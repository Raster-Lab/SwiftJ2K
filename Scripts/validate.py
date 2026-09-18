#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Run Milestone 1 gates and retain exact commands, exit codes and test reports."""
import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
evidence = root / ".validation"
evidence.mkdir(exist_ok=True)
commands = [
    ("toolchain", ["swift", "--version"]),
    ("target", ["swift", "-print-target-info"]),
    ("host", ["uname", "-a"]),
    ("contract", [sys.executable, "Scripts/verify_contract.py"]),
    ("build-debug", ["swift", "build", "-j", "2"]),
    ("test-debug", ["swift", "test", "-j", "2", "--xunit-output", str(evidence / "debug.xml")]),
    ("build-release", ["swift", "build", "-c", "release", "-j", "2"]),
    ("test-release", ["swift", "test", "-c", "release", "-j", "2", "--xunit-output", str(evidence / "release.xml")]),
    ("consumer", ["swift", "run", "--package-path", "Examples/StandaloneConsumer", "-c", "release", "-j", "2", "StandaloneConsumer"]),
]
records = []
for name, command in commands:
    print("Running:", " ".join(command), flush=True)
    with (evidence / (name + ".log")).open("w") as log:
        process = subprocess.Popen(command, cwd=root, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True)
        for line in process.stdout:
            print(line, end="", flush=True)
            log.write(line)
        code = process.wait()
    records.append({"name": name, "command": command, "exitCode": code})
    (evidence / "commands.json").write_text(json.dumps(records, indent=2) + "\n")
    if code:
        raise SystemExit(code)
