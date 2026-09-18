#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Verify the checked-in, versioned common contract without network access."""
import hashlib
from pathlib import Path

root = Path(__file__).resolve().parents[1]
documentation = root / "Documentation"
expected = {"SUITE_POLICY.md", "COMMON_API.md", "MEMORY_CONTRACT.md", "PLATFORMS.md",
            "TESTING.md", "PERFORMANCE.md", "CLI_CONTRACT.md"}
seen = set()
for line in (documentation / "COMMON_CONTRACT_SHA256.txt").read_text().splitlines():
    digest, name = line.split()
    if name not in expected or name in seen:
        raise SystemExit("Unexpected or duplicate contract entry: " + name)
    seen.add(name)
    actual = hashlib.sha256((documentation / name).read_bytes()).hexdigest()
    if actual != digest:
        raise SystemExit("Contract digest mismatch: " + name)
if seen != expected:
    raise SystemExit("Missing contract document")
print("Seven contract digests verified")
