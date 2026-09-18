# Command-line and transcoding contract

Contract **0.3.0**. This foundation supplies instructions only; no CLI exists in these successors yet.

## Native codec commands

**CLI-01.** Successor executable names are `swiftj2k`, `swiftjls`, `swiftjxl` and `swiftjli`, avoiding accidental replacement of predecessor binaries. Shared verbs: `encode`, `decode`, `inspect`, `validate` and `capabilities`. `--help` and `--version` work consistently. Codec-specific operations/options remain explicitly named and capability-checked. No individual CLI depends on another suite codec to offer transcoding.

**CLI-02.** Shared flags: `--input` / `-i`, `--output` / `-o`, `--input-format`, `--output-format`, `--mode lossless|near-lossless|lossy`, `--max-error` for supported integer near-lossless modes, `--backend`, `--copy-policy require-sharing|allow-copy`, `--threads`, `--max-memory`, `--timeout`, `--overwrite`, `--json` for structured inspection/reporting and `--quiet`. Defaults follow the API. Mode-incompatible arguments fail. Codec-specific lossy controls state units; no shared numeric quality promise. Command-local help lists relevant flags rather than pretending every flag applies to every verb.

`-` denotes standard input/output. Binary payload output is exclusively stdout; progress and diagnostics go to stderr. Structured JSON output must not contaminate a binary stream. `inspect --json` returns inspection data; encode/decode JSON reports use stderr or an explicit report destination. Never infer a missing filename extension as permission to reinterpret raw bytes. Unsupported/ambiguous formats fail before output publication when discoverable.

**CLI-03.** Exit codes: 0 success; 2 invalid command/options; 3 malformed input; 4 unsupported format/feature/layout/backend; 5 resource limit/deadline; 6 I/O/storage failure; 7 internal failure; 130 user cancellation. Broken output pipe is an I/O failure and must not print a success report. Map API categories deterministically. File output refuses overwrite without `--overwrite`; use a sibling temporary final-output file and atomic replacement where supported. That transaction file contains the final encoded output, never an intermediate uncompressed image. Remove incomplete transaction files on failure. Binary stdout cannot be rolled back; document partial output and return failure.

## Ordinary shell pipes

**CLI-04.** A shell pipe carries bytes between processes, not a valid shared pointer. Provide a standard streamable interchange profile for piping, independently of the no-copy in-process route. The initial planned profile is an attached NRRD header with raw, uncompressed sample bytes, greyscale dimensions, explicit integer type and endian. No detached filenames, URLs, external data references, compressed payload encodings or arbitrary metadata execution in this bounded profile.

Before implementing the NRRD parser, pin and review the official specification. Use strict header/field/count limits. Unknown essential type/layout fields fail. Restrict the first profile to 2D greyscale full-precision UInt16; add colour, signed and other precision cases only with explicit interoperable metadata semantics. A standard NRRD uint16 header alone cannot promise preservation of source-declared 12 meaningful bits or every colour/ICC interpretation. In strict preservation mode, reject an unrepresentable semantic requirement; an explicitly chosen extension/profile requires its own contract and tests. Do not invent a private default stream format to bypass this limitation.

A future example, once the profile exists, is `swiftj2k decode -i input.j2k --output-format nrrd -o -` piped to `swiftjls encode -i - --input-format nrrd --mode lossless -o output.jls`. This avoids an intermediate disk image, but serialisation and pipe copies mean it is not the shared-allocation guarantee. Provide bounded back-pressure and cancellation propagation.

## Optional in-process umbrella

**CLI-05.** The optional umbrella supplies one transcode operation selecting source and destination codecs and the explicit copy/fidelity policy. Its executable/repository name is not assigned here. Both codecs run in one process; one owner retains final decoded storage and adapters forward it. The initial JPEG 2000 -> JPEG-LS proof precedes a general codec matrix.

The umbrella owns detection/selection, preflight capability checks, admission/resource accounting across the whole chain, adapter mapping, cancellation, result publication and consolidated copy/backend reporting. It must preflight metadata/precision representability before output when possible. It never auto-selects a lossy destination to satisfy an unsupported request. No temporary decoded image file, private intermediate encoding or external codec executable is allowed. Metadata that belongs to DICOM remains the application's responsibility.

Cross-process shared memory/IOSurface handle passing is a separate future feature, requiring an explicit protocol, ownership and security review. Do not pass numerical pointers through a shell pipe or imply this foundation implements such a protocol.

## Verification

Cover spaces/non-ASCII filenames, empty input, huge declared dimensions, malformed interchange headers, truncated binary streams, slow readers, downstream early exit, cancellation, existing output, unwritable directories and file cleanup. Execute every example in help/docs against fixtures once implementation exists. File parsing must not follow untrusted detached references or make network requests.

Reference: [NRRD format](https://teem.sourceforge.net/nrrd/format.html). The limited stream profile is planned; interoperability must be proven before advertising it.

## Standalone native transcode commands

**CLI-06.** SwiftJ2K and SwiftJXL each implement `transcode` for their own supported native format pairs, in a single process and without another codec library or an umbrella. SwiftJ2K handles Part 1 J2K ↔ Part 15 HTJ2K; SwiftJXL handles existing lossy JPEG ↔ JPEG XL with original-JPEG reconstruction data. SwiftJLS/SwiftJLI need not implement a placeholder native pair. The separate optional umbrella remains responsible for general cross-library transcoding.

Use `--input`, `--output`, `--input-format`, `--output-format`, `--mode lossless` and the shared resource/backend/copy/reporting flags. Lossless is the default; for J2K/HTJ2K it means sample/interpretation preservation on qualified lossless sources, and for JPEG/JXL it means original-JPEG byte restoration. Reject incompatible lossy/quality settings and metadata-discard requests. Do not make pixel re-encoding the default for reversible JPEG recompression. Reverse reconstruction has no dependency on a `--source original.jpg` argument.

Validate format claims against the bytes, declare supported raw/container variants and fail for absent reconstruction data or unsupported precision/features. All intermediate samples, coefficients and reconstruction metadata stay in owned memory. Standard input/output may carry the compressed endpoints; a shell pipe is not a pointer. File I/O is limited to input/final-output/report handling, with the existing atomic-output, cancellation and stderr rules. Repository-specific TRANSCODING.md examples are planned command tests until executable implementations exist.
