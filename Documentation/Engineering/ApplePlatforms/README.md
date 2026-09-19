# SwiftJ2K: Apple platform runtime qualification

**19 September 2026 · 12.1.0-dev.2 · shared contract 0.4.0.** The complete existing API/storage test suite now executes in Debug and Release on native macOS arm64, Mac Catalyst, iPhone, iPad, Apple TV, Apple Watch and Vision Pro simulator destinations. This qualifies the tested foundation; compression, decompression, format inspection and native transcoding remain unimplemented and capabilities remain empty.

The qualification source commit is [`9a3cc81f04ec5925dc1041132c80eaab4a9f0f8d`](https://github.com/Raster-Lab/SwiftJ2K/commit/9a3cc81f04ec5925dc1041132c80eaab4a9f0f8d), based on [`a74b6ab52c14158b02c5562eb6a7909d6d38d912`](https://github.com/Raster-Lab/SwiftJ2K/commit/a74b6ab52c14158b02c5562eb6a7909d6d38d912). Local test reports record their starting revision and exact source/test/script hashes, including then-uncommitted additions. The committed implementation matches those inputs. Subsequent documentation and evidence commits do not alter the tested Swift code or executable scripts. This branch is `codex/apple-platform-qualification`, stacked on the Swift 6.4 / OS 27 branch. No stable release, tag or merge is included.

## Changes and version decision

- [Scripts/test-apple-platforms.py](../../../Scripts/test-apple-platforms.py) discovers or explicitly selects OS 27 simulators and runs complete Xcode test actions. It uses isolated `/private/tmp` build directories: the first iOS attempt could not load its test bundle from the Documents workspace, while the same source passed from the temporary directory. The runner selects Xcode per process, uses native arm64 Python, preserves command failures, enforces timeouts and validates the actual destination in each result.
- Test enumeration and xcresult summaries must agree on a nonzero declaration count. Disabled, skipped, failed, expected-failure and wrong-destination results fail qualification. Parameterised case executions are reported separately. [Five runner regression tests](../../../Scripts/test-apple-platform-runner.py) exercise these failure paths.
- [PlatformProfileTests.swift](../../../Tests/SwiftJ2KTests/PlatformProfileTests.swift) verifies the 32 MiB Watch decoded-storage admission boundary and that default operation options select the Watch worker/deadline profile on watchOS. It tests one row over the boundary without allocating a large pixel buffer. Other platforms retain their general defaults.

Library and CLI Swift sources, package manifests, public APIs, VERSION, manuals, sample representation and ownership behaviour are unchanged from the baseline. A minor version increment is therefore unnecessary; **12.1.0-dev.2** remains the current development identifier. Common contract files and their hashes remain unchanged. No new runtime allocation/copy path or hot-path optimisation was introduced, so this work makes no new performance claim and does not waive earlier benchmark gates.

## Executed runtime matrix

Xcode **27.0 (27A266a)**, Apple Swift **6.4 (swiftlang-6.4.0.34.1)**, Apple M5 Max, macOS **27.0 (26A428)**. Complete Swift 6 concurrency checking remains in effect. All destinations are arm64. iOS/iPadOS runtime build **24A434**, tvOS **24J360**, watchOS **24R362**, visionOS **24M362**. iPad uses the iOS runtime. Mac Catalyst runs on the host Mac.

| Destination | OS | Passed declarations / case executions per configuration | Debug / Release |
| --- | --- | ---: | --- |
| macOS arm64 | 27.0 | 45 / 47 | Pass / Pass |
| Mac Catalyst arm64 | 27.0 | 45 / 47 | Pass / Pass |
| iPhone / iOS Simulator | 27.0 | 45 / 47 | Pass / Pass |
| iPad / iOS Simulator | 27.0 | 45 / 47 | Pass / Pass |
| Apple TV / tvOS Simulator | 27.0 | 45 / 47 | Pass / Pass |
| Apple Watch / watchOS Simulator | 27.0 | 45 / 47 | Pass / Pass |
| Vision Pro / visionOS Simulator | 27.0 | 45 / 47 | Pass / Pass |

All rows have **zero failures, skips and expected failures**. Counts cover descriptors and checked arithmetic, 12/16-bit golden samples, endian and odd-address access, padded layouts, resource limits, sealed ownership, exclusive writers, concurrent readers, cancellation/publication and truthful unsupported codec operations. These are synthetic API/storage tests, not compressed-format oracle comparisons. Source fixtures are original deterministic test inputs; no predecessor codec or external fixture was imported.

[Machine-readable summary](Evidence/SUMMARY.json) and [Xcode evidence](Evidence/Xcode) contain discovery results, per-destination xcresult JSON, exact argument arrays, exit codes and logs. The fourteen destination/configuration pairs are each run once, without retry-until-pass. The first iOS path probe and discovery-tool corrections are described below, not counted as successful matrix entries.

## Additional checks

- [SDK compile/link matrix](Evidence/SDK/results.json): **10/10** per library, covering macOS arm64/x86_64, iOS/tvOS/visionOS arm64 device and simulator, and watchOS arm64_32 device / arm64 simulator. All target minima are 27.0. Device and Intel compilation is distinct from native device/Intel execution.
- [AddressSanitizer and ThreadSanitizer](Evidence/Safety/report.json): separate complete macOS suites pass with the new profile regression; zero failures/skips. A fresh standalone local consumer also builds and executes through Swift Build. No sibling codec is a library dependency.
- [Fresh GitHub consumer](Evidence/RemoteConsumer/report.json): a new standalone package resolves only this repository at the published qualification source commit above, builds and runs through Swift Build, and verifies padded 16-bit samples, storage identity and truthful unsupported encoding. Its downloaded source/test/script hashes match the runtime matrix inputs. The [consumer manifest](Evidence/RemoteConsumer/Package.swift), [resolved revision](Evidence/RemoteConsumer/Package.resolved), [source](Evidence/RemoteConsumer/Sources/Consumer/main.swift) and execution log are archived.
- [CLI checks](Evidence/CLI/report.json): **109** black-box checks pass against the freshly built macOS Release executable, including expected error exits, help aliases, all verbosity levels/forms, JSON/stderr separation, closed pipes, unavailable payload operations, staged binary/manual installation and update, man lookup, lint and rendering. No global CLI installation was changed.
- [Runner checks](Evidence/Runner/tests.log): five tests pass for evidence rejection and declaration/case accounting.

## Reproduction and runner findings

See [Scripts/README.md](../../../Scripts/README.md) for commands, destination overrides and requirements. A complete default run is:

```sh
/usr/bin/python3 -B Scripts/test-apple-platforms.py --output /absolute/new/evidence-directory
```

Add `--platforms macos catalyst ios ipados tvos watchos visionos` to include the additional Mac Catalyst variant used here. `--device PLATFORM=UUID` selects an existing simulator and is checked against OS version and device family. Missing required runtimes fail explicitly. The runner neither downloads nor erases devices, and does not change the global Xcode selection. It retains build directories and result bundles for diagnosis; simulators may remain booted after a run.

Initial tooling findings were resolved before the full matrix: simulator bundle loading failed from this host's Documents workspace; native `/usr/bin/python3` avoids the Intel Homebrew Python selected by bare `python3`; CoreSimulator reports the visionOS platform identifier as `xrOS`. The archive retains the initial iOS failure and corrected pass in SwiftJ2K, plus the initial visionOS discovery rejection. These failures were environmental/tooling probes, not skipped library tests. Simulator installation earlier encountered an unverified iPhone Air migration failure; this matrix explicitly uses the successfully verified iPhone 18 Pro and its paired Watch.

Raw xcresult bundles, build products, complete device inventories and unredacted logs remain local under `work/apple-platform-qualification/` and the build paths recorded in reports. Published text redacts the workspace/home prefix and physical hardware identifiers. [Provenance](Evidence/PROVENANCE.json) records original and archived hashes; [SHA256SUMS.txt](Evidence/SHA256SUMS.txt) checks every published evidence file. Large compilation logs remain local in `work/apple-platform-qualification/local-build-archives/SwiftJ2K/BUILD_LOGS.tar.gz`; their provenance entries are explicitly marked `LOCAL_ONLY` and retain content hashes. Automatic approval review rejected uploading the bulk archive because it could contain sensitive internal metadata. Those contents are excluded from GitHub. Smaller reviewed execution logs and summaries remain directly readable. The full simulator inventory is also excluded because it contains unrelated historical devices; selected runtime/device details remain in each report and xcresult summary. Report log paths may therefore refer to locally retained files.

## Remaining qualification boundaries

Physical-device execution, native Intel macOS and native Linux ARM64/x86_64 remain unexecuted. Simulator behaviour does not establish physical-device memory ceilings, hardware acceleration performance or Intel behaviour. macOS CLI tests do not claim mobile command-line distribution. Codec migration, independent format interoperability, real shared-storage transcoding, codec fuzzing and release performance gates remain later work. The earlier SBOM-generator conformance issue and pre-span tiny-write regression remain open; this test-only change does not resolve them.

The [OS 27 / CLI record](../OS27CLI/README.md), [Swift 6.4 record](../Swift64/README.md) and [Milestone 1 evidence](../../MILESTONE1.md) remain historical and unchanged. Their former simulator-unavailability statements describe those runs; this record supplies the later executed simulator results. Roll back this qualification change by restoring the baseline commit above; no library payload or format changes need conversion.
