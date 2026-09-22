# Milestone 3 — shared-storage proof for the scalar lossless path

Executed 22 September 2026 on the owner's assignment, on branch `milestone3/shared-storage-proof` from `9c1ae00a5b864c77c93aa09318b866b6dde5bf10` (the Milestone 2 merge). Contract 0.9.0; the seven shared documents are unchanged. This record separates what was measured from what remains open. It is not a release qualification.

## Claim

For the scalar lossless JPEG 2000 path added in Milestone 2, `Decoder.decode(_:into:)` writes final samples only into the caller's allocation, `Encoder.encode` reads the caller's sealed allocation directly, and neither makes a pixel allocation or a hand-off copy under either copy policy (MEM-10, API-08). The allocating `Decoder.decode(_:)` uses the same final-output path with exactly one pixel allocation. Algorithm workspace is one `Int32` coefficient plane, released before the operation returns.

## Evidence bar (MEMORY_CONTRACT MEM-13, TESTING TEST-09)

MEM-13 requires matching allocation identities, observed reads/writes in that allocation, allocation and copy instrumentation, and sample-exact output. Each is supplied by a different mechanism:

| Requirement | Mechanism | Where |
| --- | --- | --- |
| Allocation identity | caller provider UUID compared with the published image | `SharedStorageTests`, harness |
| Observed writes and reads in the caller allocation | sentinel-filled caller providers (`0xA5` in every byte) count mutable and read borrows; prefix and row padding must still hold the sentinel afterwards | `SharedStorageTests`, harness |
| Allocation instrumentation | `StorageTelemetry`, a task-local recorder that counts every `OwnedImageStorage` and codec workspace allocation the module makes; reports are asserted against it | `Sources/SwiftJ2K/Telemetry.swift`, `SharedStorageTests` |
| Allocator telemetry in an ordinary build | `malloc_zone_statistics` live-heap deltas around decode and encode, single-threaded, non-sanitized | contract harness |
| Sample-exact output | generated PGM samples of the Milestone 2 fixtures | both |
| Load-bearing checks (mutation) | task-local `SharedPathMutation` makes the path ignore the row stride or use the wrong byte order; the failing expectations are counted | `SharedStorageTests` |
| Code-path inspection | the final-output stage is `ScalarLosslessCodec.decode`'s `destination.write` closure and the input stage is the `image.storage.withUnsafeBytes` loop in `encode`; no other code touches sample bytes | `Sources/SwiftJ2K/Codec/LosslessPipeline.swift` |

## Executed local validation

Host: Apple M5, macOS 26.5.1, Xcode 26.2 (17C52), Apple Swift 6.2.3, Swift 6 language mode, native build engine. Sanitizer and Swift Build engine gates remain unexecutable on this host for the reasons recorded in [MILESTONE2.md](MILESTONE2.md); the harness allocator figures were therefore taken in an ordinary build, as MEM-13 requires.

| Gate | Result |
| --- | --- |
| Debug tests | 77 declarations, 0 failures, 0 skipped |
| Release tests | 77 declarations, 0 failures, 0 skipped |
| Independent consumer | passed |
| Five repetitions of eight lifetime, cancellation and shared-storage tests | 40 of 40 passed |
| CLI conformance | 109 checks passed |
| Contract harness (`swift run --package-path Integration/ContractHarness`) | 3 synthetic and 3 codestream cases passed; log in [Engineering/Milestone3/Evidence](Engineering/Milestone3/Evidence) |

### Package tests (`Tests/SwiftJ2KTests/SharedStorageTests.swift`)

- **Decode into caller storage** for OpenJPEG and Kakadu fixtures at 129×67 (12-bit, 6-byte prefix, 10-byte row padding), 17×9 (16-bit, 2/4) and 129×67 packed: one write borrow, allocation UUID preserved, zero pixel allocations and bytes recorded, exactly one workspace allocation of `width × height × 4` bytes, no copy events, every sample exact, every prefix and padding byte still the sentinel, second writer refused.
- **Allocating decode** records exactly one pixel allocation of the final frame size and one workspace allocation.
- **Round trip with different strides on each side**: decode into a padded owner, encode from it with one read borrow and no pixel allocation, the codestream equals the codestream of a packed copy of the same samples byte for byte, and the result decodes into a second owner with a different prefix and padding with sentinels intact.
- **Both copy policies** take the same path and report no copy.
- **Mutation testing**: unmutated path fails 0 checks; ignoring the row stride fails 3 of 3 (padding disturbed, samples wrong, encoder reads padding and rejects it); wrong byte order fails 2 of 3 (padding untouched by design, samples wrong, encoder rejects out-of-range samples).
- **Ownership rules**: a precision mismatch is refused in preflight with no write borrow and the destination reusable; cancellation after admission throws `CancellationError` and invalidates the destination (since Milestone 4 the single write borrow spans the whole decode, so it has begun; nothing is published); a cancelled encode publishes nothing and leaves the source encodable; six concurrent encodes from one caller owner agree byte for byte while a writer request on the sealed owner fails.

### Contract harness (`Integration/ContractHarness`)

Three fixtures decoded straight into a harness-owned sentinel allocation, viewed through the SwiftJLS adapter, re-encoded from the same owner by SwiftJ2K and decoded by `opj_decompress` and `kdu_expand`:

| Case | Live heap after decode | Live heap after encode | Re-encoded bytes | Oracles |
| --- | --- | --- | --- | --- |
| 129×67, 12-bit, prefix 6, padding 10 | +24,416 B (owner 24,362 B) | +31,712 B | 3,570 | OpenJPEG and Kakadu exact |
| 17×9, 16-bit, prefix 2, padding 4 | +1,168 B (owner 344 B) | +1,776 B | 110 | exact |
| 256×256, 16-bit, packed | +131,856 B (owner 131,072 B) | +197,888 B | 64,328 | exact |

The decode delta is the harness's own owner allocation plus under a kilobyte; the 262,144-byte coefficient plane of the 256×256 case is released before `decode` returns. The encode delta includes the returned codestream `Data`. Open file descriptors are unchanged across the library calls. Each case records one owner allocation, one write borrow and one encoder read borrow.

## The JPEG-LS leg (TEST-02 steps 4–5)

SwiftJLS advertises `canEncode == false` (Milestone 1 only), so the JPEG-LS encode of the shared owner cannot execute. The harness constructs the `SwiftJLS.Image` over the same owner, confirms the identity, attempts the encode and records the `unsupportedFeature` rejection as **unexecuted coverage**, not as a pass. IMPLEMENTATION.md's Milestone 3 exit evidence admits "first suite pair or corresponding codec extension"; the corresponding codec extension, SwiftJ2K re-encoding from the same sealed owner with both reference decoders confirming the output, is what passes here. The cross-codec proof of SUITE_POLICY's "first end-to-end proof" completes when SwiftJLS ships its scalar encoder; the harness needs no change for that beyond removing the expectation of rejection.

## Open and unexecuted gates

- Contract 0.9.0's continuous-integration precondition remains unmet (every Actions job still `steps=0`).
- Sanitizer runs, the Swift Build engine, Swift 6.4, Linux, macOS x86_64, devices, SBOM, PERF-02 benchmarks and the one-hour fuzz campaign: unexecuted, as in Milestone 2.
- File-access monitoring is limited to the open-descriptor count in the harness; no `fs_usage`-style trace was captured.
- `allowCopy` has no conversion to report because the codec's native sample order is the shared layout; the reporting path for a real conversion is untested until a layout that needs one exists.
- Native transcoding, HTJ2K and every non-profile feature remain at Milestone 1 capability.
