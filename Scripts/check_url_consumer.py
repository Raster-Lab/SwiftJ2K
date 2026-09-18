#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Resolve this public product by exact GitHub revision in a fresh temporary package."""
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
name = "SwiftJ2K"
if len(sys.argv) != 2 or not re.fullmatch(r"[0-9a-f]{40}", sys.argv[1]):
    raise SystemExit("Usage: check_url_consumer.py <40-character commit SHA>")
revision = sys.argv[1]
fixture = root / "Examples/StandaloneConsumer"
with tempfile.TemporaryDirectory(prefix=name + "-consumer-") as temporary:
    consumer = Path(temporary)
    shutil.copytree(fixture / "Sources", consumer / "Sources")
    manifest = (fixture / "Package.swift").read_text()
    replacement = '.package(url: "https://github.com/Raster-Lab/' + name + '.git", revision: "' + revision + '")'
    manifest, count = re.subn(r'\.package\(path: "\.\./\.\./?"\)', replacement, manifest)
    if count != 1:
        raise SystemExit("Expected exactly one local self-package dependency")
    (consumer / "Package.swift").write_text(manifest)
    for command in (["swift", "package", "resolve"],
                    ["swift", "run", "-c", "release", "-j", "2", "StandaloneConsumer"]):
        print("URL consumer:", " ".join(command), flush=True)
        subprocess.run(command, cwd=consumer, check=True)
    resolved = (consumer / "Package.resolved").read_text()
    evidence = root / ".validation"
    evidence.mkdir(exist_ok=True)
    (evidence / "url-consumer.resolved.json").write_text(resolved)
print("Independent URL consumer passed at", revision)
