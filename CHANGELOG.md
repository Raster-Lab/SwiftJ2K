# Change log

## 12.1.0-dev.1 — Swift 6.4 upgrade, 2026-09-19 (unreleased)

- Require Swift tools/compiler 6.4, retaining Swift 6 language mode and OS 26 deployment floors.
- Advance the coordinated common contract to 0.3.0 and the earlier unreleased 12.0.0 version target to 12.1.0.
- Adopt checked native-order span access for UInt16 samples with explicit endian conversion; preserve public API and owning-storage semantics.
- Add the supplied upgrade references, F01–F13 feature register, headless Swift Build validation and exact evidence. No codec capability, stable release or tag is added.

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

## OS 27 and CLI foundation — 19 September 2026

Owner-authorised Apple platform floors now use 27.0. Development version 12.1.0-dev.2, common contract 0.4.0. The standalone `swiftj2k` provides help/version/capabilities, five diagnostic levels and a matching section 1 manual installed/updated with the binary. Codec commands remain unavailable. Endian-aware span overloads use the new floor without changing public ownership semantics. See [qualification and limitations](Documentation/Engineering/OS27CLI/README.md). Historical evidence and supplied documents remain unchanged.

## Apple runtime qualification — 19 September 2026

Added a headless Xcode platform runner, evidence-integrity regression checks and a target-specific Watch resource-admission test. Debug/Release execution now covers native macOS arm64, Mac Catalyst and iOS/iPadOS/tvOS/watchOS/visionOS 27 simulators. Device/Intel SDK builds, macOS sanitizers, standalone consumption and CLI/manual checks also pass. See [Apple platform runtime qualification](Documentation/Engineering/ApplePlatforms/README.md). Development version 12.1.0-dev.2 and common contract 0.4.0 are unchanged; no shipped codec behaviour, stable release or tag is added.
