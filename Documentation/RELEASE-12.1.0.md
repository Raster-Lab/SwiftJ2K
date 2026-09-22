# Release 12.1.0 — gate record

Executed 22 September 2026 on the owner's explicit release task ("start the release task for SwiftJ2K"), following [RELEASE.md](RELEASE.md). Contract 0.9.0; the seven shared documents are unchanged. Release commit `67273dbb5a195c1b2a1f47f311d9a1e4cd7f9203` ("Release 12.1.0: version") on branch `release/12.1.0` from the Milestone 5 merge `a964b7c34fef7ee58b3954ffaec813c1258376d1`. Between the Milestone 5 merge and the release commit only the version strings and the CHANGELOG changed; no library, test or CLI logic changed. The commits that follow the release commit on the branch add this record and its evidence only.

**Tag state: no tag exists.** `v12.1.0` is not created by this task because the continuous-integration precondition and the private-vulnerability-reporting precondition below are unmet. When both hold, RELEASE.md steps 3 to 6 apply to the merge commit of the release pull request without re-running the gates, provided no source has changed since `67273dbb…`; otherwise the gates are re-run on the new commit.

## Preconditions (RELEASE.md)

| Precondition | State at the release task | Checked by |
| --- | --- | --- |
| Continuous integration executes with non-zero steps | **Unmet.** The latest run on `main` (`a964b7c`, the Milestone 5 merge) ended with all seven jobs at `steps=0`; the release pull request's run 35735384787 on `67273dbb…` likewise ended with all seven jobs at `steps=0` (failure within 2 to 10 seconds, no step executed) | `gh api repos/Raster-Lab/SwiftJ2K/actions/runs/<id>/jobs` |
| Private vulnerability reporting enabled | **Unmet.** `{"enabled": false}` | `gh api repos/Raster-Lab/SwiftJ2K/private-vulnerability-reporting` |
| Owner assigned the release task explicitly | Met, 22 September 2026 | this task |

SUITE_POLICY.md 0.9.0: "no stable tag may be cut in any repository while the gates in TEST-07 are unexecuted", and its precondition "Actions billing is unlocked and a successor workflow run executes with non-zero steps". Both Actions-dependent preconditions are outside this task's reach (organisation billing and repository settings). Every other gate in RELEASE.md was executed and is recorded below; the tag step waits for the two preconditions and is the only step of RELEASE.md not performed.

## Host and toolchains

Apple M5 (10 cores), macOS 26.5.1 (25F80). Xcode 26.2 (17C52), Apple Swift 6.2.3, native build system. swift.org toolchain `swift-6.4.0-RELEASE` (`org.swift.640202609131a`) for the Swift Build engine, sanitizer and SBOM gates. Linux: colima (macOS Virtualization.framework, aarch64) running `swift:6.2-noble`. Oracles: OpenJPEG 2.5.4, Kakadu 8.4.1. Fixtures: `Tests/SwiftJ2KTests/Fixtures/Lossless` at the release commit (109 codestreams, `manifest.json`). Evidence with absolute host paths removed: [Engineering/Release-12.1.0/Evidence](Engineering/Release-12.1.0/Evidence).

During the whole task one foreign single-threaded process from another project on this host (a Python test runner) held one core at 100%; it is recorded in `benchmark/host-load.txt`. No process of this task ran during the benchmark.

## Gates at the release commit

| Gate (RELEASE.md) | Command | Result |
| --- | --- | --- |
| Xcode toolchain, native engine, debug tests | `xcrun swift test --build-system native -c debug --disable-xctest` | 78 of 78 passed, 0 skipped (`xcode/debug-tests.xml`) |
| Xcode toolchain, native engine, release tests | same with `-c release` | 78 of 78 passed, 0 skipped (`xcode/release-tests.xml`) |
| Swift 6.4, Swift Build engine, consumer, repetitions, SBOM | `TOOLCHAINS=org.swift.640202609131a ./Scripts/validate.sh --output …` | status `passed_requested_checks` (`swift64/report.json`): Swift Build engine debug clean and incremental build, 78 of 78 tests; release clean and incremental build, 78 of 78 tests; fresh local consumer round-tripped a 92-byte codestream; repetition run of the 19 lifetime/cancellation declarations at 5 repetitions, 500 case executions, 0 failures; SPDX 3.0.1 and CycloneDX 1.7 SBOMs emitted for `SwiftJ2K` at `67273dbb…` (build-associated; SwiftPM's schema bundle absent, so schema validation is an open gate) |
| Sanitizers (Swift 6.4) | `./Scripts/validate.sh --checks asan,tsan --output …` | status `passed_requested_checks` (`swift64-sanitizers/report.json`): AddressSanitizer 78 of 78, ThreadSanitizer 78 of 78, 0 skipped |
| Linux arm64 container, debug build and tests | `docker run --rm --platform linux/arm64 -v "$PWD":/SwiftJ2K -w /SwiftJ2K swift:6.2-noble swift test` | Swift 6.2.4 (`swift-6.2.4-RELEASE`), Ubuntu 24.04.5, aarch64: debug build exit 0; the runner reports 78 tests in 2 suites passed, of which the oracle test was skipped ("No independent JPEG 2000 decoder installed"; the xunit file counts 77 run, 0 failed, 1 skipped, `linux/debug-tests-swift-testing.xml`) |
| Linux arm64 container, release build, CLI conformance, `Examples/Consumer`, fresh URL consumer | in the same container run | release build exit 0 (`swiftj2k 12.1.0`); 147 of 147 CLI process checks passed; `Examples/Consumer` round-tripped a 106-byte codestream; the fresh URL consumer resolved from GitHub at `67273dbb…` and round-tripped (`linux/`) |
| CLI conformance | `python3 Scripts/test-cli.py --binary <release swiftj2k> --output …` | 147 of 147 process checks passed against the release binary (SHA-256 `0f0deafd…`, built with `xcrun swift build --build-system native -c release`; `cli/run-report.json`), and 147 of 147 again against a second clean release build in a separate scratch directory (SHA-256 `8a2c682f…`, `cli/run-rebuilt-report.json`) |
| Contract harness | `xcrun swift run --build-system native --package-path Integration/ContractHarness ContractHarness` | 6 of 6 PASS, oracles OpenJPEG and Kakadu exact; JPEG-LS leg unexecuted (SwiftJLS advertises `canEncode == false`) |
| Fuzz campaign, `inspect`, 60 minutes, seed 20260922 | `FuzzHarness --entry inspect --seconds 3600 --seed 20260922` | 13,650,790 iterations in 3600 s; outcomes success 1,740,786, malformedInput 11,259,400, unsupportedFeature 275,450, unsupportedFormat 110,994, resourceLimitExceeded 264,160; slowest input 53.5 ms against the 5 s deadline; 0 unexpected errors, 0 slow inputs kept, 0 reproducers left on disk, no trap; peak resident set 15 MiB; process exit 0 |
| Fuzz campaign, `decode`, 60 minutes, seed 20260922 | `--entry decode` | 3,585,070 iterations in 3600 s; outcomes success 394,103, malformedInput 3,020,321, unsupportedFeature 72,094, unsupportedFormat 29,258, resourceLimitExceeded 69,294; slowest input 540.7 ms against the 5 s deadline; 0 unexpected errors, 0 slow inputs kept, 0 reproducers left on disk, no trap; peak resident set 121 MiB; process exit 0 |
| Fuzz campaign, `decode(into:)`, 60 minutes, seed 20260922 | `--entry decodeInto` | 3,627,509 iterations in 3600 s; outcomes success 398,813, malformedInput 3,056,012, unsupportedFeature 72,980, unsupportedFormat 29,585, resourceLimitExceeded 70,119; slowest input 497.8 ms against the 5 s deadline; 0 unexpected errors, 0 slow inputs kept, 0 reproducers left on disk, no trap; peak resident set 121 MiB; process exit 0 |
| Release benchmark (PERF-03) | `python3 Scripts/benchmark-lossless.py --binary <release swiftj2k> --output …` | no median regression against the Milestone 4 record; see below |
| Apple SDK matrix | `xcodebuild -scheme SwiftJ2K -destination 'generic/platform=…' build` | iOS, iOS Simulator and macOS: BUILD SUCCEEDED, 0 errors. tvOS, tvOS Simulator, watchOS, watchOS Simulator, visionOS and visionOS Simulator: **unexecuted**, `xcodebuild` exit 70, "<platform> 26.2 is not installed" (`apple-sdks/summary.txt`, per-platform summaries) |
| iOS 26.2 simulator test run (not required by RELEASE.md; repeated from Milestone 5) | `xcodebuild test -scheme SwiftJ2K-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` with derived data on a case-sensitive volume | 78 of 78 passed ("Test run with 78 tests in 2 suites passed", `** TEST SUCCEEDED **`); derived data on a case-sensitive APFS sparse image created with `hdiutil` (`apple-sdks/hdiutil.log`), detached afterwards; the oracle test is compiled out on iOS |
| Fresh URL consumer, macOS (Xcode Swift 6.2.3) | package outside the repository, `.package(url: "https://github.com/Raster-Lab/SwiftJ2K.git", revision: "67273dbb…")` | resolved at `67273dbb5a195c1b2a1f47f311d9a1e4cd7f9203`, one package in the graph, "Independent SwiftJ2K consumer passed; 106-byte lossless codestream round-tripped" (`consumer/`) |

### Benchmark

Method as PERFORMANCE.md PERF-02: cold command-line invocations, 5 warm-ups and 20 interleaved timed iterations per case, medians; process start-up included for every tool. Comparison against the Milestone 4 record (`Documentation/Engineering/Milestone4/Evidence/benchmark/results.json`), SwiftJ2K medians in milliseconds:

| Case | Direction | Milestone 4 median ms | Release median ms | Δ median | Codestream bytes |
| --- | --- | --- | --- | --- | --- |
| g10_300x200_gradient | decode | 18.8 (p95 19.2) | 14.9 (p95 15.3) | -20.7% | 25285 → 25285 |
| g10_300x200_gradient | encode | 16.2 (p95 16.7) | 12.5 (p95 13.0) | -22.8% | 25285 → 25285 |
| g12_129x67_gradient | decode | 15.2 (p95 15.8) | 5.9 (p95 6.1) | -61.4% | 3609 → 3609 |
| g12_129x67_gradient | encode | 15.0 (p95 19.6) | 5.5 (p95 5.8) | -63.7% | 3609 → 3609 |
| g16_256x256_smooth | decode | 32.5 (p95 42.9) | 18.0 (p95 18.7) | -44.7% | 64367 → 64367 |
| g16_256x256_smooth | encode | 25.5 (p95 31.4) | 14.6 (p95 15.3) | -42.7% | 64367 → 64367 |
| g16_64x64_random | decode | 14.8 (p95 15.6) | 5.3 (p95 5.6) | -64.0% | 8988 → 8988 |
| g16_64x64_random | encode | 9.2 (p95 10.0) | 5.2 (p95 5.5) | -43.4% | 8988 → 8988 |

Every codestream is byte-identical in size to the Milestone 4 record, so the 1% size gate is met by identity. Every SwiftJ2K median is lower than the Milestone 4 figure, but so are the OpenJPEG and Kakadu medians by a similar ratio (Kakadu 5.5 to 3.0 ms on the smallest encode), which identifies the difference as host conditions, not code: the Milestone 4 benchmark was taken before the orphaned busy-loop shells recorded in MILESTONE4.md were found and killed. No codec source changed between the two records. This release record is the new baseline for PERF-03; the ratios against the reference tools are the figures to compare next time.

### Fuzz method

As MILESTONE5.md: `Integration/FuzzHarness` rebuilt at the release commit (binary and source SHA-256 in `fuzz/harness-sha256.txt`), 109 fixture codestreams, one to four mutation operations per input from a SplitMix64 stream seeded with 20260922, every input written to disk before execution, limits 8 MiB input, 64 MiB decoded, 256 MiB workspace, 8 million pixels, 8192 per dimension, 5-second deadline. Pass condition (RELEASE.md): zero unexpected errors, zero traps, no input over the deadline. The three campaigns ran concurrently with the other gates of this task for 3,600 s each (20,863,369 executions in total); every process exited 0 and every outcome fell into one of the five `CodecError` categories. Iteration counts are lower per hour than Milestone 5's because the host was running the other release gates at the same time; the pass condition does not depend on throughput.

## Findings

- **Release builds are not bit-reproducible across scratch directories on this host.** Two clean `swift build --build-system native -c release` runs of the same commit produced binaries with SHA-256 `0f0deafd…` and `8a2c682f…`; both report `swiftj2k 12.1.0` and both pass the 147 CLI checks. The benchmark and the first CLI run used the first binary; `swift test -c release` in the same scratch directory later replaced it with a testing-enabled build, which is why the second, separate build was made and hashed (`xcode/release-binary-sha256.txt`). A release that ships binaries would need a reproducibility procedure; this release ships source only, consumed by URL and revision.
- **The benchmark comparison against Milestone 4 is not like for like** (host load, see above). No regression can be claimed or excluded on the medians alone; the ratios against the reference tools and the byte-identical codestream sizes are the evidence that nothing changed. This record becomes the PERF-03 baseline.
- **Xcode's `SwiftJ2K-Package` scheme still needs case-sensitive derived data** (Milestone 5 finding, unchanged): the simulator run was made on a case-sensitive disk image as before.
- The Linux container has no reference decoder, so the oracle test is skipped there; the same test runs against OpenJPEG and Kakadu on macOS in every other run above.
- One foreign single-threaded process from another project ran on the host throughout; it is recorded, not a defect of this repository.

## Unexecuted (recorded, not waived)

- The tag step and the GitHub release: blocked by the two Actions-dependent preconditions above.
- tvOS, watchOS and visionOS builds (their 26.2 platform components are not installed in this Xcode), Linux x86_64, native macOS x86_64 (Rosetta builds only; the test bundle cannot run under Rosetta), physical Apple devices, the watchOS resource profile, SBOM schema validation (SwiftPM's schema bundle absent), coverage-guided fuzzing.
- Not implemented and not claimed: HTJ2K, lossy coding, colour and signed components, containers, acceleration, native transcoding, JPIP, JP3D, and multi-tile, multi-layer or non-default-style encoding.

## What the release task did not do

No tag was created, no GitHub release was published, nothing was installed outside the scratch area, and `main` was not modified. RELEASE.md steps 3 to 6 remain for the moment the preconditions hold; steps 1 and 2 (version, release commit, pull request) are done, and the gates of the table above were executed on the release commit.
