# Swift Image Compression Suite — implementation baseline

Contract version: **0.4.0**. Updated: **19 September 2026**.
Status: **engineering specification; Milestone 1 implementation evidence is recorded in MILESTONE1.md. Later codec and platform gates remain planned**.

This is the common engineering specification for four independent successor libraries. It records the owner's accepted direction and makes concrete implementation choices for the coding agent. Milestone 1 public API shapes and owning storage have been compiler-validated to the coverage recorded in MILESTONE1.md and Engineering/Swift64/README.md. Planned codec behaviour, engineering thresholds and unexecuted platforms remain qualification gates; those records do not constitute a separate human approval. Do not describe this baseline as a released SDK or a conformance certificate.

## Decisions and boundaries

| Successor under Raster-Lab | Predecessor | Intended first stable release |
| --- | --- | --- |
| SwiftJ2K | J2KSwift | 12.1.0 |
| SwiftJLS | JLSwift | 1.1.0 |
| SwiftJXL | JXLSwift | 2.1.0 |
| SwiftJLI | JLISwift | 1.1.0 |

The public family name is **Swift Image Compression Suite**. Raster-Lab remains the GitHub organisation; copyright attribution remains accurate. Each codec has its own repository, implementation, package and release sequence. HTJ2K remains a mode of SwiftJ2K.

**POL-01 Independence.** Each library must encode and decode its supported formats without any other suite repository, CompressionFamily, SwiftCompressionFamily or umbrella package. No sibling-path discovery, network fetch at execution, dynamic codec loading or external executable fallback. Platform SDK libraries are permitted. Development-only independent codec tools are permitted as test oracles, outside the shipped dependency graph.

**POL-02 Dependency control.** Prefer zero external package dependencies for each core library. Keep CLI parser and developer tooling dependencies outside the core target; document that a package manager may still resolve package-level dependencies even when a consumer selects only a library product. If dependency-free package resolution is needed, place CLI tooling in a separate package rather than misrepresenting target isolation. Do not vendor a reference codec implementation as an acceleration layer.

**POL-03 Common contract.** The seven documents in `Documentation/COMMON_CONTRACT_SHA256.txt` are identical in every repository. They define a specification, not a runtime module. Every module implements its own concrete types with the same meaning and public shape. Identically named types from different modules are distinct Swift types.

**POL-04 Optional integration.** A future optional umbrella depends on these libraries through adapters. No library depends on the umbrella. It owns codec selection, a convenient combined image object and in-process transcoding. The umbrella's repository/module name is deliberately unassigned. Do not create SwiftCompressionFamily 2.0.0 or a substitute shared-foundation dependency. Existing CompressionFamily remains available for predecessor consumers.

**POL-05 Scope.** Codecs remain domain-neutral. Preserve sample precision and meaning, but keep DICOM parsing, transfer-syntax negotiation, patient metadata, windowing, rescaling and diagnostic product policy in consumers/adapters. Existing predecessor-specific auxiliary products must be inventoried and explicitly retained, adapted or deferred; do not silently delete them. Future waveform compression is a separate sibling project.

**POL-06 Priorities.** Performance, reliability and security guide every change. Correctness, memory safety and defined fidelity are release constraints. Optimisation must not relax bounds checks, hide unsupported inputs, silently lower precision or bypass cancellation. Keep a correct scalar Swift reference path. Retain audited native hot paths only where measured, independently selectable and removable. Do not add C/C++ for routine parsing or to replace an in-house codec with a foreign runtime.

**POL-07 Licence and provenance.** New in-house files and documentation are MIT licensed. The owner has authorised relicensing of in-house predecessor code. Preserve original authorship/copyright years where appropriate; record each migrated path's source commit. This does not relicense third-party dependencies or fixtures. Review their notices independently. Existing published predecessor tags retain their original history and licence texts; never rewrite tags.

**POL-08 Truthful status.** Documentation requirements are planned until implemented and tested. Do not copy historical test counts, benchmark numbers or production-readiness claims into the successor README. Record measured results with exact revisions, platform and test commands. A missing required environment is an unexecuted gate, not a pass.

**POL-09 Native transcoding.** SwiftJ2K must provide lossless Part 1 J2K ↔ Part 15 HTJ2K transcoding in memory. SwiftJXL must preserve and qualify its predecessor's reversible existing-JPEG ↔ JPEG XL capability, restoring the original JPEG bytes from the JXL alone. These are native operations inside the standalone libraries; the optional umbrella is not required. Coefficient/reconstruction paths may avoid pixel images entirely. The common ownership/resource rules still apply, and a qualified J2K sample path uses the shared Image allocation. See API-14, MEM-14, TEST-08 and CLI-06. No new implementation or native-pair obligation is imposed on SwiftJLS/SwiftJLI.

## Document precedence and change control

1. The owner's current explicit task scope and decisions.
2. This suite policy and the common API, memory, platform, CLI, testing and performance contracts at the same contract version.
3. Repository-specific `IMPLEMENTATION.md`, which may add justified codec details but cannot silently weaken the common contract.
4. `AGENTS.md` and `CLAUDE.md` as workflow entry points; README, history and external predecessor notes as context.

The predecessor's Apple-only restriction for JXLSwift is superseded by the accepted Linux scope. Old local-path instructions and old shared-package requirements are superseded. Relevant algorithm invariants and known failure histories remain evidence to retain.

Keep each shared document byte-identical across the four repositories. Any contract change requires a versioned explanation, impact on all four codecs and their adapters, updated hash manifests and matching conformance tests. Make coordinated documentation PRs; avoid unilateral drift. The optional integration test harness may inspect all four repositories without becoming their dependency. Tag contract revisions separately from library release versions only if a tagging policy is later adopted; this foundation creates no tags.

## First coding task — Milestone 1

Start with contract feasibility, as numbered in every repository's `IMPLEMENTATION.md`. Establish the Swift 6.4 package and local API/owning-memory types, validate descriptors, and prove the adapter and ownership lifecycle using synthetic sample buffers. Settle the concrete lease-token signatures once and mirror the refinement across all four repositories before codec migration. Keep any API-shape experiments or test doubles clearly separate from advertised codec functionality.

Milestone 1 does not migrate codec algorithms or implement a real compressed-image transcode. Its exit evidence is compiling common call shapes, meaningful descriptor/lifetime/concurrency tests and independent consumer use. The complete end-to-end proof below belongs to Milestones 2 and 3. Each later milestone remains a separately assigned coding task.

## First end-to-end proof — Milestones 2 and 3

One unsigned greyscale image, stored as 16-bit samples, losslessly compressed as JPEG 2000, is decoded by SwiftJ2K directly into shared storage and encoded by SwiftJLS as lossless JPEG-LS. Exercise both full 16-bit precision and 12 meaningful bits in 16-bit storage. The destination decode must match source logical samples and their meaningful precision. No intermediate file and no full-image hand-off copy. Retain storage through all asynchronous work and clean up on failure/cancellation.

Migration and optimisation then extend to the remaining codecs, HTJ2K, signed samples, other layouts and advanced features using the same contract. This bounded first end-to-end proof does not remove the final platform or codec scope.

## Contract revision 0.1.1 — 17 September 2026

Clarifies the milestone sequence for all four codecs and their adapters: Milestone 1 proves the API and ownership contract with synthetic buffers; Milestones 2 and 3 deliver the first real codec/transcode proof. API names, memory semantics, platform scope, library version targets and release gates are unchanged. The matching Milestone 1 acceptance instructions in TESTING.md specify future tests; no implementation or test execution is included in this documentation revision. All seven common documents and their hash manifest advance together.

## Contract revision 0.2.0 — 18 September 2026

Adds owner-requested in-memory J2K ↔ HTJ2K transcoding and reversible existing-JPEG ↔ JPEG XL recompression/reconstruction instructions. Defines a consistent native format-pair API/CLI extension, separates exact samples from original-JPEG byte restoration, and adds memory, regression, interoperability and performance gates. The seven shared documents and manifest are mirrored across all four repositories; only SwiftJ2K/SwiftJXL receive the native pair requirement and detailed local TRANSCODING.md instructions. Standalone packaging, MIT licensing, platform floors, intended library versions and the first coding milestone remain unchanged. This revision contains documentation and source-review findings only; no codec tests or benchmarks were run.

References: [Swift API design](https://www.swift.org/documentation/api-design-guidelines/), [Swift package descriptions](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html), and each predecessor's pinned history in `HISTORY.md`.

## Contract revision 0.2.1 — 18 September 2026

Milestone 1 fixes the concrete local storage lease signatures in MEM-05. Each module retains its independent Swift types and ships no sibling dependency. A provider owns the authoritative allocation lifecycle; a copyable token is an identifier, not evidence of exclusive access by itself. Providers must reject invalid, reentrant and concurrent mutable borrows and prevent publication during a mutable borrow. API-shape implementations must advertise no codec capabilities until actual compressed-format work is qualified.

The corresponding implementation and executed evidence are recorded in each repository's `MILESTONE1.md`; this common specification does not certify all platforms or a working codec. The required deployment floors, later codec milestones, native transcoding requirements and release gates are unchanged. All seven documents and the hash manifest advance together.

## Contract revision 0.3.0 — 19 September 2026

The owner assigned a Swift 6.4 upgrade of the four successors before Milestone 2, following SWIFT64-MANIFESTO-001 and SWIFT64-SICS-001 version 1.0.0. Their compiler direction supersedes earlier 6.2 minimum instructions. Preserve Swift 6 language mode, OS 26 deployment floors, module-local public signatures, ownership/fidelity semantics and the existing milestone boundary. The supplement's inspected 0.2.0 snapshot is historical; this revision builds on the implemented 0.2.1 lease contract.

The owner also requested version increments. Because none of the successors has a released library tag, advance the unreleased targets by one minor version: SwiftJ2K 12.0.0 → 12.1.0, SwiftJLS 1.0.0 → 1.1.0, SwiftJXL 2.0.0 → 2.1.0 and SwiftJLI 1.0.0 → 1.1.0. Each VERSION file identifies its first `-dev.1` candidate. These are development identifiers and intended future releases, not published tags, backwards binary-compatibility assertions or completed codec qualification. Historical release/provenance records remain unchanged.

All seven shared documents and their SHA-256 manifest advance together. Public signatures are unchanged. Safe native-order span sample access may use explicit fixed-width integer endian conversion without raising the runtime floor. Record F01–F13 dispositions and exact tests, including compiler/platform gaps, in [the upgrade record](Engineering/Swift64/README.md). Swift 6.4 adoption grants no later codec milestone or release authorisation.

## Contract revision 0.4.0 — 19 September 2026

The owner explicitly raised the Apple baseline to macOS/iOS/iPadOS/tvOS/visionOS/watchOS **27.0**, retaining Swift 6.4 and Swift 6 language mode. This supersedes OS 26 preservation instructions in contract 0.3.0 and the immutable supplied manifesto/supplement. Linux retains its independent Ubuntu 24.04 reference distribution. Update active manifests, examples, validation consumers and instructions; preserve historical OS 26 evidence as history.

The owner also authorised CLI help, selectable verbosity and UNIX manual support ahead of codec milestones. Implement only honest help/version/capability reporting and explicitly unsupported codec verbs. Each standalone executable and installer carries its matching man page. CLI rules CLI-07..09 apply consistently. The libraries retain their public API and owning-memory semantics; safe endian-aware span operations may now use their OS 27 overloads. Other newly available language/runtime features still require an actual use and justification. No codec algorithm milestone or release is authorised by this foundation change. Development identifiers advance to `-dev.2`; stable targets remain unchanged. See [the OS 27 and CLI record](Engineering/OS27CLI/README.md).
