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
## Apple floor restored to 26.0 — contract 0.5.0, 20 September 2026

- Revert the 0.4.0 Apple deployment raise: macOS, iOS/iPadOS, tvOS, visionOS and watchOS return to **26.0**. Xcode 27 is a public preview with a 27.2 beta, no generally available SDK or stable CI runner exists for OS 27, and Swift 6.4.0 rejects a 27.0 deployment target outright because its supported range ends at 26.5.x. The raise could not be validated on any supported configuration.
- Return `swift-tools-version` to **6.2**, keeping Swift 6.4 as the qualified primary toolchain. A manifest floor constrains consumer resolution, and every current consumer resolves at 6.2.
- Replace the OS-27-gated `RawSpan.load(fromByteOffset:as:_:)` and `OutputRawSpan.append(_:as:_:)` byte-order overloads with explicit fixed-width integer conversion. This restores the rule contract 0.3.0 already specified and was the sole reason the floor moved. Public API, ownership and fidelity semantics are unchanged.
- Relax `Scripts/validate-swift64.py` from one pinned preview-Xcode build to accepting Swift 6.2 or 6.4, recording the exact toolchain as evidence rather than enforcing it as an admission gate.
- Retain the OS 27 records under `Documentation/Engineering/OS27CLI` as superseded history for their platform claims; their CLI content remains current.
- Verified on Swift 6.2.4 and Swift 6.4.0, debug and release. No codec capability, stable release or tag is added.

## Shared-storage contract refined from measurement — contract 0.6.0, 20 September 2026

- Advance the coordinated common contract to **0.6.0**. Seven memory rules are amended and one testing rule is added, each from something an exploratory spike measured or broke across all four predecessor codecs in both directions.
- **MEM-03** requires a multi-plane layout to state the distance between plane origins rather than infer it from height and `rowBytes`; with padded rows the two defensible readings differ by one row's padding per plane and shear the image instead of failing.
- **MEM-05** records that read-only storage is shared rather than leased and admits concurrent readers, an asymmetry with destinations the contract did not previously state.
- **MEM-06** requires caller-storage entry points to take the owner rather than a pointer, which an `async` codec cannot otherwise satisfy under MEM-08.
- **MEM-07** requires a safe owning constructor to exist and to be the documented default; unsafe adoption becomes the named exception.
- **MEM-10** requires algorithm workspace to be bounded by a stated per-codec figure, and records that removing the hand-off copy does not by itself reduce peak memory.
- **MEM-12** requires a codec whose native sample order differs from the shared layout to convert on the shared path rather than relax MEM-03.
- **MEM-13** records that allocator telemetry is invalid under a sanitizer, and that encode-side proofs compare codestreams byte for byte rather than comparing samples.
- **TEST-09** collects the resulting evidence bar, including mutation testing to demonstrate the checks are load-bearing.
- This codec drives three of the seven amendments. Its encode and decode are `async`, so a pointer parameter cannot satisfy MEM-08 and the owner requirement in MEM-06 follows from it. Its decoder emits big-endian 16-bit samples against the shared layout's little-endian, which MEM-12 now requires it to convert on the shared path. Its spatial-domain `[Double]` workspace is four times the final frame, which MEM-10 now requires it to state.
- Updated all seven shared documents and their SHA-256 manifest. Documentation only: no source migration, codec execution, platform change or release. Every figure cited comes from a developer machine and none has been reproduced in continuous integration.
