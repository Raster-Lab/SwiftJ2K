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

## Milestone 1 implementation — 18 September 2026

The owner assigned one coding agent per successor, coordinated against contract 0.2.1. This milestone creates new in-house API, descriptor, owning-memory, test and CI code. No predecessor algorithm, third-party codec or fixture was migrated. Synthetic tests create their samples in memory. The pinned predecessor snapshots above remain the sources to audit before Milestone 2. See `Documentation/MILESTONE_1.md` for validation outcomes and limitations.
