---
title: "Swift 6.4 upgrade manifesto"
document_id: "SWIFT64-MANIFESTO-001"
version: "1.0.0"
issued: "2026-09-18"
organisation: "Raster Images"
status: "Issued coding-agent reference; implementation and qualification evidence required"
applies_to: "Existing Swift projects and new Apple-native Oviyam/Mayam development"
---

# Swift 6.4 upgrade manifesto

## Common engineering direction and coding-agent instructions

**Version 1.0.0 · 18 September 2026 · Raster Images**

> Adopt Swift 6.4 deliberately. Preserve architectural boundaries, supported platforms, ownership, precision and behaviour. Use its new safety and ownership facilities where they improve the implementation. Prove the result rather than equating a successful build with a successful upgrade.

This is the common reference for Claude, Codex and other coding agents. Read it with the applicable project supplement and the repository's current controlled inputs. The requirements below are engineering instructions, not assertions that migration, testing, performance improvement or release approval has already occurred.

**Owner decision:** existing Swift projects shall move to Swift 6.4 through controlled qualification. **Oviyam and Mayam have not started implementation and shall start their Apple-native Swift development directly in 6.4.** Do not create a fictional 6.2 application baseline or a backwards-compatibility workstream for those new applications.

Swift 6.4 was released on 15 September 2026. The feature references in this document were checked on 18 September 2026. Recheck the selected patch release and installed SDK interfaces when executing the task. [S01]

## 1. Authority, scope and how to use this file

### 1.1 What this instruction changes

**M64-001 — Toolchain direction.** Swift 6.4 is the target compiler and, after qualification, the package minimum. Swift **6** is the language mode. Xcode's compiler version, language mode, package tools version, SDK and deployment target are separate settings. [S02][S03]

**M64-002 — Narrow supersession.** This owner-directed manifesto replaces earlier Swift 6.2 toolchain/minimum instructions for the new migration successor, subject to the gates below. It does not rewrite historical releases, signed approvals, sealed evidence, algorithm contracts, product scope, licences or platform commitments. It is not an instruction to modify a frozen historical branch.

**M64-003 — Task boundary.** When assigned an upgrade in a repository, perform the bounded migration on a reviewable branch. Do not treat merely receiving this document as permission to implement unrelated roadmap features, modify other repositories, publish releases or deploy software. Ordinary implementation choices may be made within this policy; record unresolved architectural conflicts and continue independent, unblocked work.

### 1.2 Precedence

Use the owner's current explicit decisions first. This manifesto controls the Swift upgrade; the project supplement adds only project-specific requirements. Current approved architecture, API/memory contracts, platform policies and exact-byte evidence continue to control everything not explicitly changed here. Repository `AGENTS.md`, `CLAUDE.md`, scoped instructions and build scripts govern execution within those boundaries. Historical READMEs and predecessor notes are evidence, not permission to override a newer contract.

A supplement cannot weaken a common safeguard. Where the current repository contains a later applicable owner decision, record that decision and its exact source. Do not silently choose the more convenient interpretation. Raise a concrete blocking conflict without stopping unrelated qualification work.

### 1.3 Packaging and maintenance

Keep this common file byte-identical wherever it is distributed. Put local decisions in a project supplement or migration record, not an edited copy of the manifesto. Preserve its document ID/version and record its SHA-256 digest in the migration report. Update any existing `AGENTS.md` by adding a reference; do not replace its unrelated instructions.

The three supplied supplements are:

| Project | Additional reference |
| --- | --- |
| Swift Image Compression Suite | `Swift_Image_Compression_Suite_Swift_6.4_Supplement_v1.0.0.md` |
| DICOMKit | `DICOMKit_Swift_6.4_Supplement_v1.0.0.md` |
| Voxelia | `Voxelia_Swift_6.4_Supplement_v1.0.0.md` |

Other Swift repositories use this common file and their existing architecture. Do not apply another project's platform matrix by analogy.

## 2. Target baseline

| Concern | Required disposition |
| --- | --- |
| Compiler | Pin an exact stable Swift 6.4.x toolchain/build; do not use a floating `latest` qualification baseline. |
| Language mode | Swift 6 across production, CLI and test targets; no downgrade to suppress diagnostics. |
| Package minimum | Existing projects: qualify the old source first, then explicitly raise `swift-tools-version` to 6.4. New Swift projects: start at 6.4. |
| Apple development environment | Pin compatible Xcode, SDKs, command-line tools and Metal tools where used. Record the actual host requirements. |
| Deployment targets | Preserve each project's existing minima unless separately changed by the owner. A newer SDK is not an OS-floor decision. |
| Concurrency | Preserve strict Swift 6 checking and explicitly record default actor isolation, upcoming-feature settings and executor policy per target. |
| Memory safety | Retain existing strict memory-safety settings. For touched low-level code, adopt safe APIs and inventory unavoidable unsafe boundaries. |
| Dependencies | Pin the comparison graph; unrelated dependency upgrades are separate changes. Verify fresh consumer resolution. |
| Build engine | Qualify SwiftPM's Swift Build path, resource handling and relevant Xcode builds. Do not silently fall back to an older engine. |
| Historical baseline | Retain a reproducible 6.2 reference where real prior code exists. It need not compile new 6.4-only source forever. |

Apple lists Xcode 27 with the Swift 6.4 compiler and Swift 6 language mode; its development-host requirement is macOS Tahoe 26.6 or later. These host requirements do not replace project deployment targets. [S02]

**M64-004 — Availability proof.** For every newly adopted API, record its module, exact declaration in the selected toolchain, compiler requirement, OS/runtime availability, compatibility-library/linkage needs and results on the minimum supported deployment target. Compile-time availability and runtime execution are separate gates. Do not invent availability annotations from a release announcement.

Use compiler-version conditions when detecting the compiler; `#if compiler(>=6.4)` and Swift language-version conditions answer different questions. A successful `canImport` does not prove that every API in the module can run on the oldest supported OS. Prefer a compatible implementation or a documented deferral over an unauthorised OS-floor increase. [S21]

## 3. Swift 6.4 features to use

### 3.1 Adoption rule

**M64-005 — Assess every feature, implement applicable improvements.** Complete a feature register before broad refactoring. Classify each entry as **Applicable**, **Conditional**, **Not applicable**, **Deferred** or **Prohibited** for the target. An Applicable feature should be used in new or substantively modified relevant code once its probe and regression tests pass. A Conditional or Deferred entry needs a precise reason and exit condition. Do not force every feature into every repository or manufacture changes to satisfy a quota.

**The first priorities are safe parsing, bounded temporary storage, correct ownership and dependable cleanup.** Container and optimisation changes must be justified by the actual code, not by novelty.

### F01 — Safe `RawSpan` loading and storing · SE-0525

Swift 6.4 adds safe raw-span byte conversion operations, including explicit integer byte order and unaligned loading. The relevant conversion protocols constrain which values can safely be constructed or serialised. [S04]

**Use:** replace applicable raw-pointer field loads and stores in parsers, serialisers and binary headers. Validate the byte extent before calling an API with preconditions; turn malformed input into a defined error rather than a bounds trap. Check overflow before multiplying sizes or adding offsets. Test truncation at each field boundary, unaligned addresses, both byte orders and signed values. Do not load an arbitrary in-memory struct as a wire representation or assume padding is serialisable.

### F02 — `withTemporaryAllocation` with `OutputSpan` / `OutputRawSpan` · SE-0524

This facility gives scoped temporary storage while tracking initialised elements and cleaning them up on scope exit. It does **not** mean every allocated element starts initialised. Stack placement is an optimisation opportunity, not a guarantee. [S05]

**Use:** bounded line, block, predictor or parsing scratch storage. Set explicit maximum capacities and initialise before reading. Test a throwing exit after partial initialisation. Do not use it as an asynchronous owner, return a borrowed scratch pointer, or put an unbounded image/volume into temporary storage. Keep large workspace under the normal allocation budget.

### F03 — `UniqueArray` and, selectively, `RigidArray` · SE-0527

These non-copyable containers are described in the toolchain's **`Containers`** module. `UniqueArray` has unique ownership but can grow and relocate storage. `RigidArray` provides fixed-capacity operation with explicit resizing; exceeding capacity can trap. [S06]

**Use:** private uniquely owned workspaces after confirming the module and deployment support. Preflight capacity; guard fixed-capacity insertions with defined errors. Never retain element addresses across mutations that can relocate storage. Keep shared immutable storage owners where several consumers need the same allocation. Prefer ordinary `Array` when its semantics are appropriate. Unique ownership is neither a zero-allocation guarantee nor a proof of pointer stability.

### F04 — `UniqueBox` · SE-0517

`UniqueBox` uniquely owns a heap value, including a non-copyable value, without class-style reference counting. [S07]

**Use:** private large state objects or ownership tokens where single ownership is the intended contract. Compare construction, passing, destruction and allocation behaviour with the existing design. Do not box small values gratuitously. Do not replace a shared storage owner simply to remove ARC: reader sharing and asynchronous lifetime may require that ownership model.

### F05 — `borrow` and `mutate` accessors · SE-0507

These accessors expose eligible stored values without an ordinary getter copy. Their restrictions differ from yielding accessors; they cannot simply be applied to class or actor properties. Changing a public accessor can affect source and ABI compatibility. [S08]

**Use:** appropriate value-type wrappers and buffer-facing properties, initially internally. Prove the exposed value outlives the borrow and respects exclusivity. Compile an independent consumer before changing public protocol requirements. Do not convert every getter mechanically or return temporary values. A public accessor migration needs an API compatibility decision, not just a compiler fix.

### F06 — Borrowing iteration with `Iterable` · SE-0516

`Iterable` supports iteration in ownership-sensitive cases beyond the traditional copying-oriented `Sequence` model. [S09]

**Use:** local iteration over non-copyable state or expensive-to-copy elements when the adopted API supports it. Validate empty, partial, early-exit and throwing traversals. Do not replace established public `Sequence`/`Collection` interfaces solely for uniformity, and do not invent iteration syntax from a proposal's future-directions section. Compile the smallest representative loop first.

### F07 — `Ref` and `MutableRef` · SE-0519

These are lifetime-dependent, non-escapable references for shared reading or exclusive mutation. They are not independently owning heap references; some generic uses require newer runtime functionality. [S10]

**Use conditionally:** scoped local projections that genuinely simplify an ownership-safe implementation. Retain the underlying owner separately wherever needed. Prove the exact intended generic and deployment combination. Do not store them as unrestricted asynchronous leases, use them to bridge GPU completion, or add experimental lifetime annotations merely because an illustrative proposal uses them. Defer a design that needs unsupported or experimental features.

### F08 — Asynchronous calls in `defer` · SE-0493

Asynchronous cleanup can be awaited from a `defer` in an asynchronous context; the scope waits for that cleanup before completing. [S11]

**Use:** keep necessary asynchronous cleanup beside resource acquisition. Define ordering and the treatment of cleanup failures without losing the primary operation error. Test successful return, early return, thrown error and cancellation. Review actor reentrancy at every cleanup suspension. Do not launch an unstructured fire-and-forget task in place of awaited cleanup or claim cleanup will run after process termination.

### F09 — `withTaskCancellationShield` · SE-0504

The shield changes cancellation observation within its operation; it does not undo the enclosing task's cancelled state or make external work infallible. [S12]

**Use conditionally:** the smallest essential cancellation-sensitive teardown, such as finalising an owned lease. Keep ordinary codec, rendering and network work cancellable. Document the shield's boundary and liveness assumptions; test cancellation before entry and during cleanup. A timeout must not release storage still used by CPU/GPU work. Do not rely on a cancellation-based timeout to interrupt a deliberately shielded operation, or shield an entire job to make tests pass.

### F10 — Non-copyable `Optional` improvements · SE-0532

The new operations allow more inspection and mutation of optional non-copyable values without consuming the wrapped value. [S13]

**Use:** optional private resources, pending work and ownership-state transitions where the exact operation is supported. Test empty, present, consumed, failed and repeated-close states. Avoid force unwraps and double release. Do not change observable absence/error semantics simply to shorten the code.

### F11 — Test-framework interoperability and per-case repetition

Swift 6.4 adds targeted XCTest/Swift Testing assertion interoperability and improved test-case repetition. These enable incremental test maintenance rather than requiring one framework to replace the other. [S14][S15]

**Use:** verify an intentionally failing mixed-framework assertion is actually reported before relying on a migrated helper. Apply repetition to targeted race, cancellation and teardown cases; retain every failure. Record discovered, executed, passed, failed and skipped case counts. Zero selected cases is not a pass. Never retry until green, relabel failures as warnings, or weaken existing process-isolation requirements.

### F12 — Swift Build qualification and SwiftPM SBOM generation

Swift Build becomes SwiftPM's default build engine in 6.4. SwiftPM also supports SBOM generation in SPDX and CycloneDX formats. [S01][S16]

**Use:** exercise clean and incremental builds, resource bundles, generated code, plugins, destination selection, debugger symbols and fresh package consumers. Generate an SBOM for the actual build/product, retain dependency identities and supplement it for components outside SwiftPM's graph. A package-graph-only SBOM is not identical evidence to a build-associated one. Use the installed CLI help to confirm options. Keep SBOMs tied to the exact release candidate rather than re-resolving dependencies afterwards.

### F13 — Source-level warning control with `@diagnose` · SE-0522

`@diagnose` permits scoped warning behaviour. [S17]

**Use sparingly:** narrowly elevate important diagnostics, or document an unavoidable local warning disposition with an owner, reason, test and removal condition. **Prohibited:** blanket suppression of memory-safety, concurrency, availability, deprecation or resource warnings to obtain a green migration. Do not downgrade error semantics globally.

## 4. Useful facilities inherited from 6.3 and 6.2

**From Swift 6.3:** module selectors such as `ModuleName::TypeName` help disambiguate intentionally similar APIs. `@specialize`, `@inline(always)` and `@export(implementation)` provide additional control over library optimisation. Treat these as 6.3-era additions available in the new baseline, not uniquely 6.4 features. [S18]

Use module selectors where ambiguity is real. Use optimisation attributes only for measured hot paths, with a code-size/API review and an independent consuming module. Do not blanket-inline, expose private implementation unnecessarily, or promise a percentage speed-up before measurement.

**Already in Swift 6.2:** `Span`, `InlineArray`, opt-in strict memory-safety diagnostics and the relevant approachable-concurrency facilities, including `@concurrent`, are part of the existing foundation. Preserve and improve their use; do not claim they are newly enabled by 6.4. [S19]

Do not automatically enable default main-actor isolation across libraries or copy an application's concurrency settings into codec/rendering targets. New Swift platform or interoperability capabilities do not authorise new supported operating systems, a web-stack rewrite, or a foreign codec dependency.

## 5. Non-negotiable implementation rules

### 5.1 Behaviour and representation

**M64-006.** Preserve sample values, meaningful precision, signedness, layout, colour interpretation, transforms, metadata/provenance and the project's fidelity definition. No implicit normalisation, bit-depth reduction, display transform, lossy recompression or disk staging. Floating-point tolerances must come from the approved algorithm/test contract, not be widened after a failure.

Do not require a compressed output to remain byte-identical unless deterministic codestream identity is part of its contract. Equally, do not substitute pixel equivalence where the contract requires restoration of original encoded bytes. Separate exact integer comparisons, tolerated numerical comparisons and presentation comparisons in the test report.

### 5.2 Ownership and memory

**M64-007.** Every asynchronous resource has an explicit retained owner. Scoped raw-pointer borrows remain synchronous and do not span `await`, escape into tasks or become GPU ownership tokens. An owner wrapper must retain the actual allocation, not an unrelated object. Close or release only after all users have completed.

Use exclusive writes, explicit sealing/publication, generation-aware pool reuse and bounded concurrent jobs. Track copies separately from necessary algorithm workspace. A new container must not invalidate a shared-allocation contract. Test partial initialisation, failure, cancellation, outstanding readers and repeated cleanup.

**M64-008.** Bound dimensions, offsets, strides, recursion, frame counts, metadata, expanded output and aggregate live memory. Perform checked arithmetic before allocation or indexing. No untrusted-input force unwrap, cast trap, assertion failure, unchecked bounds access or process exit. Do not promise recovery from OS termination or every allocator-level out-of-memory failure; use admission limits and defined errors where recovery is supported.

### 5.3 Concurrency and diagnostics

**M64-009.** Keep a documented executor/isolation policy. Async does not by itself mean off-main execution. Bound task creation and fan-out. Preserve structured cancellation and error reporting. Review reentrancy, continuation completion, close/drain ordering and publication races.

Any `@unchecked Sendable`, `nonisolated(unsafe)`, manual pointer lifetime or unsafe interoperability boundary needs a local written proof, narrowly scoped implementation and relevant tests. Do not scatter detached tasks, disable exclusivity checking, use `-Ounchecked`, or introduce broad warning suppression as a migration strategy.

### 5.4 API, dependencies and licences

**M64-010.** Keep public names, module boundaries and contracts stable unless an explicit change is justified. Compile an independent client for changed public accessors, generic constraints, non-copyable types and concurrency annotations. Raising a compiler floor must be documented even when runtime behaviour is unchanged. A source-compatible rebuild is not an ABI compatibility proof for an existing distributed binary.

Preserve licences, notices and original provenance. The toolchain upgrade itself grants no relicensing authority. Do not add runtime package or native-code dependencies without the project's permitted dependency policy. Keep development-only oracles out of shipped products.

## 6. Execution sequence and exit gates

### G0 — Inventory and pin the task

Read current controlled inputs, scoped agent instructions and supplements. Record the repository URL, branch, source commit, working-tree state, dependency resolutions, tools/language modes, OS/architecture matrix, product graph, public API, shader/resource policy and active test inventory. Record known failures and excluded tests rather than trusting old totals.

Create a separate migration branch using the repository's naming policy. Preserve unrelated working changes. Choose and record the exact Swift 6.4 toolchain; include patch/build identity rather than a marketing label alone. Confirm required hosts, SDKs and devices before promising qualification coverage.

**Exit:** scoped plan, feature register, baseline identity and environment matrix exist. An unavailable runner is explicitly unexecuted.

### G1 — Capture existing behaviour where it exists

For implemented projects, reproduce the 6.2 baseline on its pinned source and dependencies. Retain its command results, failure inventory, sample outputs and relevant release-mode measurements. Do not repair unrelated baseline defects silently. Do not alter a historical evidence file to describe a new execution.

For documentation-only successors, identify the pinned predecessor evidence and create the new contract feasibility experiment in 6.4. For genuinely new applications, record this gate as not applicable to prior application code and establish the first baseline in 6.4.

**Exit:** truthful reference evidence, including gaps. Missing historical performance data prevents a measured improvement claim, not all forward engineering work.

### G2 — Qualify the new toolchain before redesigning code

Build the same source with the same dependency revisions under 6.4 wherever possible. Use separate build directories and caches. Keep SDK/build options comparable; document any unavoidable SDK change as a confounder. Fix only necessary compatibility issues first, in isolated changes.

Run debug and optimised builds, relevant tests, fresh consumer builds and resource loading. Inventory diagnostics. Establish whether failures are pre-existing, compiler/build-system changes or actual source defects. Do not combine a compiler switch, major dependency migration and algorithm rewrite into one comparison.

**Exit:** the existing behaviour works under the candidate toolchain to the declared coverage, or specific remaining failures are documented and promotion blocked where necessary.

### G3 — Establish the 6.4 development minimum

Update the tools-version declaration, CI/toolchain pins, development instructions, local scripts and agent references consistently. Preserve Swift 6 language mode and existing deployment targets. Record any implied/default setting differences revealed by the manifest change.

For a SwiftPM manifest, the intended declarations are `// swift-tools-version: 6.4` and `swiftLanguageModes: [.v6]`. Integrate them into the real manifest; do not replace the package with a generic template. Preserve current memory-safety settings. Use supported manifest APIs rather than unsafe flags that impair consumption as a dependency. [S03][S20]

**Exit:** the new minimum is explicit, independently consumable and documented. The old branch remains the historical reference; permanent dual-compiler source support is not required.

### G4 — Adopt selected features in small changes

Compile minimal probes for the selected F01–F13 features on every relevant target before broad adoption. Keep probes in an appropriate test/support location, not advertised production functionality. Make one coherent ownership, parsing or cleanup change at a time.

Prove the intended change at the public boundary as well as inside the module. Record the concrete reason when an older representation remains better. Do not alter an algorithm, public contract, GPU topology or deployment commitment merely to accommodate a fashionable feature.

**Exit:** each adopted feature has its availability evidence, tests and measured or clearly reasoned benefit. Deferred features have no hidden production dependency.

### G5 — Validate the complete candidate

| Verification family | Required evidence |
| --- | --- |
| Unit and semantic regression | Exact values, layout, metadata and error behaviour; representative edge cases; changed and adjacent code paths. |
| Ownership and concurrency | Single-writer/seal lifecycle; destruction exactly once; reader retention; failure/cancellation at transitions; repeated close/drain; bounded concurrency. |
| Input safety | Truncation, overflow, malformed geometry/metadata, allocation-limit refusal, excessive expansion and applicable fuzz/regression corpus. |
| Optimised execution | Release-mode correctness and teardown, not only debug success. Preserve any established crash reproducer as a regression case. |
| Dynamic tools | Applicable address/thread/undefined-behaviour tools where supported; separate runs as required. State what each tool cannot cover, including GPU work. |
| Platform and availability | Minimum supported OS, representative current OS and required native architectures; distinguish compilation, simulator execution and physical-device proof. |
| Build and packaging | Clean/incremental build, resource/shader discovery, plugins/macros where used, public consumer, all advertised products and dependency graph. |
| Performance | Same workload/configuration; throughput, latency distribution, peak memory, copies/allocations and code size where relevant; CPU and GPU costs separated. |
| Provenance | Source/dependency identities, fixture origin, commands/exit status, logs, outputs, SBOM and SHA-256 records. |

Set workload-specific performance acceptance thresholds before interpreting results. Follow existing numerical and memory budgets; do not invent a universal percentage that permits a correctness regression. Report warm-up, repetitions, device, OS, thermal/power conditions, variance and failures. A topology change is not automatically a performance gain.

**Exit:** required gates pass. Deferred/non-applicable gates have explicit scope reasons. A required unexecuted gate remains open; it cannot be relabelled as passed or silently removed from support claims.

### G6 — Handover, promotion and rollback

Submit a reviewable change with the report in Section 7. Update README/history, build instructions, API documentation and any affected shared contracts. Describe known limitations and the actual tested platform matrix. Do not reuse previous approval signatures or claim medical/regulatory readiness.

Keep the preceding source/toolchain baseline retrievable. A rollback restores a coherent source, dependencies, toolchain and resource set; it is not a manifest-only downgrade of source that now requires 6.4. New application projects have no invented 6.2 rollback target.

**Exit:** repository review and release rules determine promotion. These files do not create a tag, signed release, acceptance attestation or deployment.

## 7. Required migration records

Prefer existing repository evidence formats. Add the following information without creating a parallel governance system unnecessarily.

### 7.1 Feature register

| Feature ID | Location/use | Disposition | Toolchain/module/OS proof | Behaviour and lifetime tests | Benefit or deferral reason |
| --- | --- | --- | --- | --- | --- |
| F01–F13 | Populate per feature, splitting by target where necessary | Applicable / Conditional / Not applicable / Deferred / Prohibited | Exact probe and result | Named tests and outcomes | Measured result or specific rationale |

### 7.2 Change report

```text
Task and permitted scope:
Repository / branch / source commit / candidate commit:
Manifesto and supplement versions + SHA-256:
Controlling project inputs and conflicts resolved:
Prior baseline, or reason prior-code comparison is not applicable:
Swift/Xcode/SDK/Metal/compiler/build-engine identities:
Dependency resolutions and platform/deployment matrix:
Compatibility-only changes:
Feature adoption by F01–F13, including deferred features:
Public API / ABI / contract / licence impact:
Exact commands, exit codes and evidence locations:
Discovered / run / passed / failed / skipped test counts:
Known failures and required unexecuted gates:
Precision, copy, allocation, ownership and cancellation evidence:
Performance results and limits on attribution:
Resources/shaders, SBOM and integrity records:
Rollback reference and remaining work:
Requested reviewer disposition (not a fabricated approval):
```

### 7.3 Command discipline

Capture `swift --version`, relevant compiler target information, `xcodebuild -version` and SDK listings on Apple hosts, the source revision and the resolved dependency graph. Inspect `swift build --help`, `swift test --help` and installed SBOM command help before relying on new flags. Save exact executed commands and return codes; a sample command in documentation is not execution evidence.

Use local, synthetic or appropriately authorised fixtures under the project's privacy policy. Never send patient data, credentials, private code or test attachments to an external service as an incidental migration step.

## 8. Greenfield Oviyam and Mayam

**M64-011 — Start directly in Swift 6.4.** For the Apple-native applications, initialise packages/projects with the selected stable Swift 6.4 toolchain and Swift 6 language mode. Apply the feature assessment, concurrency, memory, availability and evidence rules from the first milestone. Select deployment targets through the existing product requirements and dependency compatibility assessment, not by inheriting the developer Mac's OS.

Use qualified DICOMKit/Voxelia configurations appropriate to the product. Keep UI isolation in UI targets and expensive work behind explicit library/executor boundaries. Separate application workflow, permissions, configuration, persistence and claims from reusable engines. Mayam's existing intended-use, risk and evidence requirements remain product responsibilities; adopting a compiler is not their verification.

This instruction applies to their **Swift implementations**, not every member of the product family. The dicom.js/Oviyam Web stack, Java server, Windows and Java implementations retain their separately approved technology choices. No extra Oviyam or Mayam upgrade supplement is needed at this stage.

## 9. Ready-to-use coding-agent task

> Read the common **Swift 6.4 upgrade manifesto v1.0.0**, the applicable project supplement and the repository's current controlled inputs and scoped agent instructions. Work only on the assigned repository and milestone. Inventory and pin the actual baseline; then qualify Swift 6.4 before changing ownership APIs or algorithms. Preserve architecture, dependency boundaries, supported platforms, precision, fidelity and existing safety/evidence obligations. Assess F01–F13 and implement applicable improvements in small, tested changes. Start new Apple-native Oviyam/Mayam code directly in 6.4 without inventing a 6.2 migration. Produce a reviewable change, exact test/benchmark evidence, a completed feature register and an honest list of open gates. Do not suppress diagnostics, broaden scope, tag a release, rewrite historical evidence or claim verification that was not performed.

## 10. Sources and verification notes

The technical feature descriptions above are based on primary Swift/Apple material. The engineering requirements and adoption gates are the programme's instructions, not claims made by those sources. Proposal examples may include experimental or future material; only the supported implementation verified in the pinned toolchain is eligible for production use. **No Swift 6.4 project builds, runtime tests or benchmarks were executed in preparing this publication.**

[S01]: https://www.swift.org/blog/swift-6.4-released/ "Swift 6.4 Released — 15 September 2026"
[S02]: https://developer.apple.com/xcode/system-requirements/ "Apple Xcode SDK and system requirements"
[S03]: https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html "SwiftPM PackageDescription: tools version and deployment compatibility"
[S04]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0525-rawspan-safe-loading-api.md "SE-0525: safe RawSpan loading and storing"
[S05]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0524-span-temporary-allocation.md "SE-0524: temporary allocation with spans"
[S06]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0527-rigidarray-uniquearray.md "SE-0527: UniqueArray and RigidArray"
[S07]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0517-uniquebox.md "SE-0517: UniqueBox"
[S08]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0507-borrow-accessors.md "SE-0507: borrow and mutate accessors"
[S09]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0516-borrowing-sequence.md "SE-0516: borrowing iteration / Iterable"
[S10]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0519-ref-mutableref-types.md "SE-0519: Ref and MutableRef"
[S11]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0493-defer-async.md "SE-0493: async calls in defer"
[S12]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0504-task-cancellation-shields.md "SE-0504: task cancellation shields"
[S13]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0532-optional-noncopyable-improvements.md "SE-0532: non-copyable Optional improvements"
[S14]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/testing/0021-targeted-interoperability-swift-testing-and-xctest.md "ST-0021: XCTest and Swift Testing interoperability"
[S15]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/testing/0024-per-test-case-repetitions.md "ST-0024: per-test-case repetition"
[S16]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0509-swift-sboms-via-swiftpm.md "SE-0509: SwiftPM SBOM generation"
[S17]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0522-source-warning-control.md "SE-0522: source warning control"
[S18]: https://www.swift.org/blog/swift-6.3-released/ "Swift 6.3 release: module selectors and optimisation controls"
[S19]: https://www.swift.org/blog/swift-6.2-released/ "Swift 6.2 release: pre-existing foundations"
[S20]: https://docs.swift.org/latest/documentation/packagemanagerdocs/6.4/ "SwiftPM 6.4 release notes; confirm syntax against installed toolchain"
[S21]: https://github.com/swiftlang/swift-book/blob/main/TSPL.docc/ReferenceManual/Statements.md#conditional-compilation-block "Swift conditional compilation"

### Reference index

[S01] Swift 6.4 release. [S02] Xcode requirements. [S03] SwiftPM versions and compatibility. [S04] RawSpan. [S05] Temporary allocation. [S06] UniqueArray/RigidArray. [S07] UniqueBox. [S08] Accessors. [S09] Iterable. [S10] Ref/MutableRef. [S11] Async defer. [S12] Cancellation shields. [S13] Optional. [S14] Test interoperability. [S15] Repetition. [S16] SBOM. [S17] Warning control. [S18] Swift 6.3. [S19] Swift 6.2. [S20] SwiftPM 6.4. [S21] Compilation conditions.

## Revision history

**1.0.0 — 18 September 2026.** Initial owner-directed common reference. Establishes controlled migration to Swift 6.4, explicit feature adoption, platform/availability and ownership safeguards, test/evidence gates, and direct 6.4 commencement for new Apple-native Oviyam/Mayam applications. No repository code or approval record is changed by this publication.
