# Coding-agent instructions

Applies to Claude, Codex and other coding agents working in this repository.

## Start here

Read `README.md`, `HISTORY.md`, this file and `IMPLEMENTATION.md`, then all seven common contract documents in `Documentation/`. Read the repository-specific `TRANSCODING.md` when present before work affecting transcoding. `CLAUDE.md` points here and is not a separate policy. Follow the precedence in `Documentation/SUITE_POLICY.md`.

The owner has assigned Milestone 1. The repository now contains its package, API/owning-memory source, synthetic tests and CI definitions. Consult `Documentation/MILESTONE_1.md` for actual validation evidence and remaining gates. Reading this file does not authorise moving to a later milestone. Codec migration, real transcoding and CLI remain deferred; do not report API shells as implemented compression functionality.

## Required working method

1. Confirm the task, target repository, pinned predecessor revision and contract version. Inspect existing working changes before editing. Work on an isolated feature branch; preserve unrelated work.
2. Inventory the relevant predecessor paths, tests, capability coverage, external material and failure cases. Source at the pinned SHA is evidence; stale README claims are not implementation proof. Read scoped predecessor guidance for migrated files and reconcile it with the new contract.
3. Establish the relevant predecessor baseline and record failures/skips. Add meaningful tests for the new contract before claiming migration success. For contract feasibility, compile an isolated ownership/adapter experiment before moving large codec subsystems.
4. Implement the smallest complete assigned milestone. Maintain the common API, memory lifecycle, platform boundaries and explicit fidelity/copy policies. No dependency on another suite codec or shared-foundation package.
5. Run the affected unit and regression groups, independent oracle checks and memory/security tests required for the change. Use controlled release benchmarks for changed hot paths. Expand testing to resolve a concrete risk or required gate, not to inflate a test count.
6. Review the diff, public API, unsafe operations, licence/provenance and emitted resource/copy reports. Update documentation to distinguish implemented, tested, unexecuted and deferred capabilities. Submit a reviewable PR with exact commands and outcomes. Do not tag a stable release merely because compilation passes.

## Non-negotiable engineering rules

- Swift 6.2 minimum, Swift 6 language mode and complete concurrency checking. Expensive codec work must have a defined executor policy and bounded cancellation points.
- Validate untrusted sizes, offsets, strides, entropy counts and lengths with checked arithmetic. Throw defined errors. No input-dependent force unwrap/cast, assertion trap, uncontrolled allocation or process exit.
- No raw pointer may outlive its scoped borrow; no array/Data buffer pointer becomes an async storage owner. Retain owners and join CPU/GPU work before release. Raw unsafe borrow APIs document caller obligations; closure syntax alone does not prove pointer non-escape.
- An unchecked concurrency annotation needs a local written proof and relevant lifetime/race tests. Do not weaken language mode or globally suppress diagnostics to pass CI.
- Do not reduce bit depth, change signedness, apply display transformations, change compression fidelity or spill decoded images to disk implicitly.
- Prefer common scalar correctness and small measured acceleration boundaries. No runtime fallback to an external reference codec or shell executable.
- Keep codec-specific options explicit. Test declared capabilities; reject unsupported combinations. Use British English in prose.
- Do not relicense third-party code/fixtures, add secrets/patient data, rewrite predecessor history, delete existing repositories, or change organisation permissions as part of implementation.

## Change report required from the agent

State what behaviour changed and why, exact source/baseline/contract revisions, commands and exit results, skipped/unavailable gates, sample/copy/lifetime evidence, performance/memory impact and remaining limitations. Separate measured facts from expectations. Include links to tests and fixture provenance. No invented test counts, benchmark numbers, platform verification or medical/regulatory claims.

## Ready-to-use first task prompt

"Read AGENTS.md, IMPLEMENTATION.md, HISTORY.md and the common contract. Carry out Milestone 1 only: validate the local public API and owning-memory contract in Swift 6.2, with meaningful descriptor, lifetime, concurrency and independent-consumer tests. Use synthetic buffers for the adapter experiment and preserve repository independence. Do not migrate codec algorithms or implement the real transcoder in this milestone. Return a reviewable PR, exact test evidence and any concrete contract issue requiring a coordinated revision."

Later task prompts must name the next milestone explicitly. Repository creation and documentation publication are separate from authorising codec implementation.
