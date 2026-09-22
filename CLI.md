# swiftj2k: help, diagnostics and installation

Version **12.1.0-dev.6**; Swift 6.2 minimum with Swift 6.4 qualified / Swift 6, Apple OS minimum **26.0**. The CLI targets macOS and Linux; Linux execution remains a qualification requirement. No external parser package or sibling codec is required. Since Milestone 4 the `encode`, `decode`, `inspect` and `validate` verbs operate on the library's scalar lossless JPEG 2000 path through the NRRD interchange profile below; `capabilities` reports the library's actual support. `transcode` remains reserved (exit 4) without opening input, consuming stdin or creating output.

```sh
swift run swiftj2k --help
swift run swiftj2k -h
swift run swiftj2k help capabilities
swift run swiftj2k capabilities --help
swift run swiftj2k --version
swift run swiftj2k capabilities --json
swift run swiftj2k capabilities -vv
swift run swiftj2k capabilities -verbose: 3
swift run swiftj2k capabilities --verbose=+++++
```

Both global and command-local help include availability, examples, option ranges/defaults, streams, errors and manual discovery. No arguments also show help. Use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` with the qualified Xcode on macOS.

## Codec commands and the NRRD interchange profile (CLI-01..CLI-04)

```sh
swiftj2k encode -i slice.nrrd -o slice.j2k --precision 12 [--levels N] [--code-block WxH]
swiftj2k decode -i slice.j2k -o slice.nrrd [--overwrite]
swiftj2k inspect -i slice.j2k --json
swiftj2k validate -i slice.j2k
swiftj2k decode -i - -o - < slice.j2k | swiftj2k encode -i - --input-format nrrd -o - > copy.j2k
```

`-i`/`--input` and `-o`/`--output` accept `-` for standard input (read completely) and binary standard output. `--input-format` and `--output-format` take `j2k` (raw JPEG 2000 codestream) or `nrrd`; a declaration is checked against the bytes and a mismatch is exit 4, and without one the format is detected from the bytes, never from a filename. File output goes to a sibling temporary file and is renamed into place; an existing file is refused with exit 6 unless `--overwrite` is given, and nothing partial remains after a failure. `--json` puts a JSON document on stdout for `inspect` and `validate`, and a JSON report on stderr for `encode` and `decode` so binary stdout stays clean. `--mode lossless` is the only mode; `--backend scalar` the only backend; `--copy-policy`, `--threads` (1..8), `--max-memory` (bytes) and `--timeout` (seconds, exit 5) map to the library's options and limits. Every option value is validated before any input is opened.

**Encoder options.** `--levels 0..32` (default `min(5, floor(log2(min(width, height))))`), `--code-block WxH` with powers of two from 4 to 1024 and area at most 4096 (default 64x64), and `--precision 1..16` for the meaningful bits when the NRRD header carries none (default 16). The encoder writes one tile at the origin, one layer, default code-block style, reversible 5/3.

**Decoder coverage.** Unsigned greyscale, 1..16 bits, reversible 5/3, no quantisation, any tile grid and image or tile origin, any number of quality layers, every code-block style bit (bypass, reset, termination on each pass, vertically causal, predictable termination, segmentation symbols), every progression order, precincts, SOP/EPH markers, several tile-parts and tile-part header overrides. Rejected with exit 4: HTJ2K, the 9/7 wavelet, quantised codestreams, colour, signed or sub-sampled components, ROI, POC, PPM/PPT and JP2 containers.

**NRRD profile (CLI-04, pinned to the NRRD format specification at teem.sourceforge.net/nrrd/format.html).** Attached header ending in an empty line; magic `NRRD0001`..`NRRD0005`; fields `type: uint16` (also `ushort`, `unsigned short`, `uint16_t`), `dimension: 2`, `sizes: W H`, `encoding: raw` and `endian: little` or `big`; the standard key/value line `swiftj2k.meaningfulbits:=N` (1..16) records the declared precision, which `decode` always writes and `encode` reads back (a contradicting `--precision` is a usage error). `data file`, `line skip`, `byte skip`, `block size`, other types, dimensions and encodings are refused with exit 4; a data length other than `W*H*2` bytes is malformed (exit 3); comments are ignored. `decode` writes little-endian samples. The profile carries no colour, ICC or DICOM semantics, and it is the pipe interchange described in the contract, not the in-process shared-storage route.

## Verbosity

| Level | Cumulative stderr diagnostics |
| --- | --- |
| 0 (default) | Errors only |
| 1 | Version/operation summary |
| 2 | Command stages |
| 3 | Capability/configuration details |
| 4 | Elapsed timing |
| 5 | Bounded execution trace |

`-v` increments, `-vv` through `-vvvvv` group increments, and `--verbose LEVEL`, `--verbose=LEVEL`, `-verbose: LEVEL` or `-verbose:LEVEL` set an explicit level. Digits 1..5 and `+`..`+++++` are equivalent. Bare `--verbose` / `-verbose` increment once. Options apply in order; exceeding 5 or supplying an invalid level returns 2. `--quiet` / `-q` conflicts with any positive verbosity. Errors still print in quiet mode. Help, version and capability output remain stdout data. Diagnostics never contaminate JSON or log payload bytes, metadata, raw addresses or input/output paths.

## Install or update the binary and UNIX manual

Run the installer from this source checkout. It builds the release executable and installs both the binary and matching manual every time; rerunning updates both. No administrator command runs automatically.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./Scripts/install-cli.sh --prefix "$HOME/.local"
"$HOME/.local/bin/swiftj2k" --help
man -M "$HOME/.local/share/man" swiftj2k
```

Default prefix is `/usr/local`; choose an absolute writable prefix. Add its `bin` directory to PATH. For ordinary `man swiftj2k` lookup with a custom prefix, configure MANPATH to include `PREFIX/share/man` while retaining system defaults (for example `export MANPATH="$HOME/.local/share/man:${MANPATH:-}"`). Direct `man -M` needs no index refresh. The page is [ManPages/swiftj2k.1](ManPages/swiftj2k.1). A packaging recipe must install both `PREFIX/bin/swiftj2k` (0755) and `PREFIX/share/man/man1/swiftj2k.1` (0644).

`--destdir /absolute/staging` (or DESTDIR) stages those same prefix-relative locations for packaging. `--binary /absolute/built/swiftj2k` avoids a rebuild and verifies `--version` against VERSION before writing. `--scratch-path` selects a build directory; `--disable-package-sandbox` is only an explicit workaround for nested sandbox restrictions. An existing destination symlink/directory is refused. Merely copying the executable does not install its manual.

## Exit codes and validation

Exit statuses: 0 success; 2 invalid usage or argument (including a library `invalidArgument`); 3 malformed input; 4 unsupported format, feature, layout or backend (also the reserved `transcode`); 5 resource limit or deadline; 6 I/O or storage failure, including an existing output without `--overwrite` and a closed pipe; 7 internal failure; 130 interrupted by SIGINT with nothing published. The mapping from `CodecError` categories is fixed in the executable; library errors cannot terminate the host application, and exit handling exists only here.

`Scripts/test-cli.py --binary /absolute/built/swiftj2k --output /new/evidence/directory` checks the real executable: help, verbosity, JSON separation, every codec verb against the repository fixtures (sample-exact decode to NRRD, re-encode, validate, a decode | encode | decode pipe), overwrite refusal and atomic replacement, format declarations, NRRD profile rejections, every exit status including SIGINT, closed pipes and staged manual install/update/rendering. [Qualification](Documentation/Engineering/OS27CLI/README.md) records exact executed commands and platform limits. Later codec milestones must add real stream/format/overwrite/cancellation tests before advertising those operations.
