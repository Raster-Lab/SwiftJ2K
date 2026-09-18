# Change log

## Unreleased — application migration guide, 2026-09-18

- Added MIGRATION.md for humans and coding agents moving applications from J2KSwift, with verified dependency/API mappings, precision and ownership changes, explicit feature gaps, and staged rollout/rollback guidance.
- Linked the guide from README, agent instructions, contributor guidance, implementation and transcoding plans. Codec availability is unchanged.

## Unreleased — Milestone 1, 2026-09-18

- Final Milestone 1 review: prevent image publication when cancellation occurs inside provider sealing/validation; deterministic regressions and full checks pass.
- Added the independent Swift 6.2 package and common local API, checked descriptors, zero-initialised owning storage and exclusive lease lifecycle.
- Added safe synthetic 12/16-bit sample access, caller resource-budget validation and clearly unsupported codec/native-transcoder entry points.
- Refined the mirrored suite contract to 0.2.1 with concrete lease and preflight semantics.
- Debug/release, independent consumer, AddressSanitizer and ThreadSanitizer checks passed using Xcode 27 headlessly; see Documentation/MILESTONE1.md for exact results and unavailable gates.
- Added a separate four-module adapter experiment. No codec algorithm, CLI, accelerated backend or release tag is included.

## Unreleased — documentation foundation, 2026-09-17

- Defined the standalone SwiftJ2K successor and intended first stable version 12.0.0.
- Added the common API, memory, platform, CLI, testing and performance specifications, codec-specific agent instructions, source provenance and MIT licence.
- No source migration, implementation, package manifest, executable test, binary or release tag is included.
- No runtime behaviour, support matrix or performance result is claimed as verified.

## Documentation clarification — contract 0.1.1, 2026-09-17

- Aligned the suite policy, README and agent handoff with the staged implementation plan: contract feasibility first, codec migration second, shared-storage integration third.
- Added explicit Milestone 1 test evidence and labelled the later codec delivery sections to prevent accidental expansion of the first task.
- Mirrored all seven common documents and regenerated their SHA-256 manifest across the four repositories. API/memory behaviour, platform floors, intended library versions and release gates are unchanged.
- Verified documentation consistency and links; no codec code or executable tests were added or run.

## Native transcoding instructions — contract 0.2.0, 2026-09-18

- Added a common native format-pair API/CLI pattern and explicit in-memory ownership, fidelity and testing requirements for SwiftJ2K and SwiftJXL.
- Distinguished sample-exact J2K ↔ HTJ2K conversion from original-JPEG-byte restoration through JPEG XL. Neither operation requires an umbrella or sibling codec dependency.
- Recorded predecessor implementation/test findings in the relevant repositories; kept Milestone 1 scoped to feasibility. No native transcode placeholder is required in SwiftJLS/SwiftJLI.
- Updated all seven shared documents and their SHA-256 manifest. This is documentation only; no source migration, codec execution or performance claim.

The foundation document version is 0.2.0. It is separate from the intended library version.
