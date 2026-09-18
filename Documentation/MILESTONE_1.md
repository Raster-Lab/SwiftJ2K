# SwiftJ2K — Milestone 1 implementation and validation

Date: 18 September 2026. Common contract: **0.2.1**. Intended library release: **12.0.0**, not tagged.

## Scope and current status

This owner-assigned milestone implements the independent common API surface and owning-memory contract using newly written in-house Swift. There are no codec algorithms, compressed-format parsers, working encoders/decoders/transcoders, CLI or external runtime codec dependencies. Capability sets are empty and unsupported operations fail explicitly. The native `Transcoder` shape exists only in SwiftJ2K/SwiftJXL.

The descriptor supports unsigned little-endian single-plane greyscale16, with 1–16 declared meaningful bits, checked dimensions/offsets/strides/capacity, packed or padded rows and two-byte alignment. `OwnedImageStorage` allocates zero-initialised bytes and enforces available/writing/sealed/invalid states through one shared provider lifecycle. Synchronous scoped borrows, a retained write lease and an immutable sealed owner prevent overlapping writes and premature publication. External unsafe providers retain explicit caller responsibilities.

## Validation record

**Milestone acceptance is blocked on compilation and runtime validation.** The initial [GitHub Actions run](https://github.com/Raster-Lab/SwiftJ2K/actions/runs/35309322447) for source revision `e62078029b8506a3fca5b96b24e8561922dcf27e` created five jobs. Every job failed before runner assignment: the job API reports an empty runner name and no executed steps. Consequently no Swift source was compiled and no unit, consumer, platform or sanitizer test ran. The job-log service returned no log; the available connection could not read the failure annotations. The reason for runner admission failure has not been verified. Inspect the linked run's annotation when restoring CI; do not assume a compiler error, runner-label problem or billing cause from this evidence alone.

The editing environment is Ubuntu 24.04 x86_64 and `swift --version` exits 127 because Swift is not installed. The official Swift 6.2 archive download attempt timed out at the network proxy. That local gate is also unavailable. Later source refinements and the integration fixture remain uncompiled and unexecuted; the PR stays a draft. No pass count, benchmark result or qualified platform support is claimed.

Local static checks passed: the staged diff has no whitespace errors, all seven common document hashes match, all six neutral API/storage source files match across the four modules, Python validation scripts compile, the Apple build script passes Bash syntax checking, and the workflow parses as YAML. These are checks of repository consistency and tooling syntax, not Swift type-checking or runtime correctness. A machine-readable first-attempt record is in `Documentation/Validation/initial-ci-attempt.json`.

Run these commands from the repository root:

```sh
python3 Scripts/validate.py
python3 Scripts/check_url_consumer.py <published-commit-sha>
swift test -j 2 --scratch-path .build/asan --sanitize address
swift test -j 2 --scratch-path .build/tsan --sanitize thread
bash Scripts/validate_apple_sdks.sh
```

The first command records debug/release build and test exit codes, xUnit output, compiler/target information and the standalone public consumer outcome in `.validation/`. The URL consumer creates a fresh temporary package and resolves this repository at the supplied SHA; it does not discover siblings. CI uses the official Swift `6.2.0-noble` container on Ubuntu 24.04 and Xcode 26.0.1 for macOS/Apple SDK checks. Runner setup logs record actual runner/image revisions. Pinned action revisions and exact commands are in `.github/workflows/contract.yml`.

## Evidence boundaries and next milestone

Synthetic tests exercise storage and API behaviour only. They are not compressed-format interoperability, codec regression, throughput, real-transcode copy counts or medical validation. No comparative performance numbers are claimed. The default owner uses one zero-initialised allocation and small wrappers; metadata is budgeted separately. The private raw allocation's unchecked concurrency bridge carries its safety proof in source; public owners/leases use checked Sendable conformance.

Native device runtime tests, controlled performance baselines, parser fuzz campaigns and independent codec oracles remain later gates. Any CI jobs that did not execute or failed must be resolved or explicitly recorded; workflow presence never establishes support. Milestone 2 requires a separate assignment and begins with the pinned predecessor baseline/provenance inventory in HISTORY.md and IMPLEMENTATION.md.

## Separate two-module adapter experiment

`IntegrationTests/SharedStorage` is a development-only package with an explicitly pinned SwiftJLS dependency. The root SwiftJ2K package remains independent. The fixture maps descriptors/errors and forwards writable, lease and read-only protocols to one actual provider. Tests cover both reservation orderings, exact padded/offset 12-in-16 and full16 samples, retained ownership across suspension, concurrent readers and terminal failure/cancellation. Scope and owner observations are deliberately distinguished from process-wide allocator telemetry. See its README for deterministic fixture hashes and commands. This experiment has not yet compiled or run because of the validation blockers above.
