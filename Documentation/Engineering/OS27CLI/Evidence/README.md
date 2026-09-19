# OS 27 / CLI evidence archive

Exact logs, command/exit records, test counts, generated SBOMs and benchmark samples from this follow-up. PROVENANCE.json maps original local files and SHA-256 digests to copies or explicit derived subsets. Physical device identifiers are redacted in public Xcode records only; unmodified originals remain local. Caches, executables and binary xcresult bundles are excluded.

FINAL_INPUTS.json distinguishes unchanged tested Swift/library inputs from the later installer/manual-version guard and its rerun CLI tests. Candidate/report.json is the original full-suite record; it is not rewritten to imply the final installer scripts existed during that earlier run. CLI/report.json hashes the final installer and CLI test runner and records their executed checks. InstallerBuild records the default build-and-install path, separately from the prebuilt-binary tests.

XcodeInitialScheme retains the failed use of former library schemes; adding products moved tests to the generated Package schemes. Xcode retains the successful package tests and CLI release build/run. InitialChecks retains the nested-cache permission failure, corrected compilation, and corrected man-date/line-format and terminal-overstrike test assertions. These are retained environment/development failures, not silently skipped tests.

Benchmark samples compare the preceding Swift 6.4 candidate against the OS 27 change on one host. Both iterations remain intact. The short allocation-timing threshold crossing did not reproduce; no compiler/codec speedup or acceptance waiver follows. SBOM JSON generation succeeded, but full schema/semantic conformance remains open and field findings are preserved. Read the parent qualification report for scope and platform limits.

Absolute command paths and copied runners retain historical workspace assumptions; they are provenance rather than portable entry points. Use the repository's Scripts documentation for a new run. Verify files here with `shasum -a 256 -c SHA256SUMS.txt`.
