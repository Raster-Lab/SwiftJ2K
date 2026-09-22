# Milestone 2 — scalar lossless JPEG 2000 migration baseline

Executed 22 September 2026 on the owner's assignment. This record separates measured facts from expectations and lists every gate that did not execute. It is not a release qualification: contract 0.9.0's continuous-integration precondition is unmet, HTJ2K and every lossy, colour, tiled and accelerated feature are absent, and no tag exists.

## Revisions and provenance

- Successor base: `c390b50e7a96c4e7bb598e69bd8b7c047a1350eb`; branch `milestone2/scalar-lossless-j2k`.
- Pinned predecessor: Raster-Lab/J2KSwift `7acc9ae415e7d0bc7d441e0f0277d5e150bd19ca` (`origin/main`, `v12.0.0-rc.1-6`).
- Contract 0.9.0; the seven shared documents are unchanged.
- Migrated and new files, their predecessor sources and what was left behind are tabulated in [HISTORY.md](../HISTORY.md). Migrated material carries an Apache-2.0 SPDX identifier and a provenance header naming the predecessor commit and path (POL-07).

## What the scalar path supports

Raw JPEG 2000 Part 1 codestreams (no JP2/JPH container) with one unsigned greyscale component of 1–16 bits, one tile at the origin, the reversible 5/3 wavelet with 0–32 decomposition levels, no quantisation, default code-block style, one quality layer, any precinct partition, LRCP/RLCP/RPCL progression (PCRL/CPRL only when every resolution has one precinct), optional SOP/EPH markers and several tile-parts of the one tile; PLT, TLM, PLM, CRG and COM segments are skipped. Decoded samples are written straight into the caller's or the allocated `ImageDestination`; the encoder reads the sealed `Image` in place. Workspace is one `Int32` plane (4 bytes per sample) plus fixed per-block scratch, and is reported in `OperationReport.peakWorkspaceBytes` (MEM-10).

Rejected with `unsupportedFeature` before any pixel work: Part 2 or Part 15 (HTJ2K) capability bits, more than one component, signed samples, sub-sampling, non-zero image or tile origins, several tiles, the 9/7 wavelet, quantised codestreams, several layers, any code-block style bit (bypass, reset, termination, causal, predictable termination, segmentation symbols), RGN, POC, PPM/PPT, CAP, and coding overrides in tile-part headers. Truncated code-blocks decode without half-LSB reconstruction; only complete lossless sources are qualified.

## Fixtures and oracles

`Scripts/generate-lossless-fixtures.py` writes ten deterministic synthetic images (1×1 to 300×200, 8/10/12/16 meaningful bits, ramps, extremes, impulses, XorShift32 noise with recorded seeds) and encodes each with OpenJPEG 2.5.4 (`opj_compress`) and Kakadu 8.4.1 (`kdu_compress`) in seven configurations: default, no wavelet levels, 32×32 and 16×16 code-blocks, RPCL, Kakadu defaults and Kakadu with three levels. 51 codestreams resulted; every one was decoded by both tools and compared exactly to the source before admission. Thirteen further variants of the 64×64 noise image exercise supported syntax (explicit precincts, SOP/EPH, RPCL, CPRL, several tile-parts, PLT) and unsupported features (9/7, tiles, two layers, bypass, termination on each pass, segmentation symbols, HTJ2K), plus one RGB codestream. The manifest records SHA-256 of every file, geometry, precision, minimum/maximum and the little-endian sample digest. No predecessor fixture was copied; Kakadu is an oracle only and nothing from it ships.

## Executed local validation

Host: Apple M5, macOS 26.5.1. Xcode 26.2 (17C52), Apple Swift 6.2.3, Swift 6 language mode, complete concurrency checking. No Swift 6.4 toolchain is installed on this host, so the qualified primary compiler of PLAT-01 is an unexecuted gate here; 6.2 is the manifest minimum and a supported compiler.

Commands (each in its own scratch path, `DEVELOPER_DIR` selecting Xcode 26.2, module caches redirected):

```sh
xcrun swift build --build-system native -c debug
xcrun swift test  --build-system native -c debug   --disable-xctest --xunit-output debug-tests.xml
xcrun swift build --build-system native -c release
xcrun swift test  --build-system native -c release --disable-xctest --xunit-output release-tests.xml
xcrun swift run   --build-system native --package-path Examples/Consumer Consumer
xcrun swift test  --build-system native --sanitize=address --disable-xctest --xunit-output asan-tests.xml
xcrun swift test  --build-system native --sanitize=thread  --disable-xctest --xunit-output tsan-tests.xml
for i in 1 2 3 4 5; do xcrun swift test --build-system native -c debug --disable-xctest --skip-build --filter '<six ownership, cancellation and shared-storage tests>'; done
python3 Scripts/test-cli.py --binary <release swiftj2k> --output <evidence>
```

| Gate | Result |
| --- | --- |
| Debug build and tests | 69 Swift Testing declarations, 167 passing case executions, 0 failures, 0 skipped |
| Release build and tests | 69 declarations, 167 case executions, 0 failures, 0 skipped |
| Independent consumer (tools 6.2, OS 26 floor) | Built and ran: 106-byte lossless codestream round-tripped, exit 0 |
| AddressSanitizer tests | **Unexecuted.** The instrumented bundle builds, but `swift test --sanitize=address` never starts a test: the SwiftPM testing helper idles indefinitely (48 minutes observed, then killed). Reproduced on the unmodified main branch with the same toolchain |
| ThreadSanitizer tests | **Unexecuted.** The instrumented bundle builds, but the test process exits with signal 11 before any test runs. Reproduced on the unmodified main branch |
| Five fixed repetitions of the lifetime/cancellation/shared-storage tests | 6 tests × 5 runs, 30 of 30 passed (`--repetitions` is absent from Swift 6.2.3, so five separate invocations were used) |
| CLI conformance (`Scripts/test-cli.py`) | 109 process checks passed, including staged install and rendered manual |

Swift Testing counts a parameterised test as one declaration; the case executions include the 51 fixture decodes, 10 round trips, 6 option combinations, 8 degenerate geometries, 7 unsupported variants, 6 supported variants, 6 wavelet sizes and 10 oracle decodes.

## What the tests establish

- **Independent decode.** All 51 OpenJPEG and Kakadu codestreams decode to the generated samples exactly, with the declared precision, `backend == .scalarCPU`, `fidelity == .exactSamples`, no copy events and one pixel allocation.
- **Independent decode of successor output.** For all ten images the successor's codestream is decoded by `opj_decompress` and `kdu_expand` and compared sample-exact to the source. The test is enabled only where an oracle binary exists; absence is recorded as a skip reason, never a pass.
- **Round trips** across default and explicit options (0–6 levels, 4×4 to 8×512 code-blocks), 1×1 to 65×1 and 17×33 geometries, and every precision from 1 to 16 bits with extreme values.
- **Shared storage (Milestone 3 preview, TEST-09 shape).** Decoding into caller storage keeps the caller's allocation UUID, reports zero pixel allocations, leaves offset and padding bytes at zero and refuses a second writer. Encoding a padded and an unpadded view of the same samples produces byte-identical codestreams, four concurrent readers agree, and a deliberately sheared stride changes the codestream, which shows the stride check is load-bearing.
- **Robustness.** Every byte-length prefix of a fixture fails with `malformedInput` or `unsupportedFormat` (only the missing EOC decodes); every single-bit flip at three bit positions of a 222-byte fixture returns a defined error or an image, never an `internalFailure`, trap, hang or deadline; a main header without tile-parts is malformed, a JPEG marker pair is an unsupported format.
- **Limits, cancellation, progress.** Pixel, dimension, compressed-size, workspace, decoded-size and deadline limits are enforced before or during work; cancelling from the progress callback throws `CancellationError` and invalidates the destination; progress is monotonic, phased and completes only after publication.
- **Component checks.** MQ encoder/decoder round trip of 20,000 symbols over all 19 contexts, packet bit-stuffing after 0xFF, tag-tree inclusion and zero-bit-plane coding, and wavelet identity on six geometries.

## Predecessor baseline (TEST-04)

The predecessor's `J2KCodecTests` target at `7acc9ae4` does not compile on this host because `V8_8_DaemonOverheadDecomposition.swift` imports an undeclared module. With that file set aside in a scratch worktree, seventeen scalar-path suites executed 211 XCTest cases, 0 failures, 11 skips (the predecessor's own PNG/TIFF and HTJ2K variants), in 1,629 s. Log and xUnit output: [Engineering/Milestone2/Evidence](Engineering/Milestone2/Evidence); the successor gate logs, xUnit files, CLI report and source hashes are under `Evidence/gates` with local paths redacted. No successor test reproduces those suites; the successor's acceptance evidence is the independent-oracle set above.

## Performance

No release benchmark of the codec was run in this milestone. PERF-02 evidence for the scalar path is an open gate; the encoder and decoder are single-threaded scalar reference implementations and have not been measured against the predecessor or the reference tools.

## Open and unexecuted gates

- **Continuous integration (contract 0.9.0).** Every Actions job on this repository still ends with `steps=0`. The branch is local evidence; a merge before CI executes departs from the contract and is the owner's decision.
- **Swift Build engine.** `swift build --build-system swiftbuild` with Swift 6.2.3 fails on the `swiftj2k` executable target on this host, in debug with "unable to open dependencies file … main.d" and in release on an x86_64 slice with "Undefined symbol: _main"; the same failure occurs on the unmodified main branch. `Scripts/validate.sh` forces that engine and therefore could not complete. All gates above used the native engine.
- **Sanitizers.** Neither AddressSanitizer nor ThreadSanitizer test execution works with Xcode 26.2 / Swift 6.2.3 on this host (see the table); both failed identically on unmodified main. The library sources contain no `@unchecked Sendable` annotation (the only occurrence is a provenance comment) and the new coders hold no raw pointers, but the TEST-05 sanitizer gate remains unexecuted until a working toolchain runs it. Milestone 1's sanitizer evidence was produced with Xcode 27.
- **Swift 6.4** compiler, Linux, macOS x86_64, Apple devices and simulators: unexecuted.
- **SBOM generation** (needs the Swift 6.4 `--sbom-spec` option): unexecuted.
- **Fuzzing**: the deterministic truncation and bit-flip tests ran; the one-hour coverage-guided campaign of TEST-05 has not.
- **Milestone 3** shared-storage instrumentation (allocator telemetry, file-access monitoring, the SwiftJLS harness) is not claimed by the checks above.
