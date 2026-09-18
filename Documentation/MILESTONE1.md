# Milestone 1 — API and owning-memory feasibility

**Final validation after review:** 38 Swift Testing tests passed in each of debug, release, AddressSanitizer and ThreadSanitizer; every command and the independent consumer exited 0. The final source hashes, complete command lines, logs and XML are in [Validation/final](Validation/final). Earlier tables below record the preceding implementation snapshot; this final evidence supersedes their test counts and source fingerprints.


The independent `SwiftJ2K` package now implements checked image descriptors, resource limits, exclusive writable storage, immutable sealed images and the common API call shapes. Synthetic helpers preserve unsigned 12-in-16 and full 16-bit sample values. JPEG 2000, HTJ2K, container inspection, native transcoding, acceleration and CLI algorithms remain unimplemented. Their capability lists are empty and their entry points throw defined unsupported errors. This milestone is not a working image codec or a release qualification.

## Revisions and provenance

- Successor foundation: `e7c287c768b40afa9c657cfe0b63a27d6adf3267`.
- Branch: `codex/milestone-1-contract`.
- Pinned predecessor: Raster-Lab/J2KSwift, `768f6b53499b806fd0304962056e1fc7833f12e5`.
- Contract: original 0.2.0, refined consistently across all four repositories to 0.2.1. The seven documents and `COMMON_CONTRACT_SHA256.txt` are byte-identical between repositories.
- All new source, tests and fixtures are original MIT-licensed implementation. No predecessor algorithm or third-party fixture was copied. `Validation/IMPLEMENTATION_SHA256.txt` identifies the tested source/test snapshot.

The pinned predecessor's `.github/AGENTS.md`, `Package.swift`, `Sources/J2KCore/CompressionFamilyConformance.swift` and `Sources/J2KCore/J2KImageBuffer.swift` were inspected. The existing buffer uses copy-on-write owned raw storage, and its Data constructor copies. Its source confirms that a view wrapper alone cannot establish direct caller-storage decode. The old mandatory CompressionFamily conformances and dependency are not imported. The successor uses independent local types; identical source declarations in other modules do not make them the same Swift type.

J2KCore/J2KCodec scalar algorithms and their regressions are deferred to Milestone 2. J2KFileFormat, J2KMetal/native kernels, JPIP, J2K3D, J2KDICOMHelpers, CLI/test app, daemon/protocol/core/client products remain explicitly inventoried migration candidates. No predecessor product was deleted or changed. Predecessor codec builds, oracle comparisons and hot-path benchmarks are unexecuted because this task migrates no codec algorithm.

## Executed local validation

Host: macOS 27.0 arm64. Xcode 27.0 build 27A266a; Apple Swift 6.4 (`swiftlang-6.4.0.34.1`, clang `2100.3.34.1`), Swift 6 language mode. Package tools minimum is 6.2 and Apple deployment floors remain exactly 26.0. An installed Swift 6.2 compiler was not available; a 6.4 build does not qualify that minimum compiler gate.

Run `bash Scripts/validate.sh` from the package root. It selects Xcode per process and does not change `xcode-select`. The recorded run used:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
xcrun swift build --disable-sandbox --build-system native -c debug
xcrun swift test --disable-sandbox --build-system native -c debug --xunit-output .build/evidence/debug-tests.xml
xcrun swift build --disable-sandbox --build-system native -c release
xcrun swift test --disable-sandbox --build-system native -c release --xunit-output .build/evidence/release-tests.xml
xcrun swift run --disable-sandbox --build-system native --package-path Examples/Consumer Consumer
xcrun swift test --disable-sandbox --build-system native --sanitize=address --scratch-path .build/asan --xunit-output .build/evidence/asan-tests.xml
xcrun swift test --disable-sandbox --build-system native --sanitize=thread --scratch-path .build/tsan --xunit-output .build/evidence/tsan-tests.xml
```

All seven commands exited 0. Debug, release, AddressSanitizer and ThreadSanitizer each ran **37 Swift Testing tests**, with zero failures and no skipped cases. The independent consumer compiled and ran without a sibling or shared-foundation dependency. Swift Testing writes `*-swift-testing.xml`; XCTest's compatibility section reports zero tests and is not the actual test count. [Machine-readable summary](Validation/summary.json), test XML and logs are retained in `Validation/`. Local workspace prefixes in archived logs are redacted to `<workspace>`.

Initial build attempts exposed a Swift concurrency diagnostic in forwarding a generic Mutex closure. Explicit closure forwarding fixed it without an unchecked annotation or weaker language mode. Review also corrected publication's use of default metadata limits: images/destinations now retain explicit caller limits and combine retained samples with metadata for admission. Regression tests cover both changes.

Initial tooling failures are not counted as passes. Default compiler caches were unwritable in the agent sandbox; workspace cache paths resolved compilation. Xcode 27's default Swift Build backend also passed local debug/release SwiftJ2K tests before the final test expansion. `xcodebuild -list` and a valid temporary workspace both failed with exit 66 amid file-type/CoreSimulator service warnings. Headless compilation and execution were completed through Xcode's `xcrun swift` toolchain. The final reproducible suite used SwiftPM's native backend, which Xcode 27 warns is deprecated. Cache warnings and that deprecation are tooling warnings, not suppressed compiler or sanitizer findings.

## Memory, sample and adapter evidence

`OwnedImageStorage` creates a zero-initialised array behind `Synchronization.Mutex`. Every writer must hold the exact active token; overlapping/reentrant mutable borrows and finish/abort while borrowing fail promptly. Sealing transfers the array to immutable retained storage and removes writable ownership. No unchecked Sendable annotation, persisted unsafe pointer, async pointer borrow or automatic disk staging exists. Unsafe raw fill closures explicitly require callers to prevent pointer escape and bound their own work. The safe UInt16 helper checks cancellation per row and rejects out-of-range meaningful bits instead of truncating.

Tests exercise descriptor arithmetic/overflow, odd and padded layouts, exact/short capacities, plane overlap, native/endian resolution, resource/metadata limits, forged and stale leases, failure/cancellation invalidation, early caller release, exactly-once adapter release, concurrent readers and competing writers. All advertised codec calls compile but reject; a preflight failure leaves an untouched reservation usable, while an error after writing starts invalidates it.

[Integration/ContractHarness](../Integration/ContractHarness) is a separate development-only package, outside all four library dependency graphs. It explicitly maps local descriptors and lease tokens while retaining one owner. Debug, release, ASan and TSan runs each passed three experiments: 12-in-16 and full16 5×3 padded images across four modules, plus a successful local write-lease mapping. Each precision case observed one owner construction, writes and reads through the same allocation UUID, test-only address equality, exact logical samples and zeroed padding. The adapters contain no byte-copy operation. Counters instrument this controlled provider path; they are not a process-wide allocation profile or evidence about future codec algorithms. Synthetic generator definitions, licence and logical-sample SHA-256 values are in [fixtures.json](Validation/fixtures.json).

The original external harness ran from a sibling package with `xcrun swift run`, then independently with `-c release`, `--sanitize=address` and `--sanitize=thread`, separate scratch paths, `--disable-sandbox --build-system native --jobs 2`. Exact source is retained in the integration package. The supplied library has no runtime sibling dependency.

## Limits of this evidence

No codec hot path changed, so no latency, throughput, compression ratio or real-codec peak-memory improvement is claimed. Operation report measurements remain optional/unknown until measured. The caller-controlled raw fill closure is not a decoder executor; full codec deadline/progress scheduling, parser fuzzing, independent codestream oracles and real shared decode/encode remain later milestones.

Swift 6.2 compiler execution, Linux native execution, native Intel execution, physical Apple device tests, codec regression/oracle campaigns, one-hour parser fuzz gates and controlled codec benchmarks are unexecuted. Additional SDK module compilation is recorded separately and does not prove linking or runtime support. No stable release or tag is created.

## Additional Apple SDK compilation

Nine source-module builds passed using Xcode 27 Swift 6.4, explicit Swift 6 language mode and complete concurrency checking: macOS x86_64; iOS/tvOS/visionOS arm64 device and simulator; watchOS arm64_32 device and arm64 simulator. All target deployment versions were 26.0 using installed SDK 27.0. This is module compilation only, not linking, simulator execution or native-device qualification. Exact commands, exit codes and source hashes are in [apple-sdk-compilation.json](Validation/apple-sdk-compilation.json). The complete four-module matrix passed 36 of 36 compiler checks with no diagnostics.

## Final publication-cancellation correction

Independent review found that cancellation inside an external provider's sealing or validation callback could occur after the last cancellation check. The write now constructs its owning image, checks task cancellation immediately before returning, and publishes only on success. A deterministic parameterised regression cancels during `finishAndSeal` and during the returned read-owner validation borrow. Both cases throw `CancellationError` and permanently prevent destination reuse. If the provider has already sealed, its private read owner is discarded without publishing an Image; cleanup cannot reopen that sealed allocation. No workers or pointers outlive the operation.

All final test runs explicitly select Swift Testing with `--disable-xctest`: these packages contain no XCTest cases. The first final-validation attempt executed every Swift Testing case successfully but exited 1 because Xcode 27's empty XCTest compatibility bundle could not be loaded from the separate scratch directory. That failed runner log is retained; the corrected invocation runs all actual tests and returns 0. This is runner selection, not a test skip or suppression of a failing test. All nine Apple SDK module checks were repeated after the source fix and passed.
