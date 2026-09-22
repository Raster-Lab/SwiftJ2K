# Milestone 4 — feature, CLI and platform coverage

Executed 22 September 2026 on the owner's assignment, on branch `milestone4/feature-platform-coverage` from `560fe5eb069ee4f962763375adb3c108548768e8` (the Milestone 3 merge). Contract 0.9.0; the seven shared documents are unchanged. Measured facts and unexecuted gates are separated below. This is not a release qualification.

## Scope delivered

**Decoder coverage (Part 1, unsigned greyscale, reversible 5/3, no quantisation).** Any tile grid and any image or tile origin; any number of quality layers; every code-block style bit of Table A.19 (selective bypass with raw passes, context reset, termination on each pass, vertically causal contexts, predictable termination, segmentation symbols) with their codeword segments; all five progression orders including position-major walks with several precincts; explicit precincts; SOP and EPH; several tile-parts per tile; COD/COC/QCD/QCC overrides in tile-part headers. The general-origin 5/3 lifting follows equations F-5 to F-8 with periodic symmetric extension; band, precinct and code-block geometry follow Annex B on the reference grid.

**Encoder.** Unchanged profile: one tile at the origin, one layer, default style; `--levels`, `--code-block` and precision selectable.

**CLI (CLI-01..CLI-04, CLI-07..CLI-09).** `encode`, `decode`, `inspect` and `validate` operate through the NRRD interchange profile documented in CLI.md: `-` for standard input and binary standard output, format declarations checked against the bytes, atomic file publication with `--overwrite`, JSON on stdout for inspection and on stderr for encode/decode reports, the full exit-status map, cooperative SIGINT cancellation (130), and every option validated before any input is opened. `transcode` remains reserved (exit 4).

**Capability matrix.**

| Feature | Decode | Encode |
| --- | --- | --- |
| Unsigned greyscale 1–16 bits, 5/3 reversible, no quantisation | yes | yes |
| Tiles, image and tile origins | yes | single tile at origin |
| Quality layers | yes | one |
| Code-block styles (all six bits) | yes | default only |
| Progression orders, precincts, SOP/EPH, tile-parts | yes | LRCP, no precincts, one tile-part |
| HTJ2K, 9/7, quantised, colour, signed, sub-sampled, ROI, POC, PPM/PPT, JP2 | rejected (`unsupportedFeature`) | rejected |
| Acceleration | none (scalar CPU) | none |

## Fixtures

`Scripts/generate-lossless-fixtures.py` now also produces 44 syntax variants of the 129×67 12-bit and 64×64 16-bit images: three layers (OpenJPEG and Kakadu), each style bit alone and all together (both encoders), 37×29 and 64×64 tiles, image origin (3,5), image plus tile origins with 40×30 tiles, Kakadu tiles and origin, PCRL/CPRL/RPCL with 32×32 precincts, and two "everything" streams combining tiles, layers, styles, precincts, position-major progression, SOP/EPH and tile-parts. Every file is decoded by both OpenJPEG 2.5.4 and Kakadu 8.4.1 and compared to the source before admission; the manifest records SHA-256 values. Total fixture set: 10 images, 51 baseline codestreams, 13 supported/unsupported variants, 44 syntax variants, one RGB codestream.

## Executed validation

Host: Apple M5 (10 cores), macOS 26.5.1, Xcode 26.2, Apple Swift 6.2.3, native build engine. Logs, xUnit files, the CLI reports, the harness log, the Linux logs and the benchmark results are in [Engineering/Milestone4/Evidence](Engineering/Milestone4/Evidence) with absolute host paths removed.

| Gate | Result |
| --- | --- |
| macOS arm64 debug tests | 78 of 78 passed in each of three consecutive full runs (`swift test --build-system native -c debug --disable-xctest`), after the test change described under "Test timing" below |
| macOS arm64 release tests | 78 of 78 passed |
| Syntax fixtures (44) decode sample-exact | 44 of 44, in the debug and release runs above |
| Independent consumer | passed; 106-byte lossless codestream round-tripped through the caller-owned path |
| Five repetitions of eight lifetime/shared-storage tests | 8 of 8 passed in all five repetitions |
| CLI conformance (`Scripts/test-cli.py`, 147 checks) | 147 of 147 passed against the release arm64 binary |
| Contract harness | 6 of 6 cases passed (3 synthetic, 3 codestream); the JPEG-LS leg stays recorded as unexecuted |
| Linux arm64, Ubuntu 24.04.5, Swift 6.2.4 (container `swift:6.2-noble`) | debug build and 78 of 78 tests passed (oracle test skipped: no reference tools in the container); release build passed; 147 of 147 CLI checks passed against the Linux binary; consumer example passed. Repository mounted at `/SwiftJ2K` so the path dependency resolves to the package identity |
| macOS x86_64 under Rosetta (supplemental, PLAT-04) | x86_64 debug build of the library, tests and executable and x86_64 release build of the executable passed; 147 of 147 CLI checks passed with the x86_64 `swiftj2k` running under Rosetta. The x86_64 test bundle was **not executed**: the toolchain's `swiftpm-testing-helper` is arm64-only and `arch -x86_64` does not propagate to it, and the bundle is a loadable bundle rather than an executable |
| Release benchmark (`Scripts/benchmark-lossless.py`) | executed; see Performance below |

## Test timing

The first three full debug runs on this host each failed one test, `sameTokenCannotAuthoriseConcurrentOverlappingBorrows`, with "First writer did not enter its scoped borrow": the writer was dispatched on the default-QoS global queue and, while the 78-test suite saturated all ten cores, that block was not scheduled within the test's five-second wait. Two of those runs also coincided with ten orphaned busy-loop shells that an unrelated session had left running on the host for 19 hours (stopped before the recorded runs). The test now starts the writer on a dedicated `Thread`, which is what it was meant to exercise (a second thread holding the borrow) and is not subject to queue starvation; the release suite, the eight-test repetition set and the Linux run had never shown the failure. Two of the three failing logs are kept in the evidence directory as `debug-test-loaded-*.log`; the first was overwritten when the gate directory was recreated for the second run. No library code changed for this.

## Portability finding

The Linux run exposed a defect in the Milestone 1 storage layer that Darwin had hidden: Swift's Linux `Mutex.withLockIfAvailable` traps ("Attempt to try to lock Mutex in already acquired thread") when the borrowing thread re-enters, whereas Darwin returns `nil`. `OwnedImageStorage` relied on that `nil` to reject reentrant borrows with an error. It now checks an atomic "engaged" flag before touching the mutex, so a reentrant call fails with `storageUnavailable` on both platforms; the test providers were changed the same way. The shared image layer is mirrored in SwiftJLS, SwiftJXL and SwiftJLI, which carry the same defect until they adopt the fix.

The Linux CLI run exposed a second one: `FileManager.replaceItemAt`, used to publish the sibling temporary file, fails on swift-corelibs-foundation for every destination (reproduced directly in the container with and without spaces in the path, with and without an existing file), so every file output exited 6 while macOS passed. The CLI now publishes with POSIX `rename(2)`, which is atomic and replaces an existing destination identically on both platforms; the overwrite refusal is checked before the rename as before. `Scripts/test-cli.py` was re-run on both platforms after the change.

## Performance

`Scripts/benchmark-lossless.py` invokes each tool as a fresh process (5 warm-ups, 20 interleaved timed iterations per case, medians of wall-clock time including process start-up), so it measures the CLI as a user would run it and not the library in isolation. Two runs were made; the first coincided with residual load from ten orphaned busy-loop shells left on the host by an unrelated session and was discarded, the second is recorded (`Engineering/Milestone4/Evidence/benchmark/results.json`). Even the second run shared the host with one unrelated single-threaded process, so the figures are indicative only.

| Case | Direction | swiftj2k median (p95) | OpenJPEG 2.5.4 | Kakadu 8.4.1 |
| --- | --- | --- | --- | --- |
| g16_64x64_random (8 988 B) | encode | 9.2 ms (10.0) | 7.6 ms (8.3) | 5.5 ms (6.5) |
| | decode | 14.8 ms (15.6) | 11.2 ms (12.5) | 8.8 ms (10.0) |
| g12_129x67_gradient (3 609 B) | encode | 15.0 ms (19.6) | 11.2 ms (12.6) | 8.4 ms (9.8) |
| | decode | 15.2 ms (15.8) | 10.3 ms (11.7) | 7.6 ms (9.2) |
| g16_256x256_smooth (64 367 B) | encode | 25.5 ms (31.4) | 19.1 ms (23.6) | 7.0 ms (8.5) |
| | decode | 32.5 ms (42.9) | 21.3 ms (27.0) | 6.7 ms (11.0) |
| g10_300x200_gradient (25 285 B) | encode | 16.2 ms (16.7) | 11.6 ms (13.0) | 4.6 ms (5.0) |
| | decode | 18.8 ms (19.2) | 11.4 ms (12.1) | 4.4 ms (4.7) |

Reading: on these small synthetic images the successor's cold CLI is roughly 1.2–1.7× OpenJPEG's time and 1.7–4.9× Kakadu's, with the gap widening with pixel count, which is expected for an unoptimised scalar bit-plane coder and a debug-free but SIMD-free 5/3 lifting; peak throughput observed is 3.7 megapixels/s encoding and 3.2 megapixels/s decoding on the 300×200 case. The successor also converts NRRD on both sides where the reference tools read and write PGM. No performance target is claimed for this milestone; PERF-02 optimisation work is deferred to a later milestone and must be measured on the in-process API with the shared-storage path, not through process start-up.

## Open and unexecuted gates

- Contract 0.9.0's continuous-integration precondition remains unmet (every Actions job still `steps=0`).
- Sanitizer execution and the Swift Build engine on this toolchain remain unexecutable (see MILESTONE2.md).
- Swift 6.4, Linux x86_64, native macOS x86_64 (Rosetta is supplemental only, and its test bundle could not be run), Apple devices and simulators, watchOS profile, SBOM generation and the one-hour fuzz campaign: unexecuted.
- Multi-tile, multi-layer and non-default-style *encoding*, HTJ2K, lossy coding, colour and signed components, containers, acceleration, native transcoding, and the auxiliary products (JP3D, JPIP): not implemented.
- Half-LSB reconstruction of truncated code-blocks is still absent; only complete lossless sources are qualified.
