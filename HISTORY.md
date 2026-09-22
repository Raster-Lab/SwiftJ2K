# History and provenance — SwiftJ2K

## Documentation foundation — 17 September 2026

The owner chose four fresh repositories under Raster-Lab, with independent codecs, a common API and memory contract, MIT licensing and an optional adapter-based umbrella. The previous proposal for a new shared-foundation package, SwiftCompressionFamily 2.0.0, was superseded. The intended first stable release here is 12.0.0; no library version has been released or tagged by this foundation.

| Item | Recorded source |
| --- | --- |
| Predecessor | [Raster-Lab/J2KSwift](https://github.com/Raster-Lab/J2KSwift) |
| Default branch observed | main |
| Inspected source snapshot | [768f6b53499b806fd0304962056e1fc7833f12e5](https://github.com/Raster-Lab/J2KSwift/commit/768f6b53499b806fd0304962056e1fc7833f12e5) |
| Highest stable-shaped tag observed | [v11.0.3](https://github.com/Raster-Lab/J2KSwift/tree/v11.0.3) |
| Source-tree licence observed | MIT |
| Successor licence | Apache-2.0, for owner-authorised in-house material (contract 0.8.0) |
| Inspection date | 2026-09-17 |

The tag and the inspected branch snapshot are separate references; this record does not assert they resolve to the same commit. Before migrating a tagged baseline, resolve annotated tags to commits and record the exact chosen SHA. The pinned snapshot above was read for documentation preparation; it was not independently built or regression-tested in this task.

## Migration provenance requirements

The coding agent must record source repository, commit, original path and successor path for each migrated subsystem, and distinguish copied/adapted in-house material from new implementation. Record retained tests, fixture licences and explicit product/feature dispositions. Keep predecessor bug history accessible through links. Do not import old tags, rewrite predecessor history or imply all historical commits have been relicensed.

The owner states the implementation is in-house and has authorised Apache-2.0 relicensing (contract 0.8.0; the foundation recorded this as MIT). Preserve accurate original copyright years and ownership. Audit any third-party dependencies, tools or fixtures separately. The root licence is not authority to remove another party's notices.

The originals are intended to become maintenance projects while new development moves here. No predecessor settings, README, branch, release, licence or archive flag was changed during this documentation preparation. Maintenance announcements and downstream DICOMKit/Voxelia migration are separate work.

## Native transcoding source review — 18 September 2026

Re-inspected the same pinned predecessor snapshot for the owner-requested native transcoding instructions. [TRANSCODING.md](TRANSCODING.md) records concrete entry points, test assertions, known limitations and required successor corrections. Source presence/control flow were reviewed; no codec build, test or benchmark was executed. No predecessor files were changed.

## Swift 6.4 development upgrade — 19 September 2026

The owner assigned the successor upgrade before Milestone 2 and requested version increments. Starting from `6d5b88d661ad88d1762f038273e0fec2f618b622`, the candidate requires Swift tools 6.4 in Swift 6 language mode, advances shared contract 0.2.1 to 0.3.0 and advances the unreleased 12.0.0 target to 12.1.0 (`12.1.0-dev.1` development identifier). Platform floors, public API signatures, licensing and codec milestone scope are preserved. This is not a release/tag. The [upgrade record](Documentation/Engineering/Swift64/README.md) keeps current evidence separate from the earlier historical reports.

## OS 27 and CLI foundation — 19 September 2026

Owner-authorised Apple platform floors now use 27.0. Development version 12.1.0-dev.2, common contract 0.4.0. The standalone `swiftj2k` provides help/version/capabilities, five diagnostic levels and a matching section 1 manual installed/updated with the binary. Codec commands remain unavailable. Endian-aware span overloads use the new floor without changing public ownership semantics. See [qualification and limitations](Documentation/Engineering/OS27CLI/README.md). Historical evidence and supplied documents remain unchanged.
## Apple floor restored to 26.0 — 20 September 2026

Contract 0.5.0 reverses the 0.4.0 raise of the Apple deployment floors to 27.0 and returns them to 26.0. Verification found that no generally available Xcode ships OS 27 SDKs, that no stable `macos-27` continuous-integration runner exists, and that Swift 6.4.0 rejects a 27.0 deployment target because its supported range ends at 26.5.x. Every OS 27 qualification claim was therefore unreproducible.

The raise was not an independent platform decision. Contract 0.4.0 adopted the OS-27-gated byte-order span overloads, and the floor moved so that they would compile. Contract 0.3.0 had already specified the correct treatment, explicit fixed-width integer endian conversion without raising the runtime floor, and that rule is restored. The compiler minimum returns to Swift 6.2 with Swift 6.4 retained as the qualified primary toolchain, because a manifest floor constrains consumer resolution and every current consumer resolves at 6.2.

Public signatures, ownership and fidelity semantics, milestone boundaries and Linux scope are unchanged. The OS 27 and Swift 6.4 records remain as history, marked superseded where they assert a platform baseline.

## Shared-storage rules refined from measurement — 20 September 2026

Contract 0.6.0 amends seven memory rules and adds one testing rule. Exploratory spikes ran the caller-storage question against all four predecessor codecs in both directions before any migration work, and every amendment comes from something those spikes measured or broke rather than from anticipated design.

The central finding reverses a standing assumption. `CopyPolicy.requireSharedStorage` is reachable in every codec, and each library reaches caller samples through exactly one stage, so pointing that stage at caller memory is small and local. What blocks the policy is the container each library exposes — `Data` per component, a packed `[UInt8]` with no row stride, a `[[Int]]` façade over an already-flat interior, or an initialiser that rejects any buffer that is not the packed frame size. A caller holding a padded plane cannot describe an image without first copying it. The `Image`/`ImageDescriptor` layer is therefore not packaging around working codecs; it is the Milestone 3 work.

This codec drives three of the seven amendments. Its encode and decode are `async`, so a pointer parameter cannot satisfy MEM-08 and the owner requirement in MEM-06 follows from it. Its decoder emits big-endian 16-bit samples against the shared layout's little-endian, which MEM-12 now requires it to convert on the shared path. Its spatial-domain `[Double]` workspace is four times the final frame, which MEM-10 now requires it to state.

Measured effects, all from a developer machine: live heap held after one JPEG 2000 decode fell from 16 MB in 6 blocks to 1 KB in 2 at 2048×2048, and for JPEG XL from 2 MB to nothing at 1024×1024; the JPEG 2000 output stage ran 9–35% faster writing the caller's plane; and on the encode side the copy a caller must make today costs 5.5 ms and 8 MB at 2048×2048 while the widening loop costs the same either way. Four defects surfaced during the work: inferred plane origins shearing padded multi-plane output, a shared encode that dropped its container wrapper and was caught only by comparing bytes rather than samples, a harness that bound an owner to storage released on the same line, and an address-sanitizer run reporting 100 MB live on a path holding nothing, which a probe traced to the sanitizer quarantining freed blocks.

The spikes are exploratory and are not proposed for merge into the predecessor repositories. No platform, milestone, release or CLI decision changes, and continuous integration remains blocked, so none of these results is a release gate.

## Decision D1 — codec libraries stay where they are, 20 September 2026

Contract 0.7.0 settles the programme's open architectural question. The shipping codec libraries are the existing repositories; the four contract repositories hold the shared documents, the reference implementation of the shared image layer and the cross-codec conformance harness. No codec source is relocated and nothing is deleted.

The Milestone 3 spikes decided it. All four codec interiors proved contract-capable through single-point changes, and the obstacle to caller-owned storage is the public image type rather than the codec, so the remaining work is additive and identical in size wherever it is done. Migration would have paid, on top of that identical work, the relocation of roughly 219,000 lines of codec source and 184,000 lines of tests together with fixtures and cross-codec oracles, with no continuous integration available to catch what such a move breaks. The contract repositories hold about 1,000 lines of source each, so little built work is given up; three in-house consumers already resolve the existing libraries by URL at pinned released versions, and none references a contract repository.

J2KSwift keeps its codec, its 144,755 lines of source and its 129,822 lines of tests. It carries the largest in-place obligations: thirteen products including a daemon to inventory and split under POL-05, and a CompressionFamily dependency confined to two conformance files to extract so the core library resolves alone. DICOMKit and CompressionFamily both consume it by URL at pinned released versions.

Two matters are referred to the owner rather than assumed: the Apache-2.0 and MIT split between the existing libraries and the contract repositories, which POL-07 authorises resolving but which should be a deliberate choice; and the inventory and splitting of auxiliary predecessor products under POL-05. The decision rests on documentation evidence gathered on one machine and authorises no codec milestone or release.

## Decision D2 — codec libraries relocate here, 22 September 2026

Contract 0.8.0 supersedes Decision D1. The owner has reaffirmed the repository foundation v0.1.0 as the guidance for this migration and instructed that the codecs move into the successor repositories. Under document precedence rule 1 the owner's current explicit decision outranks a previous contract revision.

J2KSwift relocates here: 144,755 lines of source and 129,822 lines of tests, with its fixtures and oracles. The predecessor source is MIT-licensed and is relicensed to Apache-2.0 under POL-07 as amended; Raster Images Private Limited holds that copyright, and third-party fixtures and dependencies keep their own terms. It carries the largest obligations: thirteen products including a daemon to inventory and split under POL-05, a CompressionFamily dependency confined to two conformance files to extract, 226 MB of test fixtures with no Git LFS configured and whose provenance must be audited before they enter this history, and no CI workflow of any kind. DICOMKit and CompressionFamily both consume it by URL.

The sequence is a final J2KSwift release at v12.0.0, then relocation, then a first stable 12.1.0 here once the TEST-07 gates pass, then a maintenance window on the predecessor, then its archive. J2KSwift is not renamed or deleted: this repository's HISTORY.md and MIGRATION.md pin its commits and source files by permalink, and those links are the provenance record.

D1's measurements are retained as the risk register rather than discarded. The continuous-integration objection is unresolved and becomes a precondition: the organisation's Actions billing remains locked, a re-run of JLSwift's CI on 22 September 2026 completed with `steps=0`, and no codec source moves before CI executes and passes here. This record authorises no codec milestone and no release.
