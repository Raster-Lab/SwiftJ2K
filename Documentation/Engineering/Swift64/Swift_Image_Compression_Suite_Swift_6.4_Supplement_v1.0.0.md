---
title: "Swift Image Compression Suite — Swift 6.4 supplement"
document_id: "SWIFT64-SICS-001"
version: "1.0.0"
issued: "2026-09-18"
requires: "SWIFT64-MANIFESTO-001 v1.0.0"
status: "Issued project-specific coding-agent reference; no implementation claim"
---

# Swift Image Compression Suite — Swift 6.4 supplement

**Read with `Swift_6.4_Upgrade_Manifesto_v1.0.0.md`.** This file contains only suite-specific decisions and acceptance obligations. The common feature definitions, migration gates and report format are not replaced.

## 1. Scope and controlling inputs

Applies separately to **SwiftJ2K, SwiftJLS, SwiftJXL and SwiftJLI**. HTJ2K remains a mode of SwiftJ2K. The optional umbrella remains an adapter-based consumer, not a mandatory foundation or a new dependency of the codecs. The current inspected suite policy is contract **0.2.0**, including its native-transcoding additions. [P01]

**S64-001.** Upgrade the toolchain requirements to 6.4 without changing the four-repository structure, domain-neutral codec scope, independent release sequences, common API meanings, MIT policy for in-house work or third-party provenance obligations. Preserve the correct scalar implementation and measured, separately selectable acceleration boundaries.

**S64-002.** First read `AGENTS.md`, `IMPLEMENTATION.md`, `HISTORY.md`, all seven common contract documents and local `TRANSCODING.md` where present. Determine the actual implementation state; the inspected policy describes a documentation foundation, not proof that every repository remains empty at execution time. Use current source and pinned predecessor revisions as evidence.

Do not create a common runtime module, invent an umbrella name, require a sibling checkout, add an external codec fallback, or turn the compiler upgrade into broad codec migration. The public types remain local to each module even where names and semantics match. [P01]

## 2. Preserve the suite's distinct platform contract

The inspected platform contract specifies the following intended support, not completed qualification. [P02]

| Target | Existing minimum / architecture to preserve |
| --- | --- |
| macOS | 26.0; Apple arm64 primary, native Intel x86_64 secondary |
| iOS / iPadOS | 26.0; declared supported devices and simulators |
| tvOS | 26.0; applicable supported devices and simulators |
| visionOS | 26.0; applicable supported devices and simulators |
| watchOS | 26.0; SDK-supported Watch architectures, bounded-memory runtime profile |
| Linux | Ubuntu 24.04 reference distribution; native ARM64 and native x86_64 |

**S64-003.** Replace the old 6.2 minimum with the qualified 6.4 minimum; do not raise Apple deployment targets to 27 merely because a new API requires it. Do not silently remove native Intel, Linux or Watch coverage because the local agent host is Apple Silicon. A missing environment is an open gate. Windows, Android, general ARMv7 and other platforms are not added by this task.

Segregate Apple framework code, Linux integration and architecture-specific kernels at compile time. Determine implementation eligibility from the **target**, not from the machine evaluating `Package.swift`. Native runtime evidence and cross-compilation are not interchangeable. Preserve a scalar correctness path on every claimed target. [P02]

**Integration warning:** this suite's OS 26 minimum is higher than the currently inspected DICOMKit and VoxeliaCore minima. Do not replace their older dependencies with these successors as a side effect of upgrading their compiler. Resolve the product/dependency deployment contract separately; a runtime availability check alone does not reconcile incompatible package floors. [P02][P04]

## 3. Apply Swift 6.4 features to the correct boundaries

Use the common F01–F13 register, with these suite-specific priorities:

| Feature | Suite application and limiting condition |
| --- | --- |
| F01: safe raw-span operations | Codestream fields, bounded marker/segment parsing, container lengths and byte-order conversions. Retain explicit rejection of malformed counts and offsets. |
| F02: temporary output spans | Predictor rows, transform blocks and bounded entropy scratch. Keep full-image/coefficient workspace in the resource budget. |
| F03/F04: unique containers/box | Private codec state and workspace where exclusive ownership is intended. Do not substitute them for the shared read-only image provider. |
| F05/F06: accessors/iteration | Internal buffer wrappers and ownership-sensitive traversal; shared public contract changes must be coordinated. |
| F07/F10: references/optionals | Local state transitions after availability/lifetime probes. Do not turn non-owning references into asynchronous lease owners. |
| F08/F09: async cleanup/shields | Abort, drain and invalidate an unfinished destination; seal only after all workers finish. Shield only essential teardown. |
| F11/F12 | Independent-consumer, native-platform, lifetime and transcode tests; per-codec product SBOMs and fresh URL-based package consumption. |
| 6.3 module selectors | Optional adapter/test-harness disambiguation of each module's local `Image`, descriptor or options. No shared-type dependency is required. |

No feature has a blanket mandate to replace every existing array, state object or accessor. Apply the common availability gate on Apple and Linux independently. New storage types must not change on-wire formats or the public memory semantics.

## 4. Preserve and prove the owning-memory contract

The controlling storage specification distinguishes the owning allocation, immutable descriptor, exclusive write destination, sealed image and scoped access. Its initial shared layout is unsigned greyscale in little-endian 16-bit storage, with both packed and padded rows. [P03]

**S64-004.** Retain one shared underlying lifecycle across module-local adapters. A write destination transitions from available to writing and then to sealed on success or invalid on failure/cancellation. Do not publish partially initialised output. Retain the actual allocation until all readers, workers and GPU operations are finished; release it exactly once.

Prove the owner/provider and lease-token design in 6.4 before migrating algorithms. A non-copyable token may be an implementation choice, but copying a wrapper must never create two overlapping writers. Settle any public lease-signature refinement once and mirror it across all four repositories.

**S64-005.** Under `requireSharedStorage`, final decoded samples must be written into the caller's destination and read there by the next codec. Do not decode into a second final image and copy it over, flatten/repack the entire image to enter a legacy encoder, or hide a streamed full-image hand-off copy as workspace. Preserve allocation identity through adapters and add instrumentation that checks actual reads, writes, allocations and copies; pointer equality alone is insufficient. [P03]

Keep descriptors explicit: storage/meaningful bits, signedness, byte order, component roles, colour interpretation, alpha, plane geometry, strides, capacity and bounded metadata. Preserve 12 meaningful bits stored in 16 bits without inferring precision from extrema. Preserve exact integer samples; Float16 is not an acceptable substitute for full-range UInt16. No DICOM presentation operation belongs in this contract.

Pool reuse requires completed work, no remaining reader lease and a new allocation generation. Refuse resource-limit violations before allocating. Do not expose stale padding or uninitialised bytes. Record unavoidable algorithm workspace separately from hand-off copies.

## 5. Native transcoding requirements that survive the upgrade

### 5.1 SwiftJ2K: JPEG 2000 Part 1 ↔ HTJ2K

**S64-006.** Retain the standalone in-memory native pair requirement and follow the current local `TRANSCODING.md`. Keep compatible coefficient-domain work owned in memory. A qualified sample-based path must use the same destination/seal/owner rules and avoid an extra final-image hand-off allocation. Do not allocate a pixel image solely to satisfy an interface when the native route does not need one. [P01][P03]

Verify both directions against independent decoding and the declared fidelity contract. Separate eligible reversible/lossless cases, any explicitly supported coefficient-preserving cases and unsupported inputs. Do not imply that transcode can recover information previously lost by a lossy encoding. No silent precision change, quantisation change or fallback to an external codec executable.

### 5.2 SwiftJXL: existing JPEG ↔ JPEG XL

**S64-007.** Preserve the native reversible recompression/reconstruction requirement. The destination JPEG must reproduce the **original JPEG file bytes from the JPEG XL alone** for supported cases. This is stronger than equal decoded samples or visual similarity. Keep required reconstruction information in the supported JXL representation; do not depend on the original file, a cache or a sidecar. [P01]

Test the original/restored byte lengths, digest and byte comparison, with the original unavailable to the restoration operation. Exercise corruption, truncation, unsupported profiles and expansion limits. Retain independent interoperability checks; a round trip through the same buggy code is insufficient evidence.

### 5.3 Shared exclusions

No native J2K/HTJ2K or JPEG/JXL pair implementation is imposed on SwiftJLS or SwiftJLI. They still implement the common memory/API contract and their own codec capability coverage. The optional umbrella is not needed for either native pair. [P01]

For both pairs, no temporary image file, memory-mapped scratch file or implicit spill-to-disk fallback is permitted. This is an application-I/O requirement, not a promise that the OS never pages memory. Account for compressed buffers, coefficient state, reconstruction metadata and output size; do not advertise universal zero allocations or zero copies. [P03]

## 6. Preserve the milestone sequence

**S64-008.** Change the language/toolchain used by the assigned milestone; do not skip milestones.

**Milestone 1:** in 6.4, prove local public API shapes, descriptors, owning memory, lease semantics, concurrency and independent consumption using synthetic buffers. Settle and synchronise the shared contract. No real codec/transcoder implementation is implied by this milestone.

**Milestones 2 and 3:** retain the first real cross-codec proof: lossless unsigned greyscale JPEG 2000 decoded by SwiftJ2K into shared storage and encoded by SwiftJLS as lossless JPEG-LS. Test full 16-bit range and 12 meaningful bits in 16-bit storage, packed and padded rows, retained ownership and no extra full-image hand-off copy. Later assigned increments cover additional codecs, layouts and native pairs. [P01][P03]

Where implementation has already advanced, preserve completed behaviour and apply the common migration gates to the current source. Do not restart or delete implemented work because an older foundation document was written before it existed.

## 7. Additional acceptance evidence

**S64-009.** Extend the common G5 record with the following suite-specific proofs:

| Proof | Required result |
| --- | --- |
| Independent package | Each codec builds and runs for its advertised functions without another suite repository or local path. |
| Common shape | Independent consumer exercises equivalent calls in all four local modules; adapters map descriptors explicitly. |
| Lifetime/state | Two-writer refusal, sealing, cancelled/failed destination invalidation, shared-reader retention and exactly-once release. |
| Copy contract | Allocation identities plus code-path and instrumentation evidence; padded/alignment-incompatible cases included. |
| Fidelity | Exact integer samples and declared precision; signed extrema where supported; byte restoration for the JPEG/JXL native pair. |
| Native pair | Both directions, independent oracle and declared capability/refusal matrix; no external runtime fallback. |
| Resources | Workspace, expanded metadata and compressed output limits; cancellation with workers in flight; no application scratch-file writes. |
| Acceleration | Independent scalar/accelerated selection and equivalence; no hidden copy solely to select a preferred backend. |
| Platforms | Required native Linux/Intel/Apple runs and Watch resource profile; no support claim derived solely from an Apple arm64 build. |
| Packaging | Fresh URL-based consumer and manifest compatibility; test oracles/CLI tooling excluded from the core runtime graph. |

Measure encode/decode and native-transcode throughput, latency, peak workspace and hand-off copy costs separately. Keep performance data labelled by codec, fidelity mode, sample/layout profile, platform and backend.

## 8. Contract publication and agent handover

**S64-010.** The seven shared contracts must advance as a coordinated versioned change when their 6.2 requirements or API signatures change. Explain the impact across all four codecs, update matching conformance tests and regenerate `COMMON_CONTRACT_SHA256.txt` in every repository. Do not bump only `Package.swift` while leaving agent instructions demanding 6.2, or update a digest without its corresponding content.

Keep the common manifesto byte-identical, referenced alongside the suite's contracts. Its **1.0.0** publication version is not the suite contract version and does not replace **0.2.0** by itself. Preserve predecessor release tags/history and the authorised licensing boundaries. A migration report does not authorise a stable release.

### Project-specific task suffix

> Apply S64-001–S64-010 to the assigned successor repository. Preserve standalone packaging, current platform scope and the common owning-memory contract. Use Swift 6.4 for the assigned milestone, coordinate shared-contract changes, and prove the relevant native transcode or cross-codec hand-off only when that implementation milestone is assigned. Report exact fidelity, copy/lifetime, native-platform and independent-consumer evidence; do not introduce a shared foundation or external codec runtime.

## 9. Repository-source record

These are spot-checked inputs retrieved on **18 September 2026**, not a complete audit of all four repositories. The identifiers below are **Git file-blob SHAs**, not commit IDs or SHA-256 publication digests. The executing agent must pin the actual repository commit and reread current controlling files.

| Source | Observed file-blob SHA |
| --- | --- |
| [P01] `SwiftJ2K/Documentation/SUITE_POLICY.md` | `e86dc312f780762875283ad3061b0daa784c39d1` |
| [P02] `SwiftJ2K/Documentation/PLATFORMS.md` | `fc36e227eb35d5010c336207d0cadd6176c596dc` |
| [P03] `SwiftJ2K/Documentation/MEMORY_CONTRACT.md` | `82fb4b2df1cdc969667457cb469160822bc86ec4` |

[P01]: https://github.com/Raster-Lab/SwiftJ2K/blob/main/Documentation/SUITE_POLICY.md "Suite policy 0.2.0; source read on 18 September 2026"
[P02]: https://github.com/Raster-Lab/SwiftJ2K/blob/main/Documentation/PLATFORMS.md "Suite platform contract 0.2.0"
[P03]: https://github.com/Raster-Lab/SwiftJ2K/blob/main/Documentation/MEMORY_CONTRACT.md "Suite memory contract 0.2.0"
[P04]: https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html "SwiftPM dependency deployment compatibility"

**Revision 1.0.0:** initial Swift 6.4 delta supplement. No code, test result, benchmark, contract publication or repository release is created by this document.
