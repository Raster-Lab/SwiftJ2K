# SwiftJ2K — staged implementation instructions

Read AGENTS.md and every common contract document first. Milestone 1 feasibility is implemented; later codec milestones require their own owner-assigned task. Follow the common contract when predecessor conventions differ. Maintain performance, reliability and security together.

For applications upgrading from J2KSwift, use [MIGRATION.md](MIGRATION.md). This implementation plan is for codec developers, not a claim that application cutover is already possible.

## Source and destination

Predecessor: [Raster-Lab/J2KSwift](https://github.com/Raster-Lab/J2KSwift) at inspected SHA `768f6b53499b806fd0304962056e1fc7833f12e5`. Highest stable-shaped tag observed: `v11.0.3` (resolve independently before choosing it as a baseline). Target module/product: `SwiftJ2K`. Target CLI: `swiftj2k`. Intended first stable library version: `12.1.0`.

Do not migrate code from moving main without recording the selected revision. Reproduce relevant source tests and inspect source-level capabilities. Existing test totals and benchmark claims are historical, not successor acceptance evidence.

## Milestones and exit evidence

| Milestone | Work | Exit evidence |
| --- | --- | --- |
| 1 — contract feasibility | Establish Swift 6.4 package, independent local API/owning-memory types, descriptor validation and safe adapter experiment; no codec algorithm migration | Compiling equivalent public calls, lifecycle/race/error tests, standalone consumer build and contract issues resolved explicitly |
| 2 — migration baseline | Inventory predecessor subsystems/products; select and migrate the smallest native scalar lossless path with Apache-2.0/provenance reconciliation | Pinned predecessor comparison, independent decode/encode validation, exact sample/precision results, no new runtime codec dependency |
| 3 — shared-storage path | Direct final decode into caller storage and encode from compatible sealed storage | Required-sharing copy/allocation/lifetime proof; first suite pair or corresponding codec extension passes |
| 4 — feature/platform coverage | Extend supported modes/layouts, CLI, optional acceleration and all required OS/architecture paths | Capability matrix, codec-specific regressions, platform results, security and performance evidence |
| 5 — release preparation | Validate clean versioned consumption, docs/examples, migration guide, licence/fixture notices and release gates | Reviewed complete evidence; stable tag only after explicit release task |

Work one owner-assigned milestone at a time. Preserve internal algorithm names where helpful, but provide the agreed common public module surface. Do not publish a stable version or announce complete platform support while required gates are missing.

### Milestone 2 status — executed 22 September 2026

Milestone 2 is implemented on branch `milestone2/scalar-lossless-j2k` against predecessor `7acc9ae415e7d0bc7d441e0f0277d5e150bd19ca`; evidence is in [MILESTONE2.md](Documentation/MILESTONE2.md) and file-level provenance in [HISTORY.md](HISTORY.md). The migrated scalar path covers: raw JPEG 2000 Part 1 codestreams, one unsigned greyscale component of 1–16 bits, one tile at the origin, reversible 5/3 wavelet with 0–32 levels, no quantisation, default code-block style, one quality layer, any precinct partition, LRCP/RLCP/RPCL progression (PCRL/CPRL only with one precinct per resolution), SOP/EPH markers, several tile-parts, PLT/TLM/COM segments skipped. Everything else in the "Migration focus" list below remains a capability to add: HTJ2K, 9/7 and quantised coding, tiles, layers, colour and signed components, sub-sampling, ROI, POC, PPM/PPT, JP2/JPH containers, acceleration, the auxiliary products, and native transcoding. Contract 0.9.0's continuous-integration precondition was still unmet when this milestone was executed, so the branch is local evidence rather than a merge candidate.


### Migration focus

- The CompressionFamily coupling is already out of the predecessor: J2KSwift pull request 489 (merged 22 September 2026, `7acc9ae`) moved `Sources/J2KCore/CompressionFamilyConformance.swift` and `Sources/J2KCodec/CompressionFamilyConformance.swift` into the separate package `Adapters/J2KCompressionFamily`, and the J2KSwift root manifest declares no external dependency. Nothing from that adapter package migrates; provide the agreed local common surface instead. Do not copy the protocol source into each module and claim it is one shared Swift type.
- Adapt the real `J2KDecoder`/decoder pipeline final-output stage to caller-provided storage. Existing `J2KImage` uses per-component data; `J2KImageBuffer` has copy-on-write owned storage and its Data constructor copies. Those APIs do not prove direct decode-into support. Eliminate final-frame copy-out on the required shared path, while accounting for DWT/coefficient workspace.
- Route the initial unsigned greyscale lossless case through the conformant codec. Preserve declared component precision and sign rules. Inventory multi-tile, reversible/irreversible transform, subsampling, ROI, resolution/progressive, container and component capabilities before adapting them.
- HTJ2K uses the same Encoder/Decoder contract with explicit block-coding options. Standard-compliant HT block format is required for advertised HTJ2K. Isolate any predecessor custom/non-Part-15 representation as legacy experimental material; it must not be selected by standard format defaults or claimed interoperable.
- Review Metal session initialisation, shader resources, NEON/native kernels and platform imports for the new Linux/Watch/Intel matrix. Do not carry unconditional Apple framework access into common parsing or scalar execution. Preserve relevant warm/cold behaviour and record acceleration costs separately.
- Inventory `J2KFileFormat`, `J2KMetal`, `JPIP`, `J2K3D`, daemon/client/test-app products and `J2KDICOMHelpers`. The principal shared image API does not automatically replace those products. Record explicit migration/disposition per product; retain DICOM-specific helpers outside the domain-neutral core. Network/daemon features remain optional and are not required for in-process transcoding.

### Codec-specific tests

Test reversible integer DWT boundaries/overflow, quantisation/lossless-mode validation, entropy termination/truncation, tiles and edge code-block dimensions, component precision/signedness, JP2/codestream metadata and ROI/resolution errors. For HTJ2K, use independent Part-15-capable decoding; do not assume an ordinary JPEG 2000 decoder supports HT. Independently validate both predecessor and successor codestreams.

Carry forward reproducers for empty/zero-coefficient HT blocks, invalid pointer base addresses, malformed packet lengths and report/test-runner failures. Test CPU and each qualified accelerated path for exact lossless samples. Test optional product boundaries separately; a broken daemon or auxiliary product must not be silently removed from the inventory.

### Initial codec delivery — Milestones 2–4

The following codec work follows Milestone 1 contract feasibility. It is not part of the first coding task. Migrate the scalar path in Milestone 2, prove shared storage in Milestone 3, and extend features/CLI/platform coverage in Milestone 4.

Build on the validated common local memory types to implement the direct unsigned 16-bit decode-into path, then cooperate with the SwiftJLS adapter harness. Prove 12-in-16 and full 16-bit precision. Extend HTJ2K using the same proof once classic JPEG 2000 is validated. Do not begin with a broad GPU rewrite.


## Native transcoding work

Implement lossless J2K ↔ HTJ2K using [TRANSCODING.md](TRANSCODING.md) and the common native format-pair API/CLI. Audit the recorded predecessor limitations in Milestone 2; qualify the in-memory native operation in Milestone 3 and extend profiles in Milestone 4. Preserve the initial J2K → JPEG-LS proof and the Milestone 1 feasibility boundary.

## Product dispositions (POL-05)

Decided 22 September 2026 under contract 0.8.0 §3, which requires this inventory before any subsystem is relocated. Measured at predecessor J2KSwift `2fa9a3d` with `swift package dump-package`. "Imports" counts files across DICOMKit, CompressionFamily, VoxeliaValidation, DICOMAdapter, RasterOneImage, OneImageViewer-iOS and telerad-dicom-viewer containing a top-level `import <module>`.

POL-05 requires every product to be explicitly **retained** (migrates, stays a public product), **adapted** (migrates with a changed shape — folded into the principal module, renamed, or re-expressed through the common API) or **deferred** (does not migrate for the first stable; stays with the predecessor through the maintenance window). Deferred is not deleted.

| Predecessor product | Files / lines | Imports | Disposition | Successor | Basis |
| --- | --- | --- | --- | --- | --- |
| `J2KCore` | 22 / 8,927 | 15 | Adapted | internal target of `SwiftJ2K` | API-01 names the principal product and module exactly `SwiftJ2K` and allows internal targets to preserve useful algorithm boundaries |
| `J2KCodec` | 82 / 63,930 | 6 | Adapted | internal target of `SwiftJ2K` | API-01 |
| `J2KFileFormat` | 8 / 7,323 | 1 | Adapted | internal target of `SwiftJ2K` | API-01 |
| `J2KContract` | 7 / 1,106 | 0 | Adapted — folded in | `SwiftJ2K` | It exists because `CompressionMode`, `EncodedImage` and `ImageMetadata` already meant something else inside a module named `J2KSwift`. The rename dissolves the collision. Contract 0.8.0 §5 forbids two parallel surfaces in one module. |
| `J2KMetal` | 22 / 19,244 | 1 | Adapted | internal target, selected through `executionPolicy` | API-07 makes a backend a per-operation option reported back in `OperationReport`; PLAT-05 makes acceleration optional and availability-guarded |
| `J2K3D` (JP3D) | 29 / 8,879 | 5 | **Retained** | `SwiftJ2K3D` | API-13 treats volume coding as a clearly named extension operation rather than an interchangeable common one |
| `JPIP` | 30 / 13,955 | 2 | **Retained** | `SwiftJ2KJPIP` | API-13 names JPIP explicitly as not interchangeable with the single-image contract |
| `J2KDICOMHelpers` | 11 / 1,647 | 0 | Deferred — retired | none | POL-05 keeps transfer-syntax negotiation and photometric policy in consumers. DICOMKit already owns `DICOMCore/PhotometricInterpretation.swift` and `DICOMCore/TransferSyntaxConverter.swift`, and nothing imports this product. |
| `j2k` (exec) | 1 / 16 + `J2KCLICore` | — | Adapted — renamed | `swiftj2k` | CLI-01 fixes the successor executable names |
| `j2kd` (exec) | 1 / 82 | — | Deferred | none | macOS-only XPC daemon; no importer, and a daemon-plus-fallback execution model is not part of the contract's operation surface |
| `J2KDaemonProtocol` | 1 / 177 | 0 | Deferred | none | as `j2kd` |
| `J2KDaemonCore` | 2 / 414 | 0 | Deferred | none | as `j2kd` |
| `J2KDaemonClient` | 1 / 275 | 0 | Deferred | none | as `j2kd` |
| `J2KTestApp` (exec) | 23 / 7,475 | 0 | Deferred — dev tooling | none | TESTING keeps development-only tools outside the shipped dependency graph |

**Product list after migration:** `SwiftJ2K`, `SwiftJ2K3D`, `SwiftJ2KJPIP` (libraries) and `swiftj2k` (executable). Fourteen products become four.

`Sources/J2KCore/CompressionFamilyConformance.swift` and `Sources/J2KCodec/CompressionFamilyConformance.swift` were the entire CompressionFamily coupling. Contract 0.8.0 §4 is satisfied: J2KSwift pull request 489 (merged 22 September 2026, `7acc9ae`) moved them, with their pin-down tests, into the separate package `Adapters/J2KCompressionFamily` in the predecessor repository, which depends on J2KSwift by path and on CompressionFamily by URL. The J2KSwift root manifest now declares no external dependency, so `SwiftJ2K` resolves alone. The adapter package is predecessor-compatibility surface and does not migrate. CompressionFamily itself is untouched and stays available to predecessor consumers under POL-04.

### Decisions recorded with these dispositions

**M1 — `J2KMetal` becomes an internal target.** A caller requests acceleration through `executionPolicy` and reads back the backend actually used, instead of importing the backend module. This is a source change rather than a rename for DICOMKit's `Sources/DICOMCore/CodecBackend.swift`, its single importing file, and belongs in DICOMKit's separately assigned cutover task.

**M2 — `SwiftJ2K3D` and `SwiftJ2KJPIP` ship in the first stable 12.1.0.** DICOMKit imports the two across seven files — `DICOMCore/JP3DCodec.swift`, `DICOMKit/JP3DVolumeDocument.swift`, `DICOMKit/JP3DVolumeBridge.swift`, `DICOMKit/DICOMKit+Volume.swift`, `DICOMKit/DICOMVolume.swift`, `DICOMKit/DICOMJPIPClient.swift` and the `dicom-jpip` executable. Deferring them past 12.1.0 would leave DICOMKit unable to complete its cutover and extend the predecessor maintenance window indefinitely, so they migrate carrying their existing public surface. Aligning that surface with the common contract is later milestone work under API-13, not a condition of the move.

**M3 — `J2KDICOMHelpers` retires with the predecessor.** It is not transplanted into a consumer, because DICOMKit already implements the same domain. One audit before the predecessor is archived: confirm `J2KDICOMCodestreamDetector` has a DICOMKit equivalent. If it does not, that single file transplants to DICOMKit and the rest still retires.

**CLI surface.** Retained and adapted: the CLI-01 verbs `encode`, `decode`, `inspect` (renamed from `Info`), `validate` and `capabilities`, plus `transcode` under POL-09. Deferred to a CLI milestone after the first stable: `Batch`, `Benchmark`, `Compare`, `Convert`, `Completions`, `Headless`, `InProcBench` and the `Encode3D`/`Decode3D`/`JPIPClient`/`JPIPServer` commands. Deferred under POL-05: `DICOMSupport`. Deferred as predecessor-compatibility surface: `OPJCompress`, `OPJDecompress` and `OPJDump` — these are native Swift commands mirroring OpenJPEG's flag syntax, not shell-outs, so POL-01 does not forbid them; they are simply not part of the successor's contract surface.

## Required handover

Update CHANGELOG.md and migration provenance. Provide the exact commands, commits, fixture hashes and outcomes; report tests not run and why, unsupported cases, allocation/copy evidence and performance impact. Map each advertised feature to a test and capability entry. Keep DICOMKit/Voxelia source changes outside this repository task unless the owner separately assigns them.

## Owner-authorised OS 27 and CLI foundation

Before codec migration, the owner requested executable help, verbosity and UNIX manuals. Apple floors were briefly raised to 27.0 in contract 0.4.0 and returned to 26.0 in 0.5.0. This bounded CLI foundation implements help/version/capabilities only; codec commands remain explicitly unavailable. See [CLI.md](CLI.md) and [new evidence](Documentation/Engineering/OS27CLI/README.md). The later codec/CLI milestones still govern real payload operations.
