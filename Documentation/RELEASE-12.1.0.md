# Release 12.1.0 — gate record

Executed 22 and 23 September 2026 on the owner's explicit release task, following [RELEASE.md](RELEASE.md). **Release commit `f3e13a061963dc5af62605071aa6d0243105f6f4`** ("Release 12.1.0: rename the executable to swiftj2k-cli") on branch `release/12.1.0`, which contains the Milestone 5 merge `a964b7c…`, the version commit `67273db…`, main's contract 0.10.0 documents (`a88413e…`, pull request 19) and the rename. Contract **0.10.0**; the seven shared documents are byte-identical to `main`. The commits that follow the release commit on the branch add this record and its evidence only.

**Tag state: no tag exists, and none will be cut from this branch.** On 25 September 2026 the owner ruled that no release is created until the migration of J2KSwift is complete (IMPLEMENTATION.md, "Owner decision, 25 September 2026"); decision M2 already required `SwiftJ2K3D` and `SwiftJ2KJPIP` in the first stable. This record therefore stands as the gate record of a release *preparation*: every gate of RELEASE.md passed on `f3e13a0…`, and the release task is re-run in full on the commit that completes the migration programme. The continuous-integration precondition was in any case still unmet when this was written (table below).

## How the release commit came about

1. On 22 September the version was set to 12.1.0 (`67273db…`, version strings and CHANGELOG only) and every gate below was executed on that commit; that record and its evidence are in git history at `3da1665…` and `e2ccd0c…`.
2. Overnight, contract revision 0.10.0 was merged to `main` (pull request 19). CLI-01 now names the executable `swiftj2k-cli` and forbids an executable name that differs from a target or module name by case alone, the collision Milestone 5 had recorded for the `SwiftJ2K-Package` scheme.
3. The owner decided that SwiftJ2K is a new library with no legacy name to carry, so the executable was renamed before release rather than after. The rename (`f3e13a0…`) touches the product in `Package.swift`, the tool name the executable reports, `ManPages/swiftj2k-cli.1`, `Scripts/install-cli.sh`, the benchmark label and the CLI documentation. The library module `SwiftJ2K` and the NRRD header key `swiftj2k.meaningfulbits` (the library's interchange profile, not an executable name) are unchanged. No library or test logic changed.
4. Every gate was then executed again on `f3e13a0…`. That second execution is what the table below records.

## Preconditions (RELEASE.md)

| Precondition | State | Checked by |
| --- | --- | --- |
| Continuous integration executes with non-zero steps | **Unmet at the time of this record.** The owner reported the Actions billing issue fixed on 23 September; nevertheless every run created or re-run since then ended with all seven jobs at `steps=0` and the annotation "The job was not started because your account is locked due to a billing issue": run 35850482257 (fresh push, `e979280…`), 35850583024 (`c021fc0…`), 35851275598 (`f3e13a0…`, attempts 1 to 4, the last at 17:59 UTC, 23:29 IST). GitHub's lock had not lifted when this record was written | `gh api repos/Raster-Lab/SwiftJ2K/actions/runs/<id>/jobs` |
| Private vulnerability reporting enabled | **Met** on 23 September 2026: enabled during this task with `gh api -X PUT repos/Raster-Lab/SwiftJ2K/private-vulnerability-reporting` on the owner's release instruction; read-back `{"enabled": true}`. It was `false` throughout Milestone 5 and the 22 September gate run | `gh api repos/Raster-Lab/SwiftJ2K/private-vulnerability-reporting` |
| Owner assigned the release task explicitly | Met, 22 September 2026; the rename-first decision, 23 September 2026 | this task |

## Host and toolchains

Apple M5 (10 cores), macOS 26.5.1 (25F80). Xcode 26.2 (17C52), Apple Swift 6.2.3, native build system unless stated. swift.org toolchain `swift-6.4.0-RELEASE` (`org.swift.640202609131a`) for the Swift Build engine, sanitizer and SBOM gates. Linux: colima (macOS Virtualization.framework, aarch64) running `swift:6.2-noble`. Oracles: OpenJPEG 2.5.4, Kakadu 8.4.1. Fixtures: `Tests/SwiftJ2KTests/Fixtures/Lossless` at the release commit (109 codestreams, `manifest.json`). Evidence with absolute host paths removed: [Engineering/Release-12.1.0/Evidence](Engineering/Release-12.1.0/Evidence).

## Gates at the release commit `f3e13a0…`

| Gate (RELEASE.md) | Command | Result |
| --- | --- | --- |
| Xcode toolchain, native engine, debug tests | `xcrun swift test --build-system native -c debug --disable-xctest` | 78 of 78 passed, 0 skipped (`xcode/debug-tests.xml`) |
| Xcode toolchain, native engine, release tests | same with `-c release` | 78 of 78 passed, 0 skipped (`xcode/release-tests.xml`) |
| Swift 6.4, Swift Build engine, consumer, repetitions, SBOM | `TOOLCHAINS=org.swift.640202609131a ./Scripts/validate.sh --output …` | status `passed_requested_checks` (`swift64/report.json`): Swift Build engine debug clean and incremental build, 78 of 78 tests; release clean and incremental build, 78 of 78 tests; fresh local consumer round-tripped; repetition run of the 19 lifetime/cancellation declarations at 5 repetitions, 0 failures; SPDX 3.0.1 and CycloneDX 1.7 SBOMs emitted for `SwiftJ2K` at `f3e13a06…` (build-associated; SwiftPM's schema bundle absent, so schema validation is an open gate) |
| Sanitizers (Swift 6.4) | `./Scripts/validate.sh --checks asan,tsan --output …` | status `passed_requested_checks` (`swift64-sanitizers/report.json`): AddressSanitizer 78 of 78, ThreadSanitizer 78 of 78, 0 skipped |
| Linux arm64 container, debug build and tests | `docker run --rm --platform linux/arm64 -v "$PWD":/SwiftJ2K -w /SwiftJ2K swift:6.2-noble swift test` | Swift 6.2.4 (`swift-6.2.4-RELEASE`), Ubuntu 24.04.5, aarch64: debug build exit 0; the runner reports 78 tests in 2 suites passed, of which the oracle test was skipped (no reference decoder in the container; the xunit file counts 77 run, 0 failed, 1 skipped, `linux/debug-tests-swift-testing.xml`) |
| Linux arm64 container, release build, CLI conformance, `Examples/Consumer`, fresh URL consumer | in the same container run | release build exit 0 (`swiftj2k-cli 12.1.0`); 147 of 147 CLI process checks passed; `Examples/Consumer` round-tripped a 106-byte codestream; the fresh URL consumer resolved from GitHub at `f3e13a06…` and round-tripped (`linux/`) |
| CLI conformance | `python3 Scripts/test-cli.py --binary <release swiftj2k-cli> --output …` | 147 of 147 process checks passed against the release binary `swiftj2k-cli` (SHA-256 `144b410b…`, `xcrun swift build --build-system native -c release` in its own scratch directory; `cli/run-report.json`) |
| Contract harness | `xcrun swift run --build-system native --package-path Integration/ContractHarness ContractHarness` | 6 of 6 PASS, oracles OpenJPEG and Kakadu exact; JPEG-LS leg unexecuted (SwiftJLS advertises `canEncode == false`) |
| Fuzz campaign, `inspect`, 60 minutes, seed 20260923 | `FuzzHarness --entry inspect --seconds 3600 --seed 20260923` | 13,783,050 iterations in 3600 s; outcomes success 1,756,088, malformedInput 11,370,703, unsupportedFeature 278,136, unsupportedFormat 112,953, resourceLimitExceeded 265,170; slowest input 13.9 ms against the 5 s deadline; 0 unexpected errors, 0 slow inputs kept, 0 reproducers left on disk, no trap; peak resident set 15 MiB; process exit 0 |
| Fuzz campaign, `decode`, 60 minutes, seed 20260923 | `--entry decode` | 3,451,040 iterations in 3600 s; outcomes success 378,878, malformedInput 2,908,052, unsupportedFeature 69,401, unsupportedFormat 28,264, resourceLimitExceeded 66,445; slowest input 63.1 ms against the 5 s deadline; 0 unexpected errors, 0 slow inputs kept, 0 reproducers left on disk, no trap; peak resident set 122 MiB; process exit 0 |
| Fuzz campaign, `decode(into:)`, 60 minutes, seed 20260923 | `--entry decodeInto` | 3,709,279 iterations in 3600 s; outcomes success 407,201, malformedInput 3,125,726, unsupportedFeature 74,625, unsupportedFormat 30,423, resourceLimitExceeded 71,304; slowest input 121.2 ms against the 5 s deadline; 0 unexpected errors, 0 slow inputs kept, 0 reproducers left on disk, no trap; peak resident set 122 MiB; process exit 0 |
| Release benchmark (PERF-03) | `python3 Scripts/benchmark-lossless.py --binary <release swiftj2k-cli> --output …` on a quiet host, before any other gate of this run | no median regression against the 22 September record; see below |
| Apple SDK matrix | `xcodebuild -scheme SwiftJ2K -destination 'generic/platform=…' build` | iOS, iOS Simulator and macOS: BUILD SUCCEEDED, 0 errors. tvOS, tvOS Simulator, watchOS, watchOS Simulator, visionOS and visionOS Simulator: **unexecuted**, `xcodebuild` exit 70, "<platform> 26.2 is not installed" (`apple-sdks/summary.txt`, per-platform summaries) |
| `SwiftJ2K-Package` scheme on default (case-insensitive) derived data, the Milestone 5 collision | `xcodebuild build -scheme SwiftJ2K-Package -destination 'platform=iOS Simulator,…'` | **BUILD SUCCEEDED** on the default APFS (case-insensitive) volume, no "Cannot load module" and no "unable to open dependencies file" (`apple-sdks/case-insensitive-package-scheme-build-summary.log`). Under the old name this build failed in Milestone 5 and needed a case-sensitive disk image; the rename removes that requirement |
| iOS 26.2 simulator test run (repeated from Milestone 5) | `xcodebuild test -scheme SwiftJ2K-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` | 78 of 78 passed ("Test run with 78 tests in 2 suites passed", `** TEST SUCCEEDED **`) on default case-insensitive derived data, no disk image needed; the oracle test is compiled out on iOS (`apple-sdks/ios-simulator-test-summary.log`) |
| Swift Build engine on Xcode's Swift 6.2.3, including the executable (the failure contract 0.10.0 describes) | `xcrun swift build --build-system swiftbuild -c debug` | build exit 0, "Build complete!", no "unable to open dependencies file" (`xcode/swiftbuild-623-debug-build.log`). Under the old name the same command failed on this host (pull request 19) |
| Fresh URL consumer, macOS (Xcode Swift 6.2.3) | package outside the repository, `.package(url: "https://github.com/Raster-Lab/SwiftJ2K.git", revision: "f3e13a06…")` | resolved at `f3e13a061963dc5af62605071aa6d0243105f6f4`, one package in the graph, "Independent SwiftJ2K consumer passed; 106-byte lossless codestream round-tripped" (`consumer/`) |

### Benchmark

Method as PERFORMANCE.md PERF-02: cold command-line invocations, 5 warm-ups and 20 interleaved timed iterations per case, medians; process start-up included for every tool. The baseline is the 22 September release record on `67273db…` (same host, same method, binary `0f0deafd…`), which superseded the Milestone 4 record taken on a loaded host. SwiftJ2K medians in milliseconds:

| Case | Direction | Baseline median ms | Release median ms | Δ median | Codestream bytes |
| --- | --- | --- | --- | --- | --- |
| g10_300x200_gradient | decode | 14.9 (p95 15.3) | 14.5 (p95 15.2) | -3.0% | 25285 → 25285 |
| g10_300x200_gradient | encode | 12.5 (p95 13.0) | 11.6 (p95 12.0) | -7.4% | 25285 → 25285 |
| g12_129x67_gradient | decode | 5.9 (p95 6.1) | 5.6 (p95 5.6) | -4.7% | 3609 → 3609 |
| g12_129x67_gradient | encode | 5.5 (p95 5.8) | 5.0 (p95 5.4) | -7.6% | 3609 → 3609 |
| g16_256x256_smooth | decode | 18.0 (p95 18.7) | 17.3 (p95 18.1) | -4.2% | 64367 → 64367 |
| g16_256x256_smooth | encode | 14.6 (p95 15.3) | 13.9 (p95 14.4) | -5.0% | 64367 → 64367 |
| g16_64x64_random | decode | 5.3 (p95 5.6) | 5.2 (p95 5.5) | -3.3% | 8988 → 8988 |
| g16_64x64_random | encode | 5.2 (p95 5.5) | 4.9 (p95 5.1) | -6.2% | 8988 → 8988 |

Every codestream is byte-identical in size, so the 1% size gate is met by identity; every median is within the noise of the baseline and none is higher. Host load during the run is in `benchmark/host-load.txt`.

### Fuzz method

As MILESTONE5.md: `Integration/FuzzHarness` rebuilt at the release commit (binary and source SHA-256 in `fuzz/harness-sha256.txt`), 109 fixture codestreams, one to four mutation operations per input from a SplitMix64 stream, every input written to disk before execution, limits 8 MiB input, 64 MiB decoded, 256 MiB workspace, 8 million pixels, 8192 per dimension, 5-second deadline. The seed is 20260923 for this run (20260922 on the 22 September run), so the two campaigns explored different mutation streams. Pass condition (RELEASE.md): zero unexpected errors, zero traps, no input over the deadline. The three campaigns of the table ran concurrently with each other and with nothing else of this task, `caffeinate -i -s` holding the host awake and the lid open, for 3,600 s each (20,943,369 executions in total); every process exited 0 and every outcome fell into one of the five `CodecError` categories.

**An interrupted first attempt is kept as supplementary evidence** (`fuzz-interrupted/`). The first campaigns on `f3e13a0…` started at 16:24 IST alongside the other gates; at 17:13 the laptop lid was closed ("Clamshell Sleep" in the power log, `fuzz-interrupted/host-sleep-log.txt`) and the host cycled through sleep and dark wakes until 17:35, when the harness's continuous clock, which counts through sleep, passed the budget and the three processes wrote their summaries with `elapsedSeconds` 4308. Each had therefore executed for roughly 50 minutes, not 60, and each recorded as "slowest" the iteration that was in flight when the machine slept: 24,766 ms for `inspect`, 5,688 and 5,115 ms for `decode`, 5,686 ms for `decode(into:)`, kept as `slow-*.bin`. Replayed with the release CLI on the awake host, all four inputs complete in under 40 ms (`fuzz-interrupted/replay.txt`): two are rejected as malformed at the header, two inspect and validate successfully. They are sleep artefacts, not slow inputs, and the interrupted attempt found zero unexpected errors and zero traps in its 20.8 million executions. Because the pass condition asks for an hour per entry point and no input over the deadline, the campaigns were run again with `caffeinate` holding the host awake and the lid open; that second run is the one in the table. Both runs use seed 20260923, so the second replays the first's mutation stream and continues past it.

## Findings

- **The rename resolves the Milestone 5 collision.** With the executable product `swiftj2k-cli`, the `SwiftJ2K-Package` scheme builds and tests on default case-insensitive derived data, and `swift build --build-system swiftbuild` under Xcode's Swift 6.2.3 builds the package including the executable. Both had failed under `swiftj2k` (Milestone 5 record; pull request 19). No workaround remains in the procedure.
- **Two full gate executions, one day apart, with different fuzz seeds.** The 22 September run on `67273db…` (git history `3da1665…`) and this run on `f3e13a0…` agree on every count. Between the two commits only documentation and the executable name changed, and the benchmark medians on the renamed binary are within noise of the earlier record with byte-identical codestream sizes.
- **Release builds are not bit-reproducible across scratch directories on this host** (22 September finding, unchanged): the release binary hash `144b410b…` identifies the build the benchmark and CLI checks used; a rebuild elsewhere hashes differently. The release ships source, consumed by URL and revision.
- The Linux container has no reference decoder, so the oracle test is skipped there; the same test runs against OpenJPEG and Kakadu on macOS in every other run above.
- The NRRD header key `swiftj2k.meaningfulbits` keeps its name. It is the library's interchange-profile key under CLI-04, not an executable name, and CLI-01's rule addresses executable names only.

## Unexecuted (recorded, not waived)

- The tag step and the GitHub release: blocked by the continuous-integration precondition until GitHub reports the organisation's Actions unlocked.
- tvOS, watchOS and visionOS builds (their 26.2 platform components are not installed in this Xcode), Linux x86_64, native macOS x86_64 (Rosetta builds only; the test bundle cannot run under Rosetta), physical Apple devices, the watchOS resource profile, SBOM schema validation (SwiftPM's schema bundle absent), coverage-guided fuzzing.
- Not implemented and not claimed: HTJ2K, lossy coding, colour and signed components, containers, acceleration, native transcoding, JPIP, JP3D, and multi-tile, multi-layer or non-default-style encoding.
