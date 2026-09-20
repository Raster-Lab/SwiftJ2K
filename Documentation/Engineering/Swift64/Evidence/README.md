# Swift 6.4 historical validation evidence — SwiftJ2K

This archive preserves the final validated candidate and its baseline. Original text files are copied byte for byte except physical hardware identifiers, which are redacted only in public copies. `PROVENANCE.json` identifies each exception with original and archived SHA-256 values, and maps every file to its historical workspace source; derived JSON records identify their input hashes and transformation. `SHA256SUMS.txt` covers every archive file except itself. `SOURCE_FINGERPRINTS.json` records successful comparisons at archival time, 2026-09-18T22:29:23.936543+00:00. A later code change requires new validation evidence.

| Directory | Evidence and limits |
| --- | --- |
| Baseline | Committed pre-upgrade source built and tested with Swift 6.4. This is not a Swift 6.2 execution. The source snapshot and build outputs are intentionally excluded. |
| Candidate | Original validation report, discovery/test logs, xUnit XML, build-associated SBOMs, validated package/runner files and fresh local consumer. Includes separate ASan and TSan runs and targeted repetitions. |
| Platforms | The final SDK matrix filtered to this repository, with all ten compile/link logs. It proves compile/link coverage, not device, simulator or minimum-OS runtime execution. |
| Xcode | Successful headless macOS test log, original xcresulttool summary and summary command. The xcodebuild command record is explicitly reconstructed from the log and executor report. The binary `.xcresult` bundle is excluded. |
| MigrationExamples | Compiled migration snippet, generated consumer, original log and filtered result record. |
| Harness | Suite contract harness source, commands and Debug/Release/ASan/TSan logs. Its manifest historically references all four local checkouts. |
| Environment | Original toolchain, SDK and machine evidence, including unsuccessful environment probes and their exits. |
| SBOMAudit | Structural/provenance audit and official schema references. Generator conformance defects remain; full schema/semantic validation was not completed. The SBOMs have not been rewritten or declared valid. |
| Benchmark/Original | Original storage-only benchmark, all raw samples, summaries, resource logs and source/scripts. |
| Benchmark/Repeat | Complete repeat measurements and console output, including regressions. Uses the benchmark sources and executables identified in its records. |
| Benchmark/SandboxAttempt | Earlier failed process-measurement attempt, retained separately from completed measurements. |

The benchmark exercises the shared storage implementation through SwiftJ2K on one host; it does not measure codecs or establish platform-wide performance. The initial candidate and both benchmark runs are retained regardless of their outcomes. Test summary counts can distinguish test declarations from parameterised case executions; use the original XML/logs and report fields.

Absolute paths, command working directories, timestamps and dirty-tree identifiers are historical provenance, not relocatable build instructions. Copies of scripts/manifests are evidence; they retain original path assumptions and may need an equivalent workspace layout to rerun. Use the repository's current `Scripts/validate.sh` for a new run. No build caches, modules, executables, native binaries or `.xcresult` directories are included. Native SDK/framework code is outside the SwiftPM package dependency graph represented in the generated SBOMs.

Verify archive integrity from this directory with `shasum -a 256 -c SHA256SUMS.txt`. Cross-check copied file hashes against `PROVENANCE.json`; filtered records are explicitly derived, not byte-identical copies of the suite-wide input JSON.
