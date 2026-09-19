# Swift 6.4 probe evidence

This text-only archive preserves the recorded feasibility and tooling probes for all four successor repositories. Read the [feature register](../FEATURE_REGISTER.md) and [upgrade evidence index](../README.md) for production decisions and remaining gates. Passing a small probe is not full repository or minimum-OS runtime qualification.

## Provenance and layout

Files copied from the following original directories retain their exact bytes. Paths, timestamps, commands, failures and intermediate source identities inside records have not been rewritten.

| Archive directory | Original absolute directory |
| --- | --- |
| `Ownership/` | `/Users/suresh/Documents/Codex/2026-09-18/create-coding-agents-to-start-work/work/swift64-probes/ownership/` |
| `RawSpan/` | `/Users/suresh/Documents/Codex/2026-09-18/create-coding-agents-to-start-work/work/swift64-probes/rawspan/` |
| `Tooling/` | `/Users/suresh/Documents/Codex/2026-09-18/create-coding-agents-to-start-work/work/swift64-probes/tooling/` |

- **Ownership:** standalone Swift sources, runner, exact commands/results and logs for F03–F10/F13. Availability and missing-member rejections are intentionally negative probes. See [results.json](Ownership/results.json).
- **RawSpan:** F01/F02 sources, runners, environment/linkage logs, [selected SDK declarations](RawSpan/selected-declarations.txt), [report](RawSpan/REPORT.md) and results. The [final focused tests](RawSpan/focused-tests/results.json) cover the final OutputRawSpan writer. The `initial-typecheck`, `initial-provider-typecheck` and `before-output-span` folders preserve development failures or intermediate results; they do not qualify the final candidate. Source templates/fragments are authoring evidence, not extra package targets.
- **Tooling:** installed CLI help, [report](Tooling/RESULTS.md), argv/exit records, test logs/XML, small emitted SBOM JSON files, and the portable [synthetic Swift package](Tooling/Fixture/Package.swift), including its text resource. The fixture intentionally fails when `PROBE_EXPECT_MIXED_FAILURE=1`; the opposite-direction XCTest probe failed before assertions. The `script-smoke-v3` report, root logs/XML and referenced SBOMs describe an intermediate script smoke run, not final repository qualification.

`SHA256SUMS` covers every other file in this archive, including this README. The archive is identical in all four repositories. Generated executables, libraries, compiler/build caches, scratch build trees, complete SDK interfaces and generated smoke-consumer trees are excluded. Earlier `script-smoke`/`script-smoke-v2` directories mentioned in the tooling report remain at their original paths; their development-failure summaries are preserved in that report, but their raw artifacts are not included here.

## Reproduction and interpretation

The recorded host was macOS 27, arm64, with the pinned Xcode 27 / Swift 6.4 toolchain. OS 26 targeting proves compilation only; execution on OS 26 remains open. Native Intel/Linux/device execution, sanitizers, benchmarks and final repository qualification must be read from their separate evidence. SBOM JSON parsing does not imply schema validation; the recorded generator reported unavailable schemas.

To reproduce, copy the required probe sources/fixture into a disposable directory and select the recorded compatible toolchain. Preserve this archive: runners create binaries/caches and overwrite their result files. Ownership and basic RawSpan runners resolve nearby sources; `RawSpan/run-focused-tests.py` assumes the original suite workspace layout and must be adapted in the disposable copy. The archived `Tooling/validate-swift64.py` is an exact development snapshot that expects to live in a repository's `Scripts` directory; use the current repository `Scripts/validate.sh` for new qualification. The synthetic Tooling fixture is portable, but the historical command records keep the original absolute paths and environment.

Expected negative probes, frontend/XCTest failures and unexecuted gates must remain visible. No result here establishes that every upgrade gate passed.
