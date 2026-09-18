# SwiftJ2K

JPEG 2000 and HTJ2K for the **Swift Image Compression Suite**.

**Status: documentation foundation. No implementation has been migrated, created, built or validated in this successor.** The intended first stable library version is **12.0.0**; it is not a published release. No Package.swift or installable package is present yet.

SwiftJ2K is the standalone successor to [J2KSwift](https://github.com/Raster-Lab/J2KSwift). The successor is intended to provide a harmonised API, explicit memory ownership, high-precision sample preservation and efficient shared-storage integration. It has no mandatory dependency on another suite library or CompressionFamily. MIT licensing applies to these documents and subsequent authorised in-house implementation; third-party material retains its own terms.

## Intended platform baseline

Swift 6.2 minimum, Swift 6 language mode and complete concurrency checking. Apple OS deployment minima: macOS, iOS/iPadOS, tvOS, visionOS and watchOS 26.0. Apple Silicon is the primary optimisation target. macOS x86_64 and Linux ARM64/x86_64 are included with cleanly separated platform/architecture support. Ubuntu 24.04 is the initial Linux engineering baseline. These are requirements, not completed qualification claims.

## Start reading

The first coding task is **Milestone 1: API and memory-contract feasibility**, using synthetic buffers. Codec migration and the first real shared-storage transcode follow in Milestones 2 and 3. Use the ready-to-use task prompt in [AGENTS.md](AGENTS.md).

- [Coding-agent entry point](AGENTS.md) and [codec-specific implementation plan](IMPLEMENTATION.md).
- [Suite policy](Documentation/SUITE_POLICY.md) and [common API](Documentation/COMMON_API.md).
- [Memory ownership and no-copy hand-off](Documentation/MEMORY_CONTRACT.md).
- [Unit, regression and security testing](Documentation/TESTING.md).
- [Performance gates](Documentation/PERFORMANCE.md), [platforms](Documentation/PLATFORMS.md) and [CLI](Documentation/CLI_CONTRACT.md).
- [History and source provenance](HISTORY.md), [change log](CHANGELOG.md), [security](SECURITY.md), [contributing](CONTRIBUTING.md) and [MIT licence](LICENSE).

## Native in-memory transcoding

Planned standalone **lossless J2K ↔ HTJ2K transcoding** keeps intermediate coefficients or a shared uncompressed image in memory. Both directions preserve samples and required interpretation; original compressed bytes may differ. The predecessor contains a transcoder, but source review found correctness shortcuts that must be corrected and independently tested. See [transcoding instructions and source-review findings](TRANSCODING.md) for the API/CLI pattern, limits and acceptance tests. This remains planned successor functionality.

## Relationship to the suite

The four independent libraries are SwiftJ2K, SwiftJLS, SwiftJXL and SwiftJLI, all intended to live under Raster-Lab. A future optional umbrella adapts them for codec selection and in-process transcoding. The codecs do not depend on that umbrella. SwiftCompressionFamily is not part of this successor plan. The common contract is mirrored documentation plus behavioural tests, not a shared runtime package.

The planned main module is `SwiftJ2K` and the planned CLI is `swiftj2k`. Actual API usage examples will be published only after they compile and run. Features from the predecessor are migration candidates whose exact coverage must be verified; see IMPLEMENTATION.md. Nothing here changes the predecessor repository's current maintenance configuration.
