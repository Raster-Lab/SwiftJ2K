# Swift Image Compression Suite — implementation baseline

Contract version: **0.1.1**. Prepared: **17 September 2026**.
Status: **documentation foundation; implementation and validation not yet performed**.

This is the common engineering specification for four independent successor libraries. It records the owner's accepted direction and makes concrete implementation choices for the coding agent. Detailed API designs and engineering thresholds in this foundation have not been compiler-validated or separately human-approved; demonstrate them in the first contract milestone before substantial migration. Do not describe this baseline as a released SDK or a conformance certificate.

## Decisions and boundaries

| Successor under Raster-Lab | Predecessor | Intended first stable release |
| --- | --- | --- |
| SwiftJ2K | J2KSwift | 12.0.0 |
| SwiftJLS | JLSwift | 1.0.0 |
| SwiftJXL | JXLSwift | 2.0.0 |
| SwiftJLI | JLISwift | 1.0.0 |

The public family name is **Swift Image Compression Suite**. Raster-Lab remains the GitHub organisation; copyright attribution remains accurate. Each codec has its own repository, implementation, package and release sequence. HTJ2K remains a mode of SwiftJ2K.

**POL-01 Independence.** Each library must encode and decode its supported formats without any other suite repository, CompressionFamily, SwiftCompressionFamily or umbrella package. No sibling-path discovery, network fetch at execution, dynamic codec loading or external executable fallback. Platform SDK libraries are permitted. Development-only independent codec tools are permitted as test oracles, outside the shipped dependency graph.

**POL-02 Dependency control.** Prefer zero external package dependencies for each core library. Keep CLI parser and developer tooling dependencies outside the core target; document that a package manager may still resolve package-level dependencies even when a consumer selects only a library product. If dependency-free package resolution is needed, place CLI tooling in a separate package rather than misrepresenting target isolation. Do not vendor a reference codec implementation as an acceleration layer.

**POL-03 Common contract.** The seven documents in `Documentation/COMMON_CONTRACT_SHA256.txt` are identical in every repository. They define a specification, not a runtime module. Every module implements its own concrete types with the same meaning and public shape. Identically named types from different modules are distinct Swift types.

**POL-04 Optional integration.** A future optional umbrella depends on these libraries through adapters. No library depends on the umbrella. It owns codec selection, a convenient combined image object and in-process transcoding. The umbrella's repository/module name is deliberately unassigned. Do not create SwiftCompressionFamily 2.0.0 or a substitute shared-foundation dependency. Existing CompressionFamily remains available for predecessor consumers.

**POL-05 Scope.** Codecs remain domain-neutral. Preserve sample precision and meaning, but keep DICOM parsing, transfer-syntax negotiation, patient metadata, windowing, rescaling and diagnostic product policy in consumers/adapters. Existing predecessor-specific auxiliary products must be inventoried and explicitly retained, adapted or deferred; do not silently delete them. Future waveform compression is a separate sibling project.

**POL-06 Priorities.** Performance, reliability and security guide every change. Correctness, memory safety and defined fidelity are release constraints. Optimisation must not relax bounds checks, hide unsupported inputs, silently lower precision or bypass cancellation. Keep a correct scalar Swift reference path. Retain audited native hot paths only where measured, independently selectable and removable. Do not add C/C++ for routine parsing or to replace an in-house codec with a foreign runtime.

**POL-07 Licence and provenance.** New in-house files and documentation are MIT licensed. The owner has authorised relicensing of in-house predecessor code. Preserve original authorship/copyright years where appropriate; record each migrated path's source commit. This does not relicense third-party dependencies or fixtures. Review their notices independently. Existing published predecessor tags retain their original history and licence texts; never rewrite tags.

**POL-08 Truthful status.** Documentation requirements are planned until implemented and tested. Do not copy historical test counts, benchmark numbers or production-readiness claims into the successor README. Record measured results with exact revisions, platform and test commands. A missing required environment is an unexecuted gate, not a pass.

## Document precedence and change control

1. The owner's current explicit task scope and decisions.
2. This suite policy and the common API, memory, platform, CLI, testing and performance contracts at the same contract version.
3. Repository-specific `IMPLEMENTATION.md`, which may add justified codec details but cannot silently weaken the common contract.
4. `AGENTS.md` and `CLAUDE.md` as workflow entry points; README, history and external predecessor notes as context.

The predecessor's Apple-only restriction for JXLSwift is superseded by the accepted Linux scope. Old local-path instructions and old shared-package requirements are superseded. Relevant algorithm invariants and known failure histories remain evidence to retain.

Keep each shared document byte-identical across the four repositories. Any contract change requires a versioned explanation, impact on all four codecs and their adapters, updated hash manifests and matching conformance tests. Make coordinated documentation PRs; avoid unilateral drift. The optional integration test harness may inspect all four repositories without becoming their dependency. Tag contract revisions separately from library release versions only if a tagging policy is later adopted; this foundation creates no tags.

## First coding task — Milestone 1

Start with contract feasibility, as numbered in every repository's `IMPLEMENTATION.md`. Establish the Swift 6.2 package and local API/owning-memory types, validate descriptors, and prove the adapter and ownership lifecycle using synthetic sample buffers. Settle the concrete lease-token signatures once and mirror the refinement across all four repositories before codec migration. Keep any API-shape experiments or test doubles clearly separate from advertised codec functionality.

Milestone 1 does not migrate codec algorithms or implement a real compressed-image transcode. Its exit evidence is compiling common call shapes, meaningful descriptor/lifetime/concurrency tests and independent consumer use. The complete end-to-end proof below belongs to Milestones 2 and 3. Each later milestone remains a separately assigned coding task.

## First end-to-end proof — Milestones 2 and 3

One unsigned greyscale image, stored as 16-bit samples, losslessly compressed as JPEG 2000, is decoded by SwiftJ2K directly into shared storage and encoded by SwiftJLS as lossless JPEG-LS. Exercise both full 16-bit precision and 12 meaningful bits in 16-bit storage. The destination decode must match source logical samples and their meaningful precision. No intermediate file and no full-image hand-off copy. Retain storage through all asynchronous work and clean up on failure/cancellation.

Migration and optimisation then extend to the remaining codecs, HTJ2K, signed samples, other layouts and advanced features using the same contract. This bounded first end-to-end proof does not remove the final platform or codec scope.

## Contract revision 0.1.1 — 17 September 2026

Clarifies the milestone sequence for all four codecs and their adapters: Milestone 1 proves the API and ownership contract with synthetic buffers; Milestones 2 and 3 deliver the first real codec/transcode proof. API names, memory semantics, platform scope, library version targets and release gates are unchanged. The matching Milestone 1 acceptance instructions in TESTING.md specify future tests; no implementation or test execution is included in this documentation revision. All seven common documents and their hash manifest advance together.

References: [Swift API design](https://www.swift.org/documentation/api-design-guidelines/), [Swift package descriptions](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html), and each predecessor's pinned history in `HISTORY.md`.
