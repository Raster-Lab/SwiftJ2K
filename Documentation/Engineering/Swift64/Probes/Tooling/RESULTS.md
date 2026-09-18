# Swift 6.4 F11/F12 tooling probe results

Read the supplied distribution README, common manifesto and suite supplement in that order. These are local synthetic/tooling probes, not final repository qualification. No codec algorithms, runtime dependencies or predecessor repositories were changed by this subtask.

Toolchain: Xcode 27.0 (27A266a); Apple Swift 6.4 (`swiftlang-6.4.0.34.1`, clang `2100.3.34.1`); Swift Testing 2084. Exact installed help and each argv/exit/cwd are saved alongside this report. All SwiftPM work used explicit `swiftbuild`, isolated scratch/cache/config/security paths, `DEVELOPER_DIR`, and an explicit nested-sandbox workaround (`--disable-sandbox`). The outer Codex sandbox remained in force.

## F11

- Synthetic test discovery succeeded with both frameworks enabled: four declarations (one XCTest, three Swift Testing; one Swift Testing declaration has two argument cases).
- `swift test ... --disable-xctest --enable-swift-testing --filter targetedRepetition --maximum-repetitions 3` passed: one declaration, two argument cases, six case executions. `--repeat-until pass` was not used. SwiftPM's xUnit represented this as one test, so it cannot be the sole source of case/repetition counts.
- An intentionally failing `XCTAssertEqual` inside `@Test` was actually reported and exited 1. It produced a failure plus an API-misuse warning recommending native Swift Testing assertions. This establishes failure visibility, not a recommendation to introduce mixed helpers.
- The opposite-direction probe (`#expect` inside XCTest) could not execute: the XCTest runner rejected the existing arm64 bundle with a load/architecture diagnostic. It exited 1 before assertions; this is an open environment gate, not assertion-interoperability success. Inspection with `file` confirmed an arm64 Mach-O bundle exists. Swift Testing executed the same compiled target successfully.
- SwiftPM help supports `--maximum-repetitions N` and `--repeat-until pass|fail` only for Swift Testing. Prefer a fixed maximum without a stop condition so all planned attempts run; retain failures. Installed xcodebuild help separately exposes `-test-iterations`, `-run-tests-until-failure` and `-test-repetition-relaunch-enabled` for a working Xcode frontend; no frontend execution was qualified here.

## F12

- Swift Build is the installed default. Explicit `--build-system swiftbuild` clean build succeeded; incremental build reusing the same scratch path succeeded. `native` and `xcode` engine choices are labelled deprecated in installed help; none was substituted.
- Synthetic resource bundle generation and resource loading by a fresh executable succeeded (`synthetic resource 42`). No plugins/macros/generated-code features exist in this synthetic fixture beyond SwiftPM's resource accessor.
- Build-associated `swift build ... --product ToolingProbe --sbom-spec spdx --sbom-output-dir ... --sbom-filter all` succeeded and emitted SPDX 3.0.1 JSON. Repeating with `cyclonedx` emitted CycloneDX 1.7 JSON.
- Graph-only `swift package ... generate-sbom --product ToolingProbe --sbom-spec spdx ...` succeeded but explicitly warned that build-time conditionals were absent. It is separate evidence and must not substitute for the build-associated command.
- Every SBOM emission warned that `SwiftPM_SBOMModel` schemas were unavailable and skipped validation. JSON parsing succeeded. Do not label this schema validation passed, or use `--sbom-warning-only` to hide errors.
- `xcodebuild -list -json` from a valid synthetic Swift package still exited 66 with “does not contain an Xcode project, workspace or package”, accompanied by file-type conformance/FSEvents/CoreSimulator diagnostics. This reproduces the earlier repository/workspace-recognition failure. No supported working frontend workaround was established. `xcrun swift build/test --build-system swiftbuild` is the qualified headless Xcode-toolchain route; it does not prove xcodebuild's frontend works.

## Repository validation script

All four successor repositories now contain byte-identical `Scripts/validate.sh`, `Scripts/validate-swift64.py` and `Scripts/README.md`. No CI workflow was invented because a hosted image with this exact Xcode build was not established. On a verified runner the same script rejects any wrong toolchain pin.

Default checks: clean/incremental debug and release, separate discovery and nonzero/equal-declaration execution checks, a fresh local consumer, five fixed targeted repetitions, and build-associated SBOMs in both formats. Optional `--sanitizers` adds isolated ASan/TSan runs; `--checks` selects a truthful subset. `--jobs` defaults to 2 per command. A fresh output directory is mandatory; command failures/timeouts and skipped tests fail the run. Source/manifests/scripts hashes, HEAD/dirty state and dependency-lock hash are recorded. No global xcode-select change or native fallback occurs.

A script smoke run on the in-progress SwiftJLI candidate passed debug builds/tests, local consumer, targeted repetitions and both SBOM emissions (`script-smoke-v3/report.json`). Debug: 34 discovered/executed declarations, 36 passing argument cases. Repetition: 11 declarations, 12 cases × 3 = 36 passing executions. No failures/skips. This is script behaviour evidence only, because source work was active and release/sanitizers were not selected. The final source needs the parent's complete qualification run.

Known script development failures are retained: `script-smoke` rejected interleaved stdout/stderr version formatting; matching the exact pinned version within output fixed it. `script-smoke-v2` found that `swift package --help` can load the manifest and needs the local-cache/nested-sandbox arguments too; the runner now supplies them to help commands as well. Neither failure was relabelled as passing evidence.
