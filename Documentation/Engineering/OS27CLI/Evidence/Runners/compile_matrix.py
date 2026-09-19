"""Local Xcode SDK compile/link evidence; no device runtime qualification."""
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import time

BASE = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
ENV = dict(os.environ, DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer")
ENV["CLANG_MODULE_CACHE_PATH"] = str(OUT / "module-cache")
PLATFORMS = [
    ("macosx", "arm64-apple-macosx27.0"),
    ("macosx", "x86_64-apple-macosx27.0"),
    ("iphoneos", "arm64-apple-ios27.0"),
    ("iphonesimulator", "arm64-apple-ios27.0-simulator"),
    ("appletvos", "arm64-apple-tvos27.0"),
    ("appletvsimulator", "arm64-apple-tvos27.0-simulator"),
    ("xros", "arm64-apple-xros27.0"),
    ("xrsimulator", "arm64-apple-xros27.0-simulator"),
    ("watchos", "arm64_32-apple-watchos27.0"),
    ("watchsimulator", "arm64-apple-watchos27.0-simulator"),
]
SDKS = {}
for name, _ in PLATFORMS:
    result = subprocess.run(["xcrun", "--sdk", name, "--show-sdk-path"], env=ENV, text=True, capture_output=True)
    if result.returncode:
        raise SystemExit(result.stderr)
    path = Path(result.stdout.strip()).resolve()
    settings = json.loads((path / "SDKSettings.json").read_text())
    SDKS[name] = {"path": str(path), "version": settings.get("Version"),
                  "supported_targets": settings.get("SupportedTargets")}

def compile_one(module, sdk, target):
    sources = sorted((BASE / "outputs" / module / "Sources" / module).glob("*.swift"))
    destination = OUT / module / target
    destination.mkdir(parents=True, exist_ok=True)
    command = ["xcrun", "swiftc", "-parse-as-library", "-emit-module", "-emit-library", "-o", str(destination / f"lib{module}.dylib"), "-swift-version", "6",
               "-strict-concurrency=complete", "-target", target, "-sdk", SDKS[sdk]["path"],
               "-module-cache-path", str(OUT / "module-cache"), "-module-name", module,
               "-emit-module-path", str(destination / f"{module}.swiftmodule")]
    command += [str(path) for path in sources]
    start = time.monotonic()
    completed = subprocess.run(command, env=ENV, capture_output=True, text=True, timeout=90)
    log = destination / "compile.log"
    log.write_text(completed.stdout + completed.stderr)
    return {"module": module, "sdk": sdk, "sdk_version": SDKS[sdk]["version"], "target": target,
            "command": shlex.join(command), "exit_code": completed.returncode,
            "elapsed_seconds": round(time.monotonic() - start, 3), "log": str(log),
            "source_sha256": {str(path.relative_to(BASE)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}}

results = []
with ThreadPoolExecutor(max_workers=4) as executor:
    jobs = [executor.submit(compile_one, module, sdk, target)
            for sdk, target in PLATFORMS for module in ["SwiftJ2K", "SwiftJLS", "SwiftJXL", "SwiftJLI"]]
    for future in as_completed(jobs):
        result = future.result()
        results.append(result)
        print(f'{result["module"]} {result["target"]}: exit {result["exit_code"]}', flush=True)
results.sort(key=lambda value: (value["module"], value["sdk"]))
(OUT / "results.json").write_text(json.dumps({"kind": "SDK compile/link only; no device or minimum-OS runtime test", "environment": {"DEVELOPER_DIR": ENV["DEVELOPER_DIR"]}, "sdks": SDKS, "results": results}, indent=2) + "\n")
print(f'{sum(item["exit_code"] == 0 for item in results)}/{len(results)} module builds passed.', flush=True)
