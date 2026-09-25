#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Controlled release benchmark of the swiftj2k-cli CLI against reference tools
(PERFORMANCE.md PERF-02): cold command-line invocations, 5 warm-ups and 20
interleaved timed iterations per case, medians, p95, spread and pixels/s.

Usage: benchmark-lossless.py --binary /abs/release/swiftj2k-cli --output /new/dir

Cases are the repository's synthetic fixtures. Each codec is invoked as a
fresh process, so process start-up is part of every figure; results describe
this host and configuration only and are not a release gate on their own.
"""
import argparse, json, os, platform, shutil, statistics, subprocess, sys, tempfile, time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
FIXTURES = REPO / "Tests/SwiftJ2KTests/Fixtures/Lossless"
WARMUPS, ITERATIONS = 5, 20
CASES = ["g16_64x64_random", "g12_129x67_gradient", "g16_256x256_smooth", "g10_300x200_gradient"]

def timed(argv, env=None):
    start = time.perf_counter()
    r = subprocess.run(argv, capture_output=True, env=env)
    elapsed = time.perf_counter() - start
    if r.returncode != 0:
        raise RuntimeError(f"{argv[0]} exited {r.returncode}: {r.stderr.decode(errors='replace')[:200]}")
    return elapsed

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--binary", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    out = args.output.resolve(); out.mkdir(parents=True, exist_ok=False)
    binary = args.binary.resolve()
    tools = {
        "swiftj2k-cli": {"encode": [str(binary), "encode", "-i", "{nrrd}", "-o", "{out}", "--overwrite", "--precision", "{bits}"],
                     "decode": [str(binary), "decode", "-i", "{j2k}", "-o", "{out}", "--overwrite"]},
    }
    opj_c, opj_d = shutil.which("opj_compress"), shutil.which("opj_decompress")
    if opj_c and opj_d:
        tools["openjpeg"] = {"encode": [opj_c, "-i", "{pgm}", "-o", "{out}"], "decode": [opj_d, "-i", "{j2k}", "-o", "{out}"]}
    kdu_c, kdu_d = shutil.which("kdu_compress") or "/usr/local/bin/kdu_compress", shutil.which("kdu_expand") or "/usr/local/bin/kdu_expand"
    if os.access(kdu_c, os.X_OK) and os.access(kdu_d, os.X_OK):
        tools["kakadu"] = {"encode": [kdu_c, "-i", "{pgm}", "-o", "{out}", "Creversible=yes", "-quiet"],
                           "decode": [kdu_d, "-i", "{j2k}", "-o", "{out}", "-quiet"]}
    manifest = json.loads((FIXTURES / "manifest.json").read_text())
    entries = {e["name"]: e for e in manifest["fixtures"]}
    host = {"machine": platform.machine(), "system": platform.system(), "release": platform.release(),
            "binary_sha256": __import__("hashlib").sha256(binary.read_bytes()).hexdigest(),
            "tools": {name: spec["encode"][0] for name, spec in tools.items()}, "warmups": WARMUPS, "iterations": ITERATIONS}
    results = []
    with tempfile.TemporaryDirectory() as temp:
        temp = Path(temp)
        for name in CASES:
            entry = entries[name]
            pixels = entry["width"] * entry["height"]
            pgm = FIXTURES / f"{name}.pgm"
            j2k = FIXTURES / entry["codestreams"][0]["file"]      # the OpenJPEG default codestream
            nrrd = temp / f"{name}.nrrd"
            subprocess.run([str(binary), "decode", "-i", str(j2k), "-o", str(nrrd)], check=True, capture_output=True)
            for direction in ("encode", "decode"):
                samples = {tool: [] for tool in tools}
                def argv(tool):
                    ext = ".j2k" if direction == "encode" else (".nrrd" if tool == "swiftj2k-cli" else ".pgm")
                    return [a.format(nrrd=nrrd, pgm=pgm, j2k=j2k, out=temp / f"{tool}-{direction}-{name}{ext}", bits=entry["meaningfulBits"]) for a in tools[tool][direction]]
                for _ in range(WARMUPS):
                    for tool in tools: timed(argv(tool))
                for i in range(ITERATIONS):
                    order = list(tools) if i % 2 == 0 else list(reversed(list(tools)))
                    for tool in order: samples[tool].append(timed(argv(tool)))
                row = {"case": name, "direction": direction, "width": entry["width"], "height": entry["height"],
                       "meaningfulBits": entry["meaningfulBits"], "codestreamBytes": j2k.stat().st_size, "tools": {}}
                for tool, values in samples.items():
                    ordered = sorted(values)
                    median = statistics.median(values)
                    row["tools"][tool] = {"median_ms": median * 1000, "p95_ms": ordered[int(0.95 * (len(ordered) - 1))] * 1000,
                                          "min_ms": ordered[0] * 1000, "max_ms": ordered[-1] * 1000,
                                          "megapixels_per_s": pixels / median / 1e6, "samples_ms": [v * 1000 for v in values]}
                results.append(row)
                print(f"{name:24s} {direction:6s} " + "  ".join(f"{tool} {row['tools'][tool]['median_ms']:7.1f} ms" for tool in tools), flush=True)
    (out / "results.json").write_text(json.dumps({"host": host, "method": "cold CLI invocations, 5 warm-ups then 20 interleaved timed iterations per case; medians reported; process start-up included for every tool", "results": results}, indent=2) + "\n")
    print(f"written {out / 'results.json'}")

if __name__ == "__main__":
    sys.exit(main())
