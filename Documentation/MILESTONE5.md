# Milestone 5 — release preparation

Executed 22 September 2026 on the owner's assignment, on branch `milestone5/release-preparation` from `45a36992f2daab547cc058097b648f71053e3cab` (the Milestone 4 merge). Contract 0.9.0; the seven shared documents are unchanged. Development version `12.1.0-dev.6`. **No tag was created**: IMPLEMENTATION.md reserves the stable tag for an explicit release task, and contract 0.9.0 forbids any stable tag while the continuous-integration precondition is unmet. The only source change is the CLI's version string. This record separates what was executed from what remains open; it is not a release approval.

## Scope delivered

- **Clean versioned consumption.** A fresh package outside the repository, `.package(url: "https://github.com/Raster-Lab/SwiftJ2K.git", revision: "45a36992…")`, resolves this repository alone (`swift package show-dependencies` shows one node), builds and round-trips a codestream on macOS (Xcode Swift 6.2.3) and inside the Linux arm64 container (Swift 6.2.4). `Scripts/validate-swift64.py`'s generated local consumer was brought back to the contract (tools 6.2, macOS 26.0, a real round trip instead of the Milestone 1 "encode must fail" assertion). A second executable example, [Examples/MigrationExample](../Examples/MigrationExample), is the program reproduced in MIGRATION.md.
- **Documentation and examples.** MIGRATION.md rewritten for the Milestone 4 state (capability table, contract 0.9.0 Decision D3 on floors, URL pinning, operation mapping including `decode(into:)`, CLI mapping, product dispositions with the executed DICOMKit audit). README, IMPLEMENTATION.md, CLI.md and the manual updated; [RELEASE.md](RELEASE.md) written as the procedure for the release task.
- **Licence and fixture notices.** [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) records the relicensed predecessor code, the synthetic fixtures and every development oracle with version and licence; SPDX headers added to the three active files that lacked them (two example manifests and the fixture generator). Archived evidence copies keep their original form and are declared as such.
- **Security policy.** SECURITY.md now records the repository's actual settings (private vulnerability reporting, Dependabot security updates and secret scanning are all disabled, checked through the GitHub API) and a supported-version policy that takes effect with the first tag.
- **Release gates executed** on this host that earlier milestones had recorded as unexecuted: Swift 6.4 with the Swift Build engine, AddressSanitizer, ThreadSanitizer, build-associated SBOMs, a fuzz campaign per decode entry point, an Apple SDK build matrix and an iOS simulator test run. Details below.

## Executed validation

Host: Apple M5 (10 cores), macOS 26.5.1, Xcode 26.2 (Apple Swift 6.2.3) and the swift.org toolchain `swift-6.4.0-RELEASE` (`org.swift.640202609131a`, Apple Swift version 6.4). Evidence with absolute host paths removed: [Engineering/Milestone5/Evidence](Engineering/Milestone5/Evidence).

| Gate | Result |
| --- | --- |
| Swift 6.4, **Swift Build engine**, debug clean and incremental build, tests | 78 of 78 passed (`Scripts/validate.sh` default checks, `report.json` under `swift64/`) |
| Swift 6.4, Swift Build engine, release clean and incremental build, tests | 78 of 78 passed |
| Swift 6.4 fresh local consumer | passed after the script fix; the first attempt with the stale script (macOS 27 floor) is kept as `fresh-local-consumer-stale-script.log` |
| **AddressSanitizer** (Swift 6.4) | 78 of 78 passed |
| **ThreadSanitizer** (Swift 6.4) | 78 of 78 passed |
| **SBOM**, SPDX 3.0.1 and CycloneDX 1.7, build-associated (`swift build --sbom-spec`) | both emitted; components are exactly `SwiftJ2K` and `swiftj2k`; SwiftPM reported its schema bundle unavailable, so schema validation is an open gate |
| Fresh URL-based consumer, macOS, Xcode Swift 6.2.3 | resolved at the pinned revision, one package in the graph, round trip passed |
| Fresh URL-based consumer, Linux arm64 container (`swift:6.2-noble`, Swift 6.2.4) | resolved from GitHub at the pinned revision, one package in the graph, round trip passed |
| Examples/MigrationExample (path dependency, native engine) | passed: 115-byte codestream, decode into caller storage with 0 pixel allocations and 0 copy events |
| Apple SDK build matrix (`xcodebuild -scheme SwiftJ2K`, Release) | iOS device, iOS Simulator and macOS built. tvOS, watchOS and visionOS **unexecuted**: their 26.2 platform components are not installed in this Xcode |
| iOS 26.2 simulator test run (`xcodebuild test -scheme SwiftJ2K-Package`, iPhone 17 Pro) | 78 of 78 Swift Testing declarations passed with derived data on a case-sensitive volume; the oracle test is compiled out on iOS (`Process` unavailable). The first attempt on the default case-insensitive derived data failed to build (see Findings) |
| Fuzz campaign, `inspect` entry point, 60 minutes | 18,812,916 iterations in 3600 s; outcomes success 2,398,342, malformedInput 15,517,998, unsupportedFeature 379,690, unsupportedFormat 153,368, resourceLimitExceeded 363,518; slowest input 12.5 ms against the 5 s deadline; 0 unexpected errors, 0 slow inputs kept, 0 reproducers left on disk, no trap; peak resident set 16 MiB; process exit 0 |
| Fuzz campaign, `decode` entry point, 60 minutes | 5,024,260 iterations in 3600 s; outcomes success 552,255, malformedInput 4,232,584, unsupportedFeature 101,268, unsupportedFormat 40,891, resourceLimitExceeded 97,262; slowest input 229.2 ms against the 5 s deadline; 0 unexpected errors, 0 slow inputs kept, 0 reproducers left on disk, no trap; peak resident set 121 MiB; process exit 0 |
| Fuzz campaign, `decode(into:)` entry point, 60 minutes | 5,116,734 iterations in 3600 s; outcomes success 562,459, malformedInput 4,310,402, unsupportedFeature 103,217, unsupportedFormat 41,624, resourceLimitExceeded 99,032; slowest input 242.6 ms against the 5 s deadline; 0 unexpected errors, 0 slow inputs kept, 0 reproducers left on disk, no trap; peak resident set 121 MiB; process exit 0 |
| Milestone 4 gates (Xcode 6.2.3 native engine, Linux container, harness, benchmark) | unchanged since `45a3699`: no library or test source changed in this milestone. See MILESTONE4.md |
| CLI conformance (`Scripts/test-cli.py`) against the `12.1.0-dev.6` release binary, Xcode 6.2.3 | 147 of 147 passed |

### Fuzz method

`Integration/FuzzHarness` (development-only, path dependency) mutates the 109 fixture codestreams (the OpenJPEG and Kakadu baselines, the syntax variants and the unsupported-feature variants) with one to four operations drawn from truncation, bit flips, byte sets, chunk deletion, insertion and duplication, marker-length corruption, header-field corruption, splicing between seeds and zero runs, driven by a SplitMix64 stream seeded with `20260922`. Every input is written to disk before execution so a trap leaves its reproducer. Limits: 8 MiB input, 64 MiB decoded, 256 MiB workspace, 8 million pixels, 8192 per dimension, 5-second deadline. Outcomes are counted by `CodecError` category; a `CancellationError`, a trap or any other error type is a finding. The three campaigns ran concurrently on the same host for 3,600 s each (28,953,910 executions in total, summaries and the SHA-256 of the harness binary and sources under `fuzz/`); every process exited 0 and every outcome fell into one of the five `CodecError` categories. This is mutation-based, not coverage-guided; libFuzzer integration remains open.

## Findings

- **Xcode builds the package's own scheme into one case-insensitive products directory**, where the executable module `swiftj2k` and the library module `SwiftJ2K` collide ("Cannot load module 'swiftj2k' as 'SwiftJ2K'"). CLI-01 fixes the executable name and API-01 the module name, so the names cannot change. It affects only `xcodebuild` of the `SwiftJ2K-Package` scheme on a case-insensitive volume; `swift build`, `swift test`, consumers that reference the library product, and derived data on a case-sensitive volume are unaffected. The simulator run was completed by placing derived data on a case-sensitive APFS disk image (`hdiutil create -fs "Case-sensitive APFS"`); the failing and passing logs are both archived under `apple-sdks/`. Consumers building an app in Xcode are not affected unless they add the `swiftj2k` executable product to their own scheme.
- **The validation script had drifted from the contract**: it generated a macOS 27 consumer and asserted that encoding must fail. Fixed; the stale run is archived.
- Swift 6.4 executes what Swift 6.2.3 could not on this host: the Swift Build engine, and both sanitizers. Contract PLAT-01 names 6.4 the qualified primary toolchain; the Milestone 2 to 4 records that called these gates unexecutable described the 6.2.3 toolchain only.

## Open and unexecuted gates

- **Contract 0.9.0's continuous-integration precondition remains unmet**: every Actions job on `main` and on this branch still ends with `steps=0`. Recorded, not waived; no stable tag can be cut while this holds.
- Private vulnerability reporting is not enabled on the repository (organisation-owner action; SECURITY.md).
- SBOM schema validation (SwiftPM's schema bundle absent), tvOS/watchOS/visionOS builds, Linux x86_64, native macOS x86_64, physical Apple devices, the watchOS resource profile on a device, and coverage-guided fuzzing: unexecuted.
- Milestone 4's Rosetta test-bundle limitation stands.
- Not implemented and not claimed: HTJ2K, lossy coding, colour and signed components, containers, acceleration, native transcoding, JPIP, JP3D, and multi-tile, multi-layer or non-default-style encoding.
