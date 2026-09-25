# Milestone 6 — HTJ2K

Started 25 September 2026 on the owner's assignment ("merge PR 18 and start Milestone 6"), on branch `milestone6/htj2k` from `be4e7a3ad352759e7a78a90f6a2e2c3b7aa0f748` (the merge of pull request 18). Contract **0.10.0**; pinned predecessor Raster-Lab/J2KSwift `7acc9ae415e7d0bc7d441e0f0277d5e150bd19ca`. Scope from IMPLEMENTATION.md's programme: Part 15 block coder (MEL, VLC, MagSgn, cleanup), CAP/CPF/COD HT signalling, HT decode and encode for the current greyscale lossless profile (HT Rev Only first, then HT Only and mixed), and lossless J2K ↔ HTJ2K transcoding in memory and through `swiftj2k-cli transcode` per TRANSCODING.md and POL-09. Oracles: OpenJPH 0.30.1 (BSD-2-Clause, Part 15 reference), Kakadu 8.4.1 (`Cmodes=HT`), OpenJPEG 2.5.4 (Part 15 decode). This record separates what was executed from what remains open.

## Predecessor audit

Read at the pinned revision with `git show 7acc9ae4…:<path>` (the local J2KSwift working tree is not the pinned state). Executed 25 September 2026.

**Two HT implementations coexist in the predecessor; only one is Part 15.**

- The standard path is the `J2KHTConformant*` family in `Sources/J2KCodec`: `Tables` (the VLC source tables and 1024-entry lookups), `MELCoder`, `VLCCoder`, `MagSgnCoder`, `BitStream` (forward and reverse writers), `BlockLayout` (MagSgn ‖ MEL ‖ reversed VLC, Scup in the last 12 bits, Lcup/Scup split), `BlockEncoder` (its header states it is a port of OpenJPH's `ojph_encode_codeblock32`; pure-Swift loop `encodeLoopGeneric`), `BlockDecoder` (state machine with UVLC decoding, quad rows and sample reconstruction, a scalar twin of the SIMD path) and `Dispatch`. It implements the **cleanup pass only**: no HT SigProp or MagRef refinement passes, no multiple HT sets, no placeholder passes. The encoder always writes one pass and `zeroBitPlanes = K_max − 1`.
- `J2KHTBlockCoder.swift` (3,021 lines) and `J2KHTCodec.swift` are a **custom, non-Part-15 format** (a 6-byte per-block length header, a 2-bit significance-pattern VLC that is not the standard's, its own refinement framing). `J2KEncodingPresets.HTBlockFormat` defaults to `.conformant` and documents that `.custom` "is NOT decodable by OpenJPH". Under IMPLEMENTATION.md's rule this is legacy experimental material and does not migrate.
- The NEON C kernels (`Sources/J2KCodecNEON`) and the Metal HT stages are routed to by default but the Swift paths are self-contained once the routing branches, the Darwin-only profiling calls and the legacy-type extensions are removed.

**Signalling is inconsistent and the decoder never reads it.** The encoder writes Rsiz `0x4000`, CAP with `Pcap = 0x00020000` and a constant `Ccap15 = 0x0020`, CPF, COD with code-block style `0x40`, and a private COM marker `J2KSWIFT-HT:conformant`; `J2KHTCodec` and `J2KHTConformanceAPI` each use a different CAP/CPF convention, and the conformance API's validator would warn on the pipeline's own output. The decoder skips CAP and CPF entirely, detects HT from code-block style bit 6 only, ignores bit 7, misreads Scod bits 3–4 as a made-up "HT set" flag with an extra byte, and chooses between the conformant and custom block decoders by a heuristic on the first block's bytes when the private COM marker is absent, so any third-party codestream is at the mercy of that guess. Packet headers use Part 1 segment rules only; a block with more than one HT pass is not rejected. Decoded magnitudes are not scaled by 2^(K_max − 1 − missingMSBs), which is only correct for the predecessor's own output.

**The recorded lossless failure was an encoder bug, diagnosed and fixed.** Four of 49 CID22 images did not round-trip through `j2k --htj2k --lossless`; the conformant encoder derived K_max from single-level subband gains, multi-level 5/3 coefficients of high-contrast content overflowed into the sign bit (`comp=1 sub=LL K_max=8 maxAbs=259`, the 8×8 reproducer `htj2k_lossless_fail_min`). OpenJPH reproduced the loss from the predecessor's output and decoded its own streams exactly in the predecessor, isolating the encoder. v10.24.1 fixed it with `htConformantReversibleGain` (LL = B+1, detail bands = B+2, +1 under RCT) used for both the QCD exponents and the per-block shift, with a regression test. The successor derives K_max from the same rule and tests the reproducer.

**The conformance documents overstate.** `PART15_HTJ2K_CONFORMANCE.md` (February 2026) claims SigProp/MagRef/bypass compliance and lossless transcoding two months before the conformant coder existed; `HTJ2K_CONFORMANCE_REPORT.md` claims "100% conformance" of the custom codec and its own Known Limitations say no interoperability with other implementations was tested. The one substantiated claim is v10.24.1's: predecessor-encoded lossless HT decodes bit-exactly in OpenJPH 0.27, Grok 20.3 and Kakadu 8.4 on five medical fixtures, one direction only. No predecessor test decodes an OpenJPH- or Kakadu-encoded codestream.

**`J2KTranscoder.swift` is not a transcoder and nothing in it migrates.** It parses no packet headers (the whole tile's bytes are handed to every block), replaces any block decode failure with zeros, right-shifts subband sizes (wrong for odd sizes), re-encodes with the custom `HTJ2KEncoder`, concatenates block payloads without packet headers and reports `metadataPreserved: true` unconditionally; its tests assert non-empty output. The CLI's other transcode cases decode to pixels and re-encode. TRANSCODING.md's Milestone 2 audit stands.

**Licence and provenance.** The conformant block coder is an acknowledged port of OpenJPH (BSD-2-Clause) inside the MIT-licensed predecessor. Adapting it therefore brings BSD-2-Clause-derived code into this repository: permitted, but it requires OpenJPH's copyright and licence text to be retained in the adapted files and THIRD_PARTY_NOTICES.md's statement that the shipped products contain no third-party source to be amended. **This is an owner decision recorded as open below**; the alternative is an independent implementation of the Part 15 block coder from the standard.

**What migrates, what is written new.**

| Adapted with provenance (subject to the licence decision) | Written new against ISO/IEC 15444-15 and Part 1 |
| --- | --- |
| VLC/UVLC tables and lookup construction; MEL, VLC and MagSgn coders; forward/reverse bit streams; block layout (Lcup/Scup); cleanup-pass encoder loop and decoder state machine; the K_max rule of v10.24.1 | CAP (Pcap, Ccap15 with the reversible and MAGB fields) and CPF parsing and writing; code-block style bits 6 and 7 (HT, HT mixed); HT packet-header segment rules and pass accounting; magnitude scaling by 2^(K_max − 1 − missingMSBs); rejection of unsupported HT pass structures (SigProp/MagRef, multiple HT sets) with `unsupportedFeature` until implemented; the J2K ↔ HTJ2K coefficient transcoder over this repository's tier-2 and block decoders; CLI `transcode`; every test |

**Oracle triangle established before writing code.** `Scripts/generate-htj2k-fixtures.py` encodes the ten synthetic images with OpenJPH 0.30.1 (`-reversible true`, HT only) and Kakadu 8.4.1 (`Cmodes=HT`) in twelve variants and decodes every codestream with `ojph_expand`, `kdu_expand` and `opj_decompress`: 120 codestreams under `Tests/SwiftJ2KTests/Fixtures/HTJ2K`, 90 sample-exact in all three decoders. The other 30 are Kakadu-only by construction and are recorded as such in `manifest.json`: three-layer HT streams carry code-blocks with seven passes (several HT sets), which OpenJPH refuses ("supports 1 quality layer only") and OpenJPEG refuses ("more than 3 coding passes in an HT codeblock"); `Cmodes=HT|HTMIX` streams are read by Kakadu alone. Two tool findings: OpenJPH 0.30.1 with `-num_decomps 0` encodes 16-bit samples of value 0 as 32768 on five of the ten images (all three decoders agree with each other and disagree with the source), so that variant is excluded; and Kakadu accepts `BYPASS`, `CAUSAL` and `RESTART` alongside `HT` but emits identical bytes, so those flags have no HT-only fixture.

## Scope delivered

PENDING_SCOPE

## Executed validation

PENDING_VALIDATION

## Findings

PENDING_FINDINGS

## Open and unexecuted gates

- Contract 0.10.0's continuous-integration precondition: recorded per run, never waived.
- **Owner decision needed: OpenJPH-derived code.** The predecessor's conformant HT block coder is a port of OpenJPH (BSD-2-Clause). Adapting it requires retaining OpenJPH's notice and amending THIRD_PARTY_NOTICES.md; the alternative is an independent implementation from the standard.
- HT refinement passes (SigProp, MagRef), several HT sets per block and the HT/legacy mixed mode: decoded as `unsupportedFeature` until implemented; fixtures exist for the Kakadu-only cases.
