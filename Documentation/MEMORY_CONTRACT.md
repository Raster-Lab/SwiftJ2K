# Common image memory and ownership contract

Contract **0.1.1**. All requirements below apply independently in each codec.

## Existing memory layouts, no new image format

**MEM-01.** Use ordinary uncompressed integer/floating-point sample storage with explicit descriptors. The Swift owner and descriptor are an API abstraction, not a serialised file format. The initial shared profile is a single greyscale plane of unsigned 16-bit samples. Apple vImage views and compatible Core Video/IOSurface-backed storage are optional adapters; none is a mandatory core dependency or a substitute for the descriptor. Linux uses the same logical contract. Do not introduce an intermediate TIFF/PNG/NRRD encode/decode inside in-process transcoding.

## Image description

| Field | Contract |
| --- | --- |
| `width`, `height` | Positive pixel dimensions; checked against limits before multiplication |
| `sampleType` | Unsigned integer, signed integer or IEEE floating-point; initial shared profile is unsigned integer |
| `storageBits` | Initial profile 16; general API admits only declared supported widths, initially 8/16 integers and optional 32-bit float |
| `meaningfulBits` | Integer precision, from 1 through storageBits; signed precision includes sign bit; not guessed from observed extrema |
| `byteOrder` | Explicit little/big endian; convenience native-endian requests resolve to a concrete value in a stored descriptor |
| `components` | Ordered component roles; greyscale, RGB, alpha or explicit uninterpreted roles; no inferred colour meaning |
| `colour` | Declared colour interpretation plus optional bounded ICC bytes; unknown is explicit |
| `alpha` | Absent, straight or premultiplied; never silently switch |
| `planes` | Per-plane width/height, component mapping, base offset, sample/pixel stride and positive row stride, byte capacity |
| `metadata` | Bounded image-level metadata with preservation policy; excludes DICOM object semantics |

**MEM-02.** Meaningful integer bits are low-bit aligned in each storage word. Unused high bits are zero for unsigned samples and valid sign extension for signed samples. Padding is not sample data. Values outside declared meaningful range are rejected on encoding, not truncated. Full-precision unsigned 16-bit samples include 0 and 65535; 12-bit unsigned samples include 0 and 4095. This semantic convention uses normal integer storage and does not impose a private file representation.

**MEM-03.** Initial required shared layout: one plane, one component, two-byte sample/pixel stride, little-endian 16-bit storage, at least two-byte alignment, positive even `rowBytes >= width * 2`, no subsampling. Packed and padded rows are required. Each codec must accept this layout for advertised unsigned greyscale lossless input. Additional layouts are capabilities, not implicit assumptions. Do not treat every multi-component codec image as interleaved. Planar/subsampled extensions explicitly describe every plane's dimensions and sampling.

**MEM-04.** Calculate the last accessed byte using checked arithmetic: plane offset plus `(planeHeight - 1) * rowBytes` plus the last pixel/component offsets plus sample bytes. Validate against the retained allocation's capacity before touching memory. Check signed-to-unsigned conversions, plane overlap, stride alignment and row payload separately. Reject negative strides in this baseline. Writable planes cannot overlap. Alignment-sensitive loads must either be proven aligned or use a safe unaligned access strategy. If a backend needs stronger alignment than the shared profile, choose compatible scalar processing or fail/report an explicitly permitted copy.

## Owners and access

**MEM-05.** Every `Image` retains a `ReadOnlyImageStorage` owner and immutable descriptor. Storage exposes capacity, an opaque allocation identity based on a standard UUID, and synchronous scoped read access. It does not expose a persistently valid raw pointer to ordinary application code. The allocation identity follows the underlying allocation across adapter wrappers; a fresh allocation has a different identity. Never log raw addresses in production.

The common public construction/access vocabulary is fixed as follows. These are required names and meanings, not implementation snippets:

| Member / operation | Contract |
| --- | --- |
| `ImageDescriptor` validated construction | Throws for invalid geometry/layout/precision; descriptor fields use the names above |
| `Image(descriptor:storage:metadata:)` | Validates an immutable descriptor against sealed read-only storage; retains its owner |
| `ImageDestination(descriptor:storage:)` | Adopts an owning writable provider; validates capacity and reserves through its shared lifecycle |
| `ImageDestination.allocate(descriptor:limits:)` | Allocating convenience that creates the same kind of destination used by caller-storage decode |
| `ReadOnlyImageStorage.byteCount` | Capacity of the retained allocation, not just visible pixel payload |
| `ReadOnlyImageStorage.allocationID` | UUID forwarded identically across views/adapters of one allocation generation |
| `ReadOnlyImageStorage.withUnsafeBytes(_:)` | Synchronous throwing scoped read borrow; pointer must not escape |
| `WritableImageStorage.byteCount`, `allocationID` | Same capacity/identity rules; shared lifecycle is owned by the underlying provider |
| `WritableImageStorage` exclusive lease operations | Reserve one writer, scoped mutable access, finish-and-seal, or abort-and-invalidate; prove a lease token cannot authorise two concurrent overlapping writes |
| `Image.descriptor`, `Image.storage`, `Image.metadata` | Immutable public values/read-only owner for explicit adapter integration |

Milestone 1 must fix the concrete lease-token Swift signatures once, prove their Sendable/lifetime behaviour and mirror that refinement in all four copies before codec migration. Do not let four agents invent incompatible lease methods independently. Ordinary callers use owning destinations; advanced provider implementers are responsible for enforcing the documented lease protocol. Raw `withUnsafe...` access remains an unsafe boundary: a closure type alone does not prevent a malicious caller from returning or saving its pointer. Document the no-escape duty and prefer safe operations for ordinary callers.

**MEM-06.** `ImageDestination` retains `WritableImageStorage` and grants one exclusive write operation. Implement the lifecycle `available -> writing -> sealed` on success, or `available -> writing -> invalid` on failure/cancellation. A sealed image is immutable. A second writer is rejected. A destination cannot be published as an `Image` until every output sample is initialised and all worker/GPU writes finish. Validate descriptor compatibility before entering the writing state where possible. An invalid destination has no readable image view.

**MEM-07.** The owner/provider enforces the lifecycle across all wrappers, including those from different modules. A caller adopting externally managed memory must supply an owner that actually retains the allocation and enforces exclusive access; retaining an unrelated token is insufficient. The advanced unsafe adoption API must state the caller's duties, reject unsupported lifecycle integration and remain separate from safe owning constructors. Never allow stack memory, escaped array-buffer pointers or a temporary `Data.withUnsafeBytes` pointer to become an asynchronous owner.

**MEM-08.** Pointer borrows are synchronous, nonescaping and cannot span `await`. Async operations retain owning storage and borrow only inside synchronous work units. An internal parallel implementation may issue disjoint region leases after proving bounds and non-overlap. Any unavoidable unchecked Sendable bridge must be narrow, documented with its lifetime/exclusivity proof and exercised by race/lifetime tests. Do not mark the entire buffer implementation unchecked simply to silence Swift 6 errors.

After sealing, multiple readers may share storage; none may mutate it. Destruction releases the allocation exactly once after the last lease and in-flight operation ends. Reference-counted ownership is acceptable. Copy-on-write is permitted only when a requested mutation actually creates a new allocation and the copy is reported; it cannot be used to claim an operation met `requireSharedStorage` after a hidden clone.

**MEM-09.** Pool reuse is optional and bounded. It requires the last published reader to release its lease, completed hardware work, state reset and a new generation/identity before another image is written. Stale views never access reused storage. Do not promise secure erasure unless implemented and tested; do prevent uninitialised bytes or previous-frame padding from being exposed in serialised output. Encode must skip padding; public byte-export APIs must initialise or redact it.

## Decoding into and encoding from shared storage

**MEM-10.** Decoder inspection describes a supported output layout and precision; callers may request the initial shared layout. The allocating decode convenience and caller-destination decode use the same final-output path. Destination decode writes final reconstructed samples directly to the provided plane(s). It may use algorithm workspace, but must not decode to a second full final image and copy that image into the destination as a hidden implementation shortcut.

The encoder reads the supplied compatible `Image` directly, after decode has sealed it. For JPEG-LS, reading samples into bounded predictor/line workspace is acceptable; materialising the full frame as `[[Int]]` merely to enter the old encoder is a hand-off copy and fails the first end-to-end proof in Milestone 3.

**MEM-11.** For a future umbrella, one storage owner sits above the codecs. Local adapter objects implement each module's local storage protocol around that same owner. Descriptor values are mapped explicitly. Shared allocation identity, capacity and lifecycle are forwarded unchanged. The adapter retains the owner for the whole operation; it does not reconstruct the pixels. The first test harness may perform this role without introducing a production umbrella dependency.

## Copy policy and measurement

| Memory use | Permitted under `requireSharedStorage`? |
| --- | --- |
| Compressed input/output storage | Yes; report separately from decoded pixels |
| One final decoded allocation supplied by the caller | Yes |
| Small descriptor/owner wrappers | Yes |
| Bounded line/tile/predictor/entropy workspace needed by the algorithm | Yes, subject to resource limits and accounting |
| Whole-frame coefficient workspace inherently required by the selected algorithm | Only if justified, budgeted and explicitly reported as workspace |
| Extra full decoded frame for repacking, byte swapping or a legacy API hand-off | No |
| Temporary image file or implicit memory-mapped image staging | No |

**MEM-12.** `allowCopy` permits only value-preserving memory conversions needed for a supported layout. Report every conversion with a reason, source/destination layout, bytes moved and allocation count; conversion byte counts include streamed row-by-row copies. The report includes peak owned pixel bytes and algorithm workspace where measurable. Unknown measurements are marked unknown, never zero. A relabelled final image is not algorithm workspace. The default path must not change from shared to copied because acceleration is preferred; use a compatible backend or return a clear incompatibility.

**MEM-13.** A shared-storage assertion requires all of: matching allocation identities, observed reads/writes in that allocation, allocation/copy instrumentation proving no intermediate full final frame, and sample-exact output. Address equality alone is insufficient. Inspect the code path as well as allocator telemetry. Test incompatible strides/alignment and failure paths, not only packed happy-path data.

## Medical-style precision and portability

No windowing, VOI LUT, modality rescale, colour display conversion or automatic normalisation occurs in this contract. Preserve meaningful bit depth when the source explicitly declares it. Do not infer 12 bits just because a 16-bit image's values happen to fit 12 bits. A destination that cannot represent required precision or interpretation must reject or require an explicit, durable external metadata contract.

The first end-to-end proof in Milestone 3 is unsigned. Signed JPEG-LS/JPEG XL mappings need explicit external interpretation where the codestream cannot record signedness; prove both encode and decode mapping without overflow, especially -32768. Those mappings are not part of the first shared-storage claim. CVPixelBuffer format codes, vImage geometry or raw byte arrays alone do not carry the complete descriptor. Do not use Float16 as a substitute for exact UInt16 samples.

## Failure and limits

Validate resource limits before allocation and re-check on frame/layout changes. Join every worker before completing error cleanup. Failed decodes invalidate their destination; failed encodes publish no successful result. No automatic file spill. Admission failure returns `resourceLimitExceeded`; allocation failure returns a defined error where the allocator permits recovery. Resource limits reduce allocation-failure risk but cannot guarantee recovery from process-level OS termination.
