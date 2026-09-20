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
| Successor licence | MIT, for owner-authorised in-house material |
| Inspection date | 2026-09-17 |

The tag and the inspected branch snapshot are separate references; this record does not assert they resolve to the same commit. Before migrating a tagged baseline, resolve annotated tags to commits and record the exact chosen SHA. The pinned snapshot above was read for documentation preparation; it was not independently built or regression-tested in this task.

## Migration provenance requirements

The coding agent must record source repository, commit, original path and successor path for each migrated subsystem, and distinguish copied/adapted in-house material from new implementation. Record retained tests, fixture licences and explicit product/feature dispositions. Keep predecessor bug history accessible through links. Do not import old tags, rewrite predecessor history or imply all historical commits have been relicensed.

The owner states the implementation is in-house and has authorised MIT relicensing. Preserve accurate original copyright years and ownership. Audit any third-party dependencies, tools or fixtures separately. The MIT root licence is not authority to remove another party's notices.

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
