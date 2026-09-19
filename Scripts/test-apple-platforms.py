#!/usr/bin/env python3
"""Run the complete package tests on explicitly recorded Apple destinations."""
# SPDX-License-Identifier: MIT
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import signal
import subprocess
import sys
import tempfile
import time

PLATFORMS = {
    "macos": ("macOS", None, None),
    "ios": ("iOS Simulator", "iOS", "iPhone"),
    "ipados": ("iOS Simulator", "iOS", "iPad"),
    "tvos": ("tvOS Simulator", "tvOS", "Apple TV"),
    "watchos": ("watchOS Simulator", "watchOS", "Apple Watch"),
    "visionos": ("visionOS Simulator", "xrOS", "Apple Vision"),
    "catalyst": ("macOS", None, None),
}
DEFAULT_PLATFORMS = [p for p in PLATFORMS if p != "catalyst"]


def fingerprints(repo):
    paths = [repo / "Package.swift", repo / "VERSION"]
    for directory in ("Sources", "Tests", "Scripts"):
        paths += [p for p in (repo / directory).rglob("*")
                  if p.is_file() and "__pycache__" not in p.parts]
    return {str(p.relative_to(repo)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(paths)}


def enumeration_count(value):
    if value.get("errors") or not value.get("values"):
        raise ValueError("Test enumeration failed or was empty")
    enabled = []
    for plan in value["values"]:
        if plan.get("disabledTests"):
            raise ValueError("Disabled tests cannot qualify a platform")
        enabled.extend(t["identifier"] for t in plan["enabledTests"])
    if not enabled or len(set(enabled)) != len(enabled):
        raise ValueError("Zero or duplicate enumerated test declarations")
    return len(enabled)


def validate_summary(summary, expected, selected, os_version):
    if (summary.get("result") != "Passed" or summary.get("passedTests") != expected
            or summary.get("totalTestCount") != expected
            or any(summary.get(k, -1) != 0 for k in
                   ("failedTests", "skippedTests", "expectedFailures"))):
        raise ValueError("Tests failed, skipped, or differ from discovery")
    configurations = summary.get("devicesAndConfigurations", [])
    if len(configurations) != 1:
        raise ValueError("Expected results from exactly one destination")
    entry = configurations[0]
    device = entry["device"]
    if (device["platform"] != selected["platform"] or device["osVersion"] != os_version
            or device["architecture"] != "arm64"):
        raise ValueError("Results are from an unexpected platform/OS/architecture")
    if selected.get("udid") and device["deviceId"] != selected["udid"]:
        raise ValueError("Results are from the wrong simulator")
    if any(entry.get(k, -1) != 0 for k in ("failedTests", "skippedTests", "expectedFailures")):
        raise ValueError("Device-level results contain failures or skips")
    if entry.get("passedTests", 0) < expected:
        raise ValueError("Fewer executed cases than declarations")
    return entry["passedTests"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platforms", nargs="+", choices=PLATFORMS, default=DEFAULT_PLATFORMS)
    parser.add_argument("--configurations", nargs="+", choices=("Debug", "Release"), default=["Debug", "Release"])
    parser.add_argument("--device", action="append", default=[], metavar="PLATFORM=UUID",
                        help="Select an existing simulator explicitly; repeat for other platforms")
    parser.add_argument("--output", type=Path, required=True, help="New evidence directory")
    parser.add_argument("--developer-dir", default=os.environ.get("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer"))
    parser.add_argument("--os-version", default="27.0")
    parser.add_argument("--jobs", type=int, choices=range(1, 33), default=2, metavar="1..32")
    parser.add_argument("--timeout", type=int, default=900, help="Seconds allowed per command")
    args = parser.parse_args()
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        parser.error("This qualified runner requires an Apple Silicon Mac")
    if args.timeout < 1 or len(set(args.platforms)) != len(args.platforms):
        parser.error("Use a positive timeout and unique platforms")
    if len(set(args.configurations)) != len(args.configurations):
        parser.error("Use unique configurations")
    overrides = {}
    for value in args.device:
        key, separator, udid = value.partition("=")
        if (not separator or key not in args.platforms or key in ("macos", "catalyst")
                or key in overrides or not re.fullmatch(r"[0-9A-Fa-f-]{36}", udid)):
            parser.error("Each --device must be a unique requested simulator PLATFORM=UUID")
        overrides[key] = udid.upper()
    repo = Path(__file__).resolve().parents[1]
    module = repo.name
    if not (repo / "Sources" / module).is_dir():
        # A renamed checkout still resolves its module from the manifest.
        match = re.search(r'name:\s*"(SwiftJ(?:2K|LS|XL|LI))"', (repo / "Package.swift").read_text())
        if not match:
            parser.error("Cannot identify this standalone suite package")
        module = match.group(1)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    # Simulator logic-test runners cannot load bundles from every Documents
    # location. Keep binaries in an isolated, non-protected temporary directory.
    scratch = Path(tempfile.mkdtemp(prefix=module + "-apple-tests-", dir="/private/tmp"))
    env = dict(os.environ, DEVELOPER_DIR=args.developer_dir,
               PATH=args.developer_dir + "/usr/bin:" + os.environ.get("PATH", ""))
    report = {"module": module, "platforms": args.platforms, "configurations": args.configurations,
              "environment": {"DEVELOPER_DIR": args.developer_dir}, "scratch": str(scratch),
              "source_sha256": fingerprints(repo), "commands": [], "results": [], "status": "running"}

    def save():
        (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")

    def run(label, argv):
        record = {"label": label, "argv": argv, "cwd": str(repo), "log": label + ".log"}
        report["commands"].append(record)
        save()
        start = time.monotonic()
        with (output / record["log"]).open("w") as log:
            process = subprocess.Popen(argv, cwd=repo, env=env, stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            try:
                code = process.wait(timeout=args.timeout)
            except (subprocess.TimeoutExpired, KeyboardInterrupt):
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                record.update(exit_code=process.returncode, interrupted=True)
                save()
                raise
        record.update(exit_code=code, elapsed_seconds=time.monotonic() - start)
        save()
        if code:
            raise RuntimeError(label + " failed; see " + record["log"])
        return (output / record["log"]).read_text()

    try:
        report["revision"] = run("revision", ["git", "rev-parse", "HEAD"]).strip()
        report["working_changes"] = run("working-changes", ["git", "status", "--short"])
        xcode = run("xcode", ["xcodebuild", "-version"])
        swift = run("swift", ["xcrun", "swift", "--version"])
        if "Xcode 27.0\nBuild version 27A266a" not in xcode or "swiftlang-6.4.0.34.1" not in swift:
            raise RuntimeError("Unexpected toolchain; deliberate qualification update required")
        run("host", ["sw_vers"])
        run("sdks", ["xcodebuild", "-showsdks"])
        inventory = json.loads(run("simulators", ["xcrun", "simctl", "list", "--json"]))
        types = {t["identifier"]: t for t in inventory["devicetypes"]}
        selected = {}
        for key in args.platforms:
            name, runtime_platform, family = PLATFORMS[key]
            if runtime_platform is None:
                selected[key] = {"platform": name, "destination": "platform=macOS,arch=arm64" +
                                 (",variant=Mac Catalyst" if key == "catalyst" else "")}
                continue
            runtimes = [r for r in inventory["runtimes"] if r.get("platform") == runtime_platform
                        and r.get("isAvailable") and r["version"] == args.os_version]
            devices = []
            for runtime in runtimes:
                for device in inventory["devices"].get(runtime["identifier"], []):
                    dtype = types.get(device.get("deviceTypeIdentifier"), {})
                    if device.get("isAvailable") and dtype.get("productFamily") == family:
                        if key not in overrides or device["udid"] == overrides[key]:
                            devices.append((device, runtime))
            if not devices:
                raise RuntimeError("No available " + key + " " + args.os_version + " simulator; install/create it explicitly")
            device, runtime = sorted(devices, key=lambda pair: (pair[0]["state"] != "Booted", pair[0]["name"], pair[0]["udid"]))[0]
            selected[key] = {"platform": name, "destination": "platform=" + name + ",id=" + device["udid"],
                             "udid": device["udid"], "name": device["name"], "runtime": runtime["identifier"],
                             "runtime_build": runtime["buildversion"], "initial_state": device["state"]}
        report["destinations"] = selected
        save()
        for key in args.platforms:
            destination = selected[key]
            for configuration in args.configurations:
                label = key + "-" + configuration.lower()
                print(module + " " + label + ": discovering and testing", flush=True)
                common = ["xcodebuild", "test", "-scheme", module + "-Package", "-configuration", configuration,
                          "-destination", destination["destination"], "-destination-timeout", "60",
                          "-jobs", str(args.jobs), "CODE_SIGNING_ALLOWED=NO", "-derivedDataPath", str(scratch / key),
                          "-parallel-testing-enabled", "NO", "-enableCodeCoverage", "NO",
                          "-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", "60",
                          "-maximum-test-execution-time-allowance", "120"]
                enumeration = output / (label + "-enumeration.json")
                run(label + "-enumerate", common + ["-enumerate-tests", "-test-enumeration-style", "flat",
                    "-test-enumeration-format", "json", "-test-enumeration-output-path", str(enumeration)])
                expected = enumeration_count(json.loads(enumeration.read_text()))
                bundle = output / (label + ".xcresult")
                run(label + "-test", common + ["-resultBundlePath", str(bundle)])
                summary = json.loads(run(label + "-summary", ["xcrun", "xcresulttool", "get", "test-results",
                                    "summary", "--path", str(bundle)]))
                (output / (label + "-summary.json")).write_text(json.dumps(summary, indent=2) + "\n")
                cases = validate_summary(summary, expected, destination, args.os_version)
                report["results"].append({"platform": key, "configuration": configuration,
                                          "discovered_declarations": expected, "passed_declarations": expected,
                                          "passed_cases": cases, "failed": 0, "skipped": 0, "summary": label + "-summary.json"})
                save()
                print(module + " " + label + ": PASS (" + str(expected) + " declarations, " + str(cases) + " cases)", flush=True)
        if report["source_sha256"] != fingerprints(repo):
            raise RuntimeError("Source/tests/scripts changed during qualification; rerun the affected checks")
        report["status"] = "passed"
    except (Exception, KeyboardInterrupt) as error:
        report.update(status="failed", error=str(error) or type(error).__name__)
        print("FAIL: " + report["error"], file=sys.stderr)
    finally:
        save()
    print("Evidence: " + str(output), flush=True)
    print("Retained build directory: " + str(scratch), flush=True)
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
