# Migrating applications from J2KSwift to SwiftJ2K

The successor now requires Swift 6.4 and retains its OS 27 deployment floors. See the [Swift 6.4 upgrade record](Documentation/Engineering/Swift64/README.md) for development versioning and validation; current codec availability is unchanged.

For application maintainers and coding agents. This guide covers **consumer application migration**; [IMPLEMENTATION.md](IMPLEMENTATION.md) governs migration of codec algorithms into this library.

## Readiness and revision baseline

**The current successor is Milestone 1 API/ownership feasibility, not a replacement JPEG 2000 codec.** You can trial its descriptors, owning storage and common call shapes. `Encoder`, `Decoder` and `Transcoder` advertise no codec capabilities; encode, decode, inspect and transcode reject with defined errors. Keep the predecessor supplying real compression/decompression until the exact successor features your application needs are implemented and independently qualified. An unsupported error must not become an empty file, a black image or a successful migration result.

This guide uses suite contract **0.4.0**, [current successor source](Sources/SwiftJ2K), and [J2KSwift snapshot 768f6b53](https://github.com/Raster-Lab/J2KSwift/tree/768f6b53499b806fd0304962056e1fc7833f12e5). These are source snapshots, not a claim that every older release has the same API. Record your application's actual resolved revision and compare it before applying the mappings below. See [HISTORY.md](HISTORY.md) for provenance and [MILESTONE1.md](Documentation/MILESTONE1.md) for executed tests and missing gates. Intended version `12.1.0` is not a published release.

## Dependency, product and platform changes

| Application dependency | Predecessor | Successor and action |
| --- | --- | --- |
| Repository | `Raster-Lab/J2KSwift` | `Raster-Lab/SwiftJ2K` |
| Principal SwiftPM products/imports | `J2KCore`, `J2KCodec` | Product/module `SwiftJ2K`; use `import SwiftJ2K` in the new adapter target |
| Shared protocol dependency | `CompressionFamily` conformances on J2K types | No inherited conformances or shared runtime package; adapt local concrete types explicitly |
| Minimum tools | Consult the application pin; inspected predecessor uses Swift 6.2 | Swift 6.4 tools minimum, Swift 6 language mode |
| Apple deployment floors | Inspected manifest: macOS 15, iOS/tvOS 18, watchOS 10, visionOS 1 | All five successor deployment floors are 27.0; older-OS applications cannot replace their existing target directly |
| CLI | `j2k` | `swiftj2k` provides help/version/capabilities; codec commands remain unavailable |

In an isolated application migration branch, add the successor URL `https://github.com/Raster-Lab/SwiftJ2K.git` to SwiftPM or Xcode Package Dependencies, select a reviewed immutable revision containing `Package.swift`, and add `.product(name: "SwiftJ2K", package: "SwiftJ2K")` to the new adapter target. Pin the reviewed Swift 6.4 candidate revision recorded by your application; an earlier feasibility revision does not include this upgrade. Do not use `from: "12.1.0"` until an actual qualifying release exists. Commit the application's updated `Package.resolved` where appropriate. Package identities derive from repository/directory names; give a standalone consumer a distinct name/directory.

Keep old and new dependencies side by side only in the application during evaluation. Qualify symbols such as `J2KCodec.J2KDecoder` and `SwiftJ2K.Decoder`. The successor must not gain a dependency on the predecessor, another suite codec or a replacement shared-foundation library. Remove the application's CompressionFamily dependency only after checking every remaining consumer. A runtime availability check alone does not establish a valid package/deployment configuration; preserve a separately supported legacy application target or postpone cutover for older OS versions.

## Operation and image mapping

These are **API mappings**, not a statement that successor codec work runs today. Exact predecessor signatures are in [J2KCodec.swift](https://github.com/Raster-Lab/J2KSwift/blob/768f6b53499b806fd0304962056e1fc7833f12e5/Sources/J2KCodec/J2KCodec.swift) and image fields in [J2KCore.swift](https://github.com/Raster-Lab/J2KSwift/blob/768f6b53499b806fd0304962056e1fc7833f12e5/Sources/J2KCore/J2KCore.swift).

| Existing use | Successor shape | Migration consequence |
| --- | --- | --- |
| `J2KEncoder(configuration:)` / `J2KEncoder(encodingConfiguration:)` | `try SwiftJ2K.Encoder(configuration:)` with `EncoderConfiguration` | Constructors/configuration validate; old quality, rate control and transform fields have no implemented option mapping yet |
| `try await encoder.encode(image)` returning `Data` | `try await encoder.encode(image, options:)` returning `EncodedImage` | Future successful output uses `.data`, `.encoding`, `.report`; current operation throws |
| `J2KDecoder()` / `decode(_:)` returning `J2KImage` | `try SwiftJ2K.Decoder(configuration:)` / `decode(_:options:)` returning `DecodedImage` | Future successful output uses `.image` and `.report`; current operation throws |
| Component-owned `J2KImage` / `J2KImageBuffer` | `ImageDescriptor` + `ImageDestination` + sealed `Image` | Explicit precision/layout and retained storage replace mutable component/Data assumptions |
| Decoder-owned final image | `decode(_:into:options:)` | Caller-storage signature exists; real direct decode is not implemented |
| Predecessor format/metadata parsing | `inspect(_:options:) -> ImageInfo` | Signature only; keep required predecessor parsing until successor coverage is qualified |
| `J2KError` cases | `CodecError.category` and `CancellationError` | Map application error handling explicitly, not by matching diagnostic strings |
| `J2KTranscoder` direction-based calls | `Transcoder.transcode(_:to:options:)` with `.jpeg2000` / `.htj2k` | Planned pair, empty capabilities; no operational transcoder yet |

The pinned predecessor's `J2KEncoder()` uses `J2KConfiguration()` with `quality: 0.9, lossless: false`; the successor's default configuration models lossless fidelity. Choose the application's intended fidelity explicitly before eventual cutover: substituting default constructors does not preserve output quality or size. `CodecOptions` has no controls yet; positive near-lossless requests and lossy requests are unsupported, not alternative ways to obtain working output. Do not translate legacy numeric quality or HT controls by guessing a new field or changing fidelity. Revisit [COMMON_API.md](Documentation/COMMON_API.md) and actual capabilities at the chosen future revision.

## Adapting sample storage now

The first tested sample-helper profile is unsigned, one greyscale plane, 16-bit storage with explicit meaningful precision, concrete byte order, and packed or padded rows. General descriptors admit some other layouts; that does not imply an encoder/decoder supports them. Some predecessor component precision, subsampling, tile/grid-origin and colour combinations have no equivalent implemented profile. Preserve their requirements in the migration inventory rather than dropping them.

`J2KComponent.data` contains per-component bytes; `sampleByteOrder` can be absent in the pinned predecessor and its encoder may infer the order. Determine the actual producer's byte order and packing before conversion. Set `storageBits` separately from `meaningfulBits`; a 12-bit source in 16-bit words remains 12-bit even when all values happen to fit eight bits. Do not reinterpret signed samples as unsigned, interleave planar components blindly, truncate higher precision, infer colour meaning or apply windowing/rescaling. Required metadata and DICOM interpretation stay in application adapters.

A first application adapter may explicitly copy known logical samples into `ImageDestination.allocate(...).writeUInt16`; document the copied bytes and retained memory. This is an application conversion, not proof of a no-copy codec hand-off. Neither retaining a token beside `Data.withUnsafeBytes` nor escaping an array pointer creates an owning storage provider. Advanced providers must implement the complete exclusive lease lifecycle and retain the real allocation. See [MEMORY_CONTRACT.md](Documentation/MEMORY_CONTRACT.md); same-named types from different modules require explicit adapters.

This complete standalone Swift example runs with only the successor product linked. It demonstrates a deliberate sample copy and confirms the expected unsupported codec result; it does not convert a JPEG 2000 file. The existing [consumer package](Examples/Consumer) provides a buildable package layout.

```swift
import Foundation
import SwiftJ2K

@main
struct MigrationExample {
    static func main() async throws {
        // Known application samples after validating the predecessor's packing.
        let samples: [UInt16] = [0, 4095, 17, 2048, 1, 4094]
        let limits = try SwiftJ2K.ResourceLimits(
            maximumDecodedBytes: 1024, maximumMemoryBytes: 4096)
        let descriptor = try SwiftJ2K.ImageDescriptor.greyscale16(
            width: 3, height: 2, meaningfulBits: 12, rowBytes: 8, limits: limits)
        let destination = try SwiftJ2K.ImageDestination.allocate(
            descriptor: descriptor, limits: limits)
        let image = try destination.writeUInt16 { x, y in samples[y * 3 + x] }
        guard try image.sampleUInt16(x: 1, y: 0) == 4095 else {
            throw SwiftJ2K.CodecError(.internalFailure, "Sample adapter mismatch.")
        }
        let encoder = try SwiftJ2K.Encoder()
        guard !encoder.capabilities.canEncode else {
            throw SwiftJ2K.CodecError(.internalFailure, "Revisit this milestone example.")
        }
        do {
            _ = try await encoder.encode(image, options: .init(resourceLimits: limits))
            throw SwiftJ2K.CodecError(.internalFailure, "Unexpected codec success.")
        } catch let error as SwiftJ2K.CodecError where error.category == .unsupportedFeature {
            print("Storage migration example passed; keep predecessor codec routing.")
        }
    }
}
```

`Image` is immutable and retains its sealed owner. Allocate a new destination for new writable contents. One destination accepts one write; a failed/cancelled write cannot be reused. Preflight rejection before writing leaves an untouched reservation available to its caller. Handle cancellation as `CancellationError`, including cancellation during provider finalisation; never publish partial application output.

Resource limits are finite and count row padding, retained storage and metadata. Carry explicit limits through construction and operations. `requireSharedStorage` and metadata preservation are defaults; `allowCopy` permits only reported value-preserving layout conversions once a codec implements them. Unknown report measurements remain `nil`. Configuring a deadline or progress callback on current codec stubs does not demonstrate an operating kernel, backend or progress scheduler. Current async call shapes use an explicit executor policy; a UI should await results, dispatch UI updates to its actor and avoid blocking it with synchronous conversion loops.

## Features and auxiliary products requiring separate decisions

| Existing dependency/behaviour | Application action before cutover |
| --- | --- |
| Classic J2K, HTJ2K, JP2/JPH, tiles, ROI, progressive/resolution decode, component transforms | Inventory exact profiles; await implemented capability entries, independent oracles and sample/metadata tests |
| `J2KFileFormat`, `J2KMetal`, `J2KDecoder.preWarm()` and native acceleration controls | No direct successor product or warm-up replacement; retain legacy route until separately supported |
| `JPIP`, `J2K3D`, `J2KDICOMHelpers` | Not replaced by the common image API; retain or explicitly defer each integration |
| `j2kd`, `J2KDaemonProtocol`, `J2KDaemonCore`, `J2KDaemonClient`, `J2KTestApp` | No successor equivalent in this milestone; application/service migration is separate |
| `j2k` commands, exit codes, scripts and pipes | Keep codec scripts on `j2k`; `swiftj2k` currently provides diagnostic commands only ([CLI guide](CLI.md)) |
| Native J2K ↔ HTJ2K transcode | Follow [TRANSCODING.md](TRANSCODING.md); future lossless preservation means exact samples/interpretation, not identical compressed bytes |

Predecessor transcoder success is not by itself an oracle: recorded zero-on-error and packet/quantisation limitations require independent validation. Keep original compressed fixtures immutable. Existing file-format bytes are not rewritten merely because a Swift package is renamed.

## Migration sequence for humans and coding agents

1. Record the application's lockfile revision, imported products, supported OS versions, call sites, pixel layouts, precision/signedness, metadata obligations, CLI/service use and representative licensed fixtures. Record baseline outputs and known failures from that exact application/predecessor combination.
2. Add a separate successor adapter target on an application feature branch. Compile the package/import and sample-storage example first. Keep the real predecessor backend selected; make selection explicit, not a hidden fallback inside SwiftJ2K.
3. Map only supported descriptors and error categories. Add boundary/stride/precision and lifetime tests for the application adapter. Preserve unsupported functionality and list it as a blocker; do not remove tests or reduce bit depth to obtain a green build.
4. Before enabling any future successor codec route, verify format/mode/layout/metadata support and every used auxiliary product at the pinned revision. Validate old encode → new decode and new encode → old/independent decode. For lossless output compare every logical sample, meaningful precision and interpretation. A self-round-trip, successful build or same buffer address is insufficient.
5. Measure application copies/allocations, cancellation, failure cleanup, latency and peak memory under the actual workload. Exercise each supported deployment target. Test required acceleration failure versus preferred fallback without silently changing fidelity.
6. Cut over one qualified profile at a time behind an application-controlled rollout switch. Retain the previous package pin, adapter and original fixtures for rollback. Remove predecessor dependencies only after no production call site or optional product needs them.
7. Report changed call sites, exact before/after revisions, executed commands, results, conversion costs, blockers and rollback steps in the application PR. Mark storage-only work as partial migration. This guide does not authorise a coding agent to implement later codec milestones or modify a downstream application unless assigned that work.

A completed application migration requires working successor operations for every enabled profile, passing independent fidelity/metadata and platform tests, and an exercised rollback route. **Those codec cutover gates cannot be passed by the current Milestone 1 implementation.** As later releases add capabilities, update this guide and its executable example together; keep the tested revision and remaining gaps explicit.

## Apple runtime qualification update

See [Apple platform runtime qualification](Documentation/Engineering/ApplePlatforms/README.md) for executed OS 27 simulator, macOS and Mac Catalyst tests and the reproducible headless runner. This qualifies the current API/storage foundation; the existing codec migration and production-cutover gates remain in force.
