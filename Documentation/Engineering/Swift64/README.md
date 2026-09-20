# SwiftJ2K: Swift 6.4 upgrade qualification

**Development candidate 12.1.0-dev.1; contract 0.3.0; assessed 19 September 2026.** The current Milestone 1 owning-memory implementation builds and passes its executed tests with Xcode 27 / Swift 6.4. Review is requested for this bounded upgrade. This is not a release approval: minimum-OS/native-platform execution, qualified SBOM conformance and the performance item below remain open. Compressed-image encode/decode/inspect/transcode algorithms remain unimplemented and explicitly unsupported.

## Scope, identity and controlled inputs

The owner confirmed the successor repositories **SwiftJ2K, SwiftJLS, SwiftJXL and SwiftJLI**. No predecessor repository or consuming application is changed. Repository: [Raster-Lab/SwiftJ2K](https://github.com/Raster-Lab/SwiftJ2K); upgrade branch: `codex/swift-6-4-upgrade`, based on `codex/milestone-1-contract` at [`6d5b88d661ad88d1762f038273e0fec2f618b622`](https://github.com/Raster-Lab/SwiftJ2K/commit/6d5b88d661ad88d1762f038273e0fec2f618b622). The upgrade PR is stacked on the existing Milestone 1 draft PR; neither branch is merged or tagged by this task. The working tree was clean before upgrade work.

The version in [VERSION](../../../VERSION) increments the previous **unreleased** target; it does not imply that either stable version has shipped. Swift tools minimum is 6.4, Swift language mode remains 6 and deployment floors remain 26.0. All nine suite manifests (four libraries, four examples, one integration harness) were updated in place. No unsafe manifest flags or external package dependency was introduced.

The supplied README, manifesto and supplement were read in that order and the supplied SHA256SUMS verified. The two controlling reference files are retained byte-for-byte:

- [Manifesto v1.0.0](Swift_6.4_Upgrade_Manifesto_v1.0.0.md): `6a6f671a221adcc8f1323ca13546dba7a8996c5799c2a1796ed242c336c31435`.
- [Suite supplement v1.0.0](Swift_Image_Compression_Suite_Swift_6.4_Supplement_v1.0.0.md): `9ed7df7fa878cf9a6702d7ecb9d3369f7c835a40c7e8d2e6a3038c32258653b2`.

The supplement's inspected contract 0.2.0 is a historical snapshot. The actual starting source used contract 0.2.1; the seven common documents now have coordinated revision **0.3.0** and identical bytes across the repositories, verified by [COMMON_CONTRACT_SHA256.txt](../../COMMON_CONTRACT_SHA256.txt). Current repository instructions and the owner's bounded upgrade request govern scope; examples in the supplied documents do not authorise unrelated applications or a new codec milestone. Earlier [Milestone 1 evidence](../../MILESTONE1.md), predecessor history and validation records remain unchanged.

Validation ran before the documentation commit, so the recorded Git HEAD plus `-modified` is not sufficient to identify tested bytes. [Candidate/report.json](Evidence/Candidate/report.json) pins every source, test, script and core manifest by SHA-256; the publication check verifies those bytes. Current shared `Image.swift`: `a5f050b9334d533cd4f0d01b73bb7e465b9e50718abf7c07eb80dc0109e97e0e`. The containing Git commit pins the report, probes and evidence; a fresh remote consumer record separately pins the published source revision.

## Toolchain, host and deployment matrix

| Item | Observed identity |
| --- | --- |
| Developer directory | `/Applications/Xcode.app/Contents/Developer` selected per command |
| Xcode | 27.0, build 27A266a |
| Swift / Clang | Apple Swift 6.4, `swiftlang-6.4.0.34.1`, `clang-2100.3.34.1` |
| SwiftPM build engine | Explicit `--build-system swiftbuild`; no native-engine fallback |
| Host | Apple M5 Max, arm64, macOS 27.0 build 26A428 |
| Power | AC power, charged; no laboratory power/thermal control |
| SDKs | Apple SDK 27.0, compiling unchanged 26.0 deployment targets |
| Runtime dependencies | No external SwiftPM packages or sibling-codec dependency; Apple Swift/Foundation/Synchronization runtime and system linkage remain |
| Resources / shaders / plugins / macros | None in the current production package; Metal toolchain unavailable and no production Metal path to qualify |

[Environment evidence](Evidence/Environment) retains successful checks and sandbox failures. Default command-line tools were Swift 6.3; all qualification explicitly selected Xcode's 6.4. The global `xcode-select` setting was not changed. Package sandbox disabling is recorded in each command; Xcode tests and process-resource benchmarks ran outside the agent sandbox after its service/sysctl restrictions were identified.

SDK **compile and link**, with strict Swift 6 concurrency checking, passed ten targets for this package: macOS arm64 and x86_64; iOS arm64 device/simulator; tvOS arm64 device/simulator; visionOS arm64 device/simulator; watchOS arm64_32 device and arm64 simulator. All target OS 26.0. See [platform records](Evidence/Platforms). Across the suite this is **40/40 compile/link commands**, not 40 runtime tests. Execution was on the single macOS 27 arm64 host. Only iOS 17.4 simulator runtime is installed; it cannot execute OS 26 packages. OS 26 runtime, eligible simulators, physical devices, native Intel and Linux remain unexecuted.

## Behaviour and feature adoption

The compatibility-only changes raise the manifest/development minimum and qualify Swift Build. Public declarations, owning provider protocols, lease authority, synchronous sealing, capability reports, precision/layout/error semantics and cancellation policy are preserved. There is no binary ABI compatibility or binary-distribution claim. Licence remains MIT; no third-party implementation, fixture or package was added. Test inputs are synthetic and contain no patient or private application data.

[FEATURE_REGISTER.md](FEATURE_REGISTER.md) accounts for **F01–F13** with exact declarations, availability and defer reasons. The actual runtime change is F01: a bounded `RawSpan.load` reads a UInt16 from sealed storage; a bounded `OutputRawSpan.append` initialises destination sample bytes. Explicit UInt16 endian conversion preserves OS 26 availability. A mutable span over the whole destination would incorrectly assume initialised external storage, so that approach was rejected. Spans stay inside the synchronous retained-owner borrow and introduce no pixel allocation/copy. Geometry, capacity and coordinate checks dominate their preconditions; padding is excluded.

F02 scratch allocation is probed but deferred until a real codec workspace exists. F03/F04/F06/F07/F09 and endian-parameter overloads require OS 27 in the selected SDK and are absent from production. F05/F08 lack an actual current wrapper/async-cleanup need. Requested F10 public Optional APIs are unavailable even at the OS 27 target. F11 repetition/interoperability and F12 Swift Build/SBOM affect qualification tooling. F13 demonstrates local diagnostic elevation only; no suppression was introduced. Existing `@concurrent` is correctly identified as available since Swift 6.2.

The [probe archive](Probes/README.md) retains positive, expected-negative and corrected intermediate experiments. It is outside all production/test targets. Its earlier sandbox Xcode frontend failure was resolved by running direct Xcode tests outside the sandbox; that historical log remains intact rather than being rewritten as success.

## Executed checks and counts

The original source was frozen at the commit above and built with the **same Swift 6.4 compiler** before feature adoption. Clean/incremental debug builds, discovery and debug/release tests passed: **38 declarations** per configuration. [Baseline evidence](Evidence/Baseline) contains exact commands, XML and logs. The original Swift 6.2 compiler is not installed, so this is not a new 6.2 execution or a compiler-to-compiler performance comparison. The preserved historical report remains the earlier reference.

The final candidate command was:

```sh
bash Scripts/validate.sh --checks all --jobs 2 --repetitions 5 --disable-package-sandbox --output <fresh-evidence-directory>
```

The actual absolute arguments, times, exit codes, inventory and fingerprints are in [Candidate/report.json](Evidence/Candidate/report.json). Every requested command exited zero. Clean and incremental debug/release builds, an isolated local-path public consumer, fixed selected repetitions and separate AddressSanitizer / ThreadSanitizer executions passed.

| Configuration | Discovered declarations | Executed declarations | Passed case executions | Failed / skipped declarations |
| --- | ---: | ---: | ---: | ---: |
| debug | 44 | 44 | 46 | 0 / 0 |
| release | 44 | 44 | 46 | 0 / 0 |
| repetition | 14 | 14 | 75 | 0 / 0 |
| asan | 44 | 44 | 46 | 0 / 0 |
| tsan | 44 | 44 | 46 | 0 / 0 |

xUnit counts declarations; parameterised arguments and five fixed repetitions increase actual case executions. Repetition uses selected lifetime/cancellation/ownership cases, not retries until success. Swift Testing is the only production test framework; the isolated intentionally failing mixed-framework fixture proves diagnostic discovery separately. No test was silently removed or counted as passed from zero discovery.

Direct **headless Xcode** testing also passed **44 declarations**, **46 case executions**, zero failures and zero skips:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -scheme SwiftJ2K -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath <fresh-derived-data> -resultBundlePath <fresh-result>.xcresult \
  -parallel-testing-enabled NO -jobs 2 CODE_SIGNING_ALLOWED=NO
```

[Xcode evidence](Evidence/Xcode) contains the actual command, build/test log and `xcresulttool` JSON summary; raw `.xcresult` remains a local build artefact, not committed binary content. This test used Xcode's package scheme rather than inventing an Xcode project.

Six new [sample-access regression tests](../../../Tests/SwiftJ2KTests/Swift64SampleAccessTests.swift) cover independent endian golden bytes, odd physical addresses, packed/padded 12/16-bit writes, exact ownership/precision, shortened providers, extreme invalid coordinates, out-of-precision invalidation, and truly uninitialised external sample bytes without touching padding. Existing lifecycle tests cover cancellation, errors, single-writer rejection, concurrent readers and last-owner destruction. ASan/TSan found no reported errors on these CPU paths; they do not establish GPU or cross-platform safety.

The four-module [synthetic storage harness](Evidence/Harness) passed in debug, release, ASan and TSan: 12/16-bit padded 5×3 storage, one pixel allocation, zero adapter copy bytes, retained allocation identity, concurrent readers, second-writer refusal and exact lease/sample mapping. It is development-only and does not add sibling dependencies to library products. It establishes storage interoperability, not a functioning codec transcode. [Migration Markdown examples](Evidence/MigrationExamples) also compiled and ran independently for all four packages.

## Performance investigation

The shared Image.swift implementation was measured through a release-mode SwiftJ2K consumer, using identical old/new compiler configuration and synthetic unsigned 16-bit little-endian padded images. Separate allocation/write/public per-pixel read timings, checksums, total latency, executable size and process RSS are retained in [Benchmark evidence](Evidence/Benchmark). Five warmups precede twenty interleaved observations per size, alternating order; the repeat retains the same binaries. Results are exploratory host measurements, not codec throughput or general compiler-upgrade speedups.

PERF-03's pre-existing **5% median / peak-memory investigation threshold** was applied before measurement. The initial 64×63 write median rose 6.46% (6,771 → 7,208.5 ns); an independent repeat rose 6.47% (7,416.5 → 7,896 ns). The increase is small in absolute time but repeated and therefore remains an explicit investigation item. Improved total median does not waive it. Review considered a contiguous-row span path, but it would require a pixel-stride branch, a second write loop and new layout/throwing-path validation. The bounded toolchain upgrade retains the tested implementation; a later controlled experiment must resolve the cost before stable promotion. Repeated span construction is a hypothesis, not a demonstrated machine-code cause. Initial 512×511 / 2048×2047 write changes were +3.43% / −1.28%; repeat +1.16% / −2.12%. Initial total median changes were −1.05%, −7.33%, −1.60%; repeat −0.38%, −0.60%, −0.22%. Full distributions/p95 and every observation remain available, including outliers.

Initial process RSS was 19,251,200 → 18,563,072 bytes and peak footprint 13,173,336 → 12,452,392 bytes; these are whole-process maxima over all cases, not per-image memory claims. Executable size was 325,424 → 325,296 bytes. Initial thermal raw state was 1; repeat was 0. Host scheduling, frequency and workload noise were not fully controlled. No suite-wide speedup or codec memory budget conclusion is drawn. The sandbox-denied resource-wrapper attempt is preserved as an environment failure.

## Supply chain and integrity

Build-associated SPDX 3.0.1 and CycloneDX 1.7 SBOM generation exited zero for this product; originals and hashes are under [Candidate/sboms](Evidence/Candidate/sboms). No runtime SwiftPM dependency or sibling codec appears. The source fingerprint is essential because generation occurred on a modified tree. SBOMs do not inventory every native SDK/runtime component or substitute for the repository licence record.

**SBOM conformance is not qualified.** The installed generator lacks its SwiftPM_SBOMModel schema bundle. [SBOM field audit](Evidence/SBOMAudit/RESULTS.md) also records a generator CreationInfo specVersion containing `6.4.0-dev`, SPDX `externalUrl` fields incompatible with the official 3.0.1 schema, and duplicate CycloneDX product bom-ref values. Exact pointers, original hashes and authoritative specification links are retained. JSON parsing/provenance checks passed; complete JSON Schema and SPDX semantic validation were not executed. Originals were not silently repaired. Resolve generator/conformance defects and validate a clean release candidate before relying on these files for release acceptance.

[Evidence integrity](Evidence/SHA256SUMS.txt), [probe integrity](Probes/SHA256SUMS), [reference digests](REFERENCE_SHA256.txt) and the common contract digest manifest distinguish source, experiments and final validation. Build directories, caches, executables, private device attachments and binary result bundles are excluded from the text evidence archive. Public Xcode evidence copies redact unique device identifiers; the archive provenance records original and archived hashes, and untouched local originals are retained. Original command paths are historical provenance, not portable scripts; [validation instructions](../../../Scripts/README.md) provide the supported rerun interface.

## Gate disposition and rollback

| Gate | Disposition |
| --- | --- |
| G0 — inventory/pin | Complete for the authorised successor scope; dependency graph and selected toolchain recorded |
| G1 — baseline | Old source reproduced with 6.4; original 6.2 reproduction remains unavailable and historical evidence preserved |
| G2 — toolchain | Existing implemented behaviour passed under 6.4 on the stated host; targeted probes retain expected failures |
| G3 — development minimum | Manifests, instructions and pinned local runner updated; fresh URL consumer passed; no hosted CI image asserted without qualification |
| G4 — selected adoption | F01 implemented and regression-tested; all F01–F13 dispositions explicit |
| G5 — complete candidate | Executed CPU tests/builds pass; minimum-OS/native-platform, SBOM-conformance and performance investigation gates remain open |
| G6 — handover | Reviewable upgrade candidate and rollback reference; no fabricated reviewer approval, release tag or deployment |

A [fresh URL consumer](RemoteConsumer/README.md) fetched and built the published source at [`c19ff80c94eabff959d485b6b7eb3d3d931f3bf8`](https://github.com/Raster-Lab/SwiftJ2K/commit/c19ff80c94eabff959d485b6b7eb3d3d931f3bf8) and executed the exact migration example, exit 0. Package.resolved pins only this repository; downloaded source hashes match the fully tested candidate. Its initial consumer-directory naming collision and corrected fresh run are both retained. Subsequent publication changes add documentation/evidence only. No real compressed fixtures, independent codec oracles, fuzzed parsers, GPU dispatch, shaders, production CLI or compressed fidelity/throughput claim is applicable to this Milestone 1-only code; those remain required work when the corresponding later milestone is authorised.

Rollback restores the full source at `6d5b88d661ad88d1762f038273e0fec2f618b622`, its manifests and original pinned resources/toolchain as a coherent set. A manifest-only reduction to 6.2 is not a supported rollback of the new source. The preserved source is already known to build with the selected 6.4 compiler, but that does not recreate the unavailable original 6.2 environment. Reviewers should assess the narrow ownership change and evidence, and keep the stated promotion gates open until separately satisfied.
