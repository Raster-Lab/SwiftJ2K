# Release procedure for SwiftJ2K 12.1.0

Prepared in Milestone 5 (22 September 2026, contract 0.9.0). This is the procedure the owner's explicit release task follows; nothing here is executed by Milestone 5 itself, and no tag exists yet. IMPLEMENTATION.md: "stable tag only after explicit release task". TESTING.md TEST-07: "No new stable version tag until required correctness, interoperability, platform, security and performance gates are complete."

## Preconditions the release task must verify first

1. **Continuous integration executes.** Contract 0.9.0 requires a successor workflow run with non-zero steps before any codec source moves and before any stable tag. Check the latest run on `main`:
   ```sh
   gh run list --branch main --limit 1 --json databaseId --jq '.[0].databaseId' | xargs -I{} gh api repos/Raster-Lab/SwiftJ2K/actions/runs/{}/jobs --jq '.jobs[] | "\(.name): \(.conclusion) steps=\(.steps|length)"'
   ```
   Every job at `steps=0` means the Actions billing lock is still in place and the release cannot proceed. Milestones 2 to 5 were all executed under that condition and say so.
2. **Private vulnerability reporting is enabled** on the repository (SECURITY.md). `gh api repos/Raster-Lab/SwiftJ2K/private-vulnerability-reporting` must report `"enabled": true`. Organisation-owner action.
3. **The owner has assigned the release task explicitly.** Milestone 5 completion is not that assignment.

## Gates at the release commit

Run all of these on the exact commit to be tagged and archive the outputs under `Documentation/Engineering/Release-12.1.0/Evidence` with absolute host paths removed, as the milestone records do. Commands assume the repository root, Xcode 26.2 (Apple Swift 6.2.3) and the swift.org 6.4 toolchain; substitute the identifiers actually present and record them.

| Gate | Command | Pass condition |
| --- | --- | --- |
| Xcode toolchain, native engine, debug and release | `DEVELOPER_DIR=/Applications/Xcode-26.2.app/Contents/Developer xcrun swift test --build-system native -c debug --disable-xctest` and `-c release` | 78 declarations pass, none skipped except the oracle test when tools are absent |
| Swift 6.4, Swift Build engine, consumer, repetitions, SBOM | `DEVELOPER_DIR=… TOOLCHAINS=org.swift.640202609131a ./Scripts/validate.sh --output <new dir>` | `report.json` status `passed`; both SBOMs emitted |
| Sanitizers | `./Scripts/validate.sh --checks asan,tsan --output <new dir>` under the toolchain on which they execute (see MILESTONE5.md for which one that was) | both runs pass |
| Linux arm64 container | `colima start; docker run --rm --platform linux/arm64 -v "$PWD":/SwiftJ2K -w /SwiftJ2K swift:6.2-noble swift test` then the release build, `Scripts/test-cli.py` and `Examples/Consumer` | as in MILESTONE4.md |
| CLI conformance | `python3 Scripts/test-cli.py --binary <release swiftj2k-cli> --output <new dir>` | 147 of 147 |
| Contract harness | `xcrun swift run --package-path Integration/ContractHarness ContractHarness` | 6 of 6 |
| Fuzz campaign | `Integration/FuzzHarness` for one hour per entry point (`inspect`, `decode`, `decodeInto`), seed recorded | zero unexpected errors, zero traps, no input over the deadline |
| Release benchmark | `python3 Scripts/benchmark-lossless.py --binary <release swiftj2k-cli> --output <new dir>` on an unloaded host | no median regression over 5% against the previous record (PERF-03) |
| Apple SDK matrix | `xcodebuild -scheme SwiftJ2K -destination 'generic/platform=<iOS|iOS Simulator|tvOS|tvOS Simulator|watchOS|watchOS Simulator|visionOS|visionOS Simulator>' build` | every platform builds |
| Fresh URL consumer | a package outside the repository with `.package(url: "https://github.com/Raster-Lab/SwiftJ2K.git", revision: "<release commit>")` | resolves this repository alone and round-trips |

Anything unexecuted is recorded as unexecuted in the release notes, never as passed.

## Version and tag steps

1. Set `VERSION` to `12.1.0`; update the version string in `Sources/SwiftJ2KCLI/main.swift`, the `.TH` line of `ManPages/swiftj2k-cli.1`, the version lines in `README.md` and `CLI.md`, and turn the top CHANGELOG entry into `## 12.1.0 — <date>` with the executed gates listed.
2. Commit as `Release 12.1.0` and open a pull request; merge only after the gates above have been archived.
3. Tag the merge commit with an annotated tag and push it:
   ```sh
   git tag -a v12.1.0 -m "SwiftJ2K 12.1.0" <merge commit> && git push origin v12.1.0
   ```
4. Create the GitHub release from the tag with the CHANGELOG entry as its body. Attach nothing that was not built from the tagged commit.
5. Verify consumption from the tag with a fresh package using `.package(url: …, from: "12.1.0")`, and verify installation with `Scripts/install-cli.sh --prefix <staging>`.
6. Start the next development line: `VERSION` to `12.1.1-dev.1` (or `12.2.0-dev.1` for a feature line) on `main`.

## After the release

- Tags are never deleted or moved (POL-07). A defective release is followed by a patch release.
- SECURITY.md's supported-version table becomes effective.
- Predecessor J2KSwift enters its maintenance window (contract 0.8.0 item 6); consumers re-point in their own owner-assigned tasks (MIGRATION.md).
