"""Archive selected historical Swift 6.4 evidence; never copy build products."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shlex
import subprocess

BASE = Path(__file__).resolve().parents[2]
WORK = BASE / "work/swift64"
NAMES = ("SwiftJ2K", "SwiftJLS", "SwiftJXL", "SwiftJLI")
TEXT_SUFFIXES = {".log", ".json", ".xml", ".md", ".py", ".swift", ".sh"}
STAMP = datetime.now(timezone.utc).isoformat()
HARDWARE_IDS = set()
for _name in NAMES:
    _summary = json.loads((WORK / "xcode" / _name / "summary.json").read_text())
    for _configuration in _summary.get("devicesAndConfigurations", []):
        _device = _configuration.get("device", {})
        if _device.get("platform") == "macOS" and _device.get("deviceId"):
            HARDWARE_IDS.add(_device["deviceId"])


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path):
    return json.loads(path.read_text())


def file_record(path):
    return {"source": str(path.relative_to(BASE)), "sha256": sha(path)}


def check_hash(path, expected):
    actual = sha(path)
    assert actual == expected, f"Fingerprint mismatch: {path}"
    return {"path": str(path.relative_to(BASE)), "expected_sha256": expected,
            "observed_sha256": actual, "matches": True}


platform_path = WORK / "platform-final/results.json"
platform = read_json(platform_path)
migration_path = WORK / "migration-examples/results.json"
migration = read_json(migration_path)
harness_path = WORK / "harness/results.json"
harness = read_json(harness_path)
summary = []

for name in NAMES:
    repo = BASE / "outputs" / name
    dest = repo / "Documentation/Engineering/Swift64/Evidence"
    assert not dest.exists(), f"Refusing to replace an existing archive: {dest}"
    provenance = []

    def copy(source, target):
        assert source.is_file() and not source.is_symlink(), source
        assert source.suffix in TEXT_SUFFIXES, source
        original = source.read_bytes()
        original.decode("utf-8")
        public = original
        for identifier in HARDWARE_IDS:
            public = public.replace(identifier.encode(), b"REDACTED-HARDWARE-ID")
        output = dest / target
        assert not output.exists(), output
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(public)
        if public == original:
            provenance.append({"destination": target, "kind": "byte-for-byte-copy",
                               **file_record(source)})
        else:
            provenance.append({"destination": target, "kind": "hardware-identifier-redacted-copy",
                               "source": str(source.relative_to(BASE)), "source_sha256": sha(source),
                               "sha256": sha(output), "transformation": "Replace exact physical macOS deviceId values from original Xcode summaries with REDACTED-HARDWARE-ID. Raw local inputs are unchanged."})

    def derive(value, target, sources, transformation):
        output = dest / target
        assert not output.exists(), output
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(value, indent=2) + "\n")
        provenance.append({"destination": target, "kind": "derived-json",
                           "sha256": sha(output), "inputs": [file_record(p) for p in sources],
                           "transformation": transformation})

    def root_files(source, target):
        for path in sorted(source.iterdir()):
            if path.is_file() and path.suffix in TEXT_SUFFIXES:
                copy(path, target + "/" + path.name)

    def consumer(source, target):
        copy(source / "Package.swift", target + "/Package.swift")
        for path in sorted((source / "Sources").rglob("*.swift")):
            copy(path, target + "/" + str(path.relative_to(source)))

    baseline_path = WORK / "baseline" / name / "results.json"
    baseline = read_json(baseline_path)
    report_path = WORK / "candidate" / name / "report.json"
    report = read_json(report_path)
    fingerprints = {"checked_at_utc": STAMP, "scope": "Final validated candidate at archival time; later source changes require new evidence.",
                    "candidate_report": file_record(report_path), "candidate": [],
                    "baseline_git_snapshot": [], "platform_final": [], "harness": [],
                    "benchmark": [], "migration_example": [], "sboms": []}
    for relative, expected in report["source_files_sha256"].items():
        fingerprints["candidate"].append(check_hash(repo / relative, expected))
    assert report["manifest_sha256"] == sha(repo / "Package.swift")
    for source in sorted((WORK / "baseline" / name / "source").rglob("*")):
        if not source.is_file():
            continue
        relative = source.relative_to(WORK / "baseline" / name / "source")
        if relative.parts[0] not in {"Sources", "Tests"} and str(relative) != "Package.swift":
            continue
        committed = subprocess.check_output(["git", "show", f"{baseline['source_sha']}:{relative}"], cwd=repo)
        expected = hashlib.sha256(committed).hexdigest()
        fingerprints["baseline_git_snapshot"].append(check_hash(source, expected))
    rows = [row for row in platform["results"] if row["module"] == name]
    assert len(rows) == 10 and all(row["exit_code"] == 0 for row in rows)
    for relative, expected in rows[0]["source_sha256"].items():
        assert all(row["source_sha256"].get(relative) == expected for row in rows)
        fingerprints["platform_final"].append(check_hash(BASE / relative, expected))
    for relative, expected in harness["source_sha256"].items():
        fingerprints["harness"].append(check_hash(BASE / "outputs" / relative, expected))
    for run in ("benchmark", "benchmark-repeat"):
        for variant, record in read_json(WORK / run / "builds.json").items():
            source = (WORK / "baseline/SwiftJ2K/source" if variant == "baseline"
                      else BASE / "outputs/SwiftJ2K") / "Sources/SwiftJ2K/Image.swift"
            fingerprints["benchmark"].append({"run": run, "variant": variant,
                                              **check_hash(source, record["source_sha256"])})
    migration_consumer = WORK / "migration-examples" / ("Consumer-" + name)
    snippets = list((migration_consumer / "Sources").rglob("*.swift"))
    assert len(snippets) == 1
    fingerprints["migration_example"].append(check_hash(snippets[0], migration[name]["example_sha256"]))
    for record in report["sboms"]:
        sbom_path = Path(record["path"])
        if not sbom_path.is_absolute():
            sbom_path = WORK / "candidate" / name / sbom_path
        fingerprints["sboms"].append(check_hash(sbom_path, record["sha256"]))

    root_files(WORK / "baseline" / name, "Baseline")
    copy(BASE / "work/scripts/swift64_baseline.py", "Baseline/swift64_baseline.py")
    root_files(WORK / "candidate" / name, "Candidate")
    for path in sorted((WORK / "candidate" / name / "sboms").rglob("*.json")):
        copy(path, "Candidate/" + str(path.relative_to(WORK / "candidate" / name)))
    consumer(WORK / "candidate" / name / "consumer", "Candidate/consumer")
    copy(repo / "Package.swift", "Candidate/Package.swift")
    for filename in ("validate.sh", "validate-swift64.py", "README.md"):
        copy(repo / "Scripts" / filename, "Candidate/Scripts/" + filename)

    filtered_platform = {**platform, "results": rows}
    derive(filtered_platform, "Platforms/results.json", [platform_path],
           f"Preserve top-level metadata; select results whose module equals {name}.")
    for row in rows:
        copy(Path(row["log"]), "Platforms/" + row["target"] + "/compile.log")
    copy(WORK / "platform-final/compile_matrix.py", "Platforms/compile_matrix.py")

    xcode_log = WORK / ("xcode-" + name + ".log")
    xcode_text = xcode_log.read_text()
    command_line = xcode_text.split("Command line invocation:\n", 1)[1].splitlines()[0].strip()
    assert "** TEST SUCCEEDED **" in xcode_text
    xcode_summary = WORK / "xcode" / name / "summary.json"
    assert read_json(xcode_summary)["result"] == "Passed"
    copy(xcode_log, "Xcode/xcodebuild.log")
    copy(xcode_summary, "Xcode/summary.json")
    copy(WORK / "xcode" / name / "summary-command.json", "Xcode/summary-command.json")
    derive({"command": shlex.split(command_line), "command_display_from_log": command_line,
            "cwd": str(repo), "developer_dir": "/Applications/Xcode.app/Contents/Developer",
            "exit_code": 0, "outside_sandbox": True, "result": "Passed",
            "record_kind": "Reconstructed archival command record, not an original process record.",
            "provenance": {"argv": "Exact invocation printed by xcodebuild in xcodebuild.log; parsed with shlex.split.",
                           "cwd_developer_dir_exit_code_outside_sandbox": "Parent agent execution report: final per-repository runs exited 0 outside the sandbox.",
                           "result": "Original log TEST SUCCEEDED and xcresulttool summary result Passed."}},
           "Xcode/build-command.json", [xcode_log, xcode_summary],
           "Reconstruct argv from original log; preserve executor-reported context with explicit attribution.")

    derive({name: migration[name]}, "MigrationExamples/results.json", [migration_path],
           f"Select only the {name} entry from the original suite results.")
    copy(WORK / "migration-examples" / (name + ".log"), "MigrationExamples/example.log")
    consumer(migration_consumer, "MigrationExamples/consumer")
    copy(BASE / "work/scripts/swift64_migration_examples.py", "MigrationExamples/swift64_migration_examples.py")

    root_files(WORK / "harness", "Harness")
    harness_source = BASE / "outputs/SwiftJ2K/Integration/ContractHarness"
    consumer(harness_source, "Harness/Source")
    copy(BASE / "work/scripts/swift64_harness.py", "Harness/swift64_harness.py")
    root_files(WORK / "environment", "Environment")
    root_files(WORK / "sbom-validation", "SBOMAudit")
    root_files(WORK / "benchmark", "Benchmark/Original")
    root_files(WORK / "benchmark-repeat", "Benchmark/Repeat")
    root_files(WORK / "benchmark-sandbox-attempt", "Benchmark/SandboxAttempt")
    for variant in ("baseline", "candidate"):
        consumer(WORK / "benchmark" / variant, "Benchmark/Original/" + variant)
        copy(WORK / "benchmark" / variant / "build.log", "Benchmark/Original/" + variant + "/build.log")
    copy(BASE / "work/scripts/swift64_benchmark.py", "Benchmark/Original/swift64_benchmark.py")
    copy(BASE / "work/scripts/swift64_benchmark_repeat.py", "Benchmark/Repeat/swift64_benchmark_repeat.py")
    copy(WORK / "benchmark-repeat-console.log", "Benchmark/Repeat/console.log")
    copy(Path(__file__).resolve(), "Archival/archive_swift64_evidence.py")
    derive(fingerprints, "SOURCE_FINGERPRINTS.json", [report_path, baseline_path, platform_path, harness_path, migration_path,
           WORK / "benchmark/builds.json", WORK / "benchmark-repeat/builds.json"],
           "Compare candidate, final platform, harness, benchmark implementation, snippet and SBOM SHA-256 values with original reports. Compare baseline source/test/manifest bytes with git objects at recorded source_sha. No source snapshot is archived.")

    readme = f"""# Swift 6.4 historical validation evidence — {name}

This archive preserves the final validated candidate and its baseline. Original text files are copied byte for byte except physical hardware identifiers, which are redacted only in public copies. `PROVENANCE.json` identifies each exception with original and archived SHA-256 values, and maps every file to its historical workspace source; derived JSON records identify their input hashes and transformation. `SHA256SUMS.txt` covers every archive file except itself. `SOURCE_FINGERPRINTS.json` records successful comparisons at archival time, {STAMP}. A later code change requires new validation evidence.

| Directory | Evidence and limits |
| --- | --- |
| Baseline | Committed pre-upgrade source built and tested with Swift 6.4. This is not a Swift 6.2 execution. The source snapshot and build outputs are intentionally excluded. |
| Candidate | Original validation report, discovery/test logs, xUnit XML, build-associated SBOMs, validated package/runner files and fresh local consumer. Includes separate ASan and TSan runs and targeted repetitions. |
| Platforms | The final SDK matrix filtered to this repository, with all ten compile/link logs. It proves compile/link coverage, not device, simulator or minimum-OS runtime execution. |
| Xcode | Successful headless macOS test log, original xcresulttool summary and summary command. The xcodebuild command record is explicitly reconstructed from the log and executor report. The binary `.xcresult` bundle is excluded. |
| MigrationExamples | Compiled migration snippet, generated consumer, original log and filtered result record. |
| Harness | Suite contract harness source, commands and Debug/Release/ASan/TSan logs. Its manifest historically references all four local checkouts. |
| Environment | Original toolchain, SDK and machine evidence, including unsuccessful environment probes and their exits. |
| SBOMAudit | Structural/provenance audit and official schema references. Generator conformance defects remain; full schema/semantic validation was not completed. The SBOMs have not been rewritten or declared valid. |
| Benchmark/Original | Original storage-only benchmark, all raw samples, summaries, resource logs and source/scripts. |
| Benchmark/Repeat | Complete repeat measurements and console output, including regressions. Uses the benchmark sources and executables identified in its records. |
| Benchmark/SandboxAttempt | Earlier failed process-measurement attempt, retained separately from completed measurements. |

The benchmark exercises the shared storage implementation through SwiftJ2K on one host; it does not measure codecs or establish platform-wide performance. The initial candidate and both benchmark runs are retained regardless of their outcomes. Test summary counts can distinguish test declarations from parameterized case executions; use the original XML/logs and report fields.

Absolute paths, command working directories, timestamps and dirty-tree identifiers are historical provenance, not relocatable build instructions. Copies of scripts/manifests are evidence; they retain original path assumptions and may need an equivalent workspace layout to rerun. Use the repository's current `Scripts/validate.sh` for a new run. No build caches, modules, executables, native binaries or `.xcresult` directories are included. Native SDK/framework code is outside the SwiftPM package dependency graph represented in the generated SBOMs.

Verify archive integrity from this directory with `shasum -a 256 -c SHA256SUMS.txt`. Cross-check copied file hashes against `PROVENANCE.json`; filtered records are explicitly derived, not byte-identical copies of the suite-wide input JSON.
"""
    (dest / "README.md").write_text(readme)
    provenance.append({"destination": "README.md", "kind": "archival-description", "sha256": sha(dest / "README.md")})
    (dest / "PROVENANCE.json").write_text(json.dumps({"archived_at_utc": STAMP, "repository": name,
        "archive_role": "final validated candidate", "historical_workspace": str(BASE),
        "files": provenance}, indent=2) + "\n")
    files = sorted(p for p in dest.rglob("*") if p.is_file())
    for path in files:
        path.read_bytes().decode("utf-8")
    (dest / "SHA256SUMS.txt").write_text("".join(f"{sha(p)}  {p.relative_to(dest)}\n" for p in files))
    for record in provenance:
        assert sha(dest / record["destination"]) == record["sha256"]
        if record["kind"] == "byte-for-byte-copy":
            assert sha(BASE / record["source"]) == record["sha256"]
        elif record["kind"] == "hardware-identifier-redacted-copy":
            assert sha(BASE / record["source"]) == record["source_sha256"]
    all_files = [p for p in dest.rglob("*") if p.is_file()]
    summary.append({"repository": name, "archive": str(dest.relative_to(BASE)), "files": len(all_files),
                    "size_bytes": sum(p.stat().st_size for p in all_files), "all_utf8_text": True,
                    "candidate_fingerprint_count": len(fingerprints["candidate"]),
                    "baseline_git_fingerprint_count": len(fingerprints["baseline_git_snapshot"]),
                    "platform_logs": len(rows), "all_input_fingerprints_match": True,
                    "missing_requested_records": [], "reconstructed_records": ["Xcode/build-command.json"],
                    "hardware_identifier_redacted_files": [r["destination"] for r in provenance if r["kind"] == "hardware-identifier-redacted-copy"],
                    "sha256sums_sha256": sha(dest / "SHA256SUMS.txt")})

(WORK / "evidence-archive-summary.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps(summary, indent=2))
