# SwiftJ2K — staged implementation instructions

Read AGENTS.md and every common contract document first. Milestone 1 is the current owner-assigned coding task; its implementation and validation status are recorded in `Documentation/MILESTONE_1.md`. Later milestones require a separate assignment. Follow the common contract when predecessor conventions differ. Maintain performance, reliability and security together.

## Source and destination

Predecessor: [Raster-Lab/J2KSwift](https://github.com/Raster-Lab/J2KSwift) at inspected SHA `768f6b53499b806fd0304962056e1fc7833f12e5`. Highest stable-shaped tag observed: `v11.0.3` (resolve independently before choosing it as a baseline). Target module/product: `SwiftJ2K`. Target CLI: `swiftj2k`. Intended first stable library version: `12.0.0`.

Do not migrate code from moving main without recording the selected revision. Reproduce relevant source tests and inspect source-level capabilities. Existing test totals and benchmark claims are historical, not successor acceptance evidence.

## Milestones and exit evidence

| Milestone | Work | Exit evidence |
| --- | --- | --- |
| 1 — contract feasibility | Establish Swift 6.2 package, independent local API/owning-memory types, descriptor validation and safe adapter experiment; no codec algorithm migration | Compiling equivalent public calls, lifecycle/race/error tests, standalone consumer build and contract issues resolved explicitly |
| 2 — migration baseline | Inventory predecessor subsystems/products; select and migrate the smallest native scalar lossless path with MIT/provenance reconciliation | Pinned predecessor comparison, independent decode/encode validation, exact sample/precision results, no new runtime codec dependency |
| 3 — shared-storage path | Direct final decode into caller storage and encode from compatible sealed storage | Required-sharing copy/allocation/lifetime proof; first suite pair or corresponding codec extension passes |
| 4 — feature/platform coverage | Extend supported modes/layouts, CLI, optional acceleration and all required OS/architecture paths | Capability matrix, codec-specific regressions, platform results, security and performance evidence |
| 5 — release preparation | Validate clean versioned consumption, docs/examples, migration guide, licence/fixture notices and release gates | Reviewed complete evidence; stable tag only after explicit release task |

Work one owner-assigned milestone at a time. Preserve internal algorithm names where helpful, but provide the agreed common public module surface. Do not publish a stable version or announce complete platform support while required gates are missing.


### Migration focus

- Inspect `Sources/J2KCore/CompressionFamilyConformance.swift` and `Sources/J2KCodec/CompressionFamilyConformance.swift`. Remove the successor's mandatory CompressionFamily dependency and inherited conformances; provide the agreed local common surface instead. Do not copy the protocol source into each module and claim it is one shared Swift type.
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

## Required handover

Update CHANGELOG.md and migration provenance. Provide the exact commands, commits, fixture hashes and outcomes; report tests not run and why, unsupported cases, allocation/copy evidence and performance impact. Map each advertised feature to a test and capability entry. Keep DICOMKit/Voxelia source changes outside this repository task unless the owner separately assigns them.
