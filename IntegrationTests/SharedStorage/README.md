# Two-module shared-storage feasibility fixture

This separate development-only package exercises the public SwiftJ2K and SwiftJLS memory contracts together. It supplies real owned synthetic sample storage and explicit adapters between the two modules' distinct protocol, descriptor and error types. It implements no image codec, real transcoder or shipping umbrella.

The package depends on its own SwiftJ2K checkout at `../..` and on SwiftJLS from GitHub at revision `d394e4eff3b85d9da9f2f3a6af09a898ffe7d57d`. Neither library's product or root package depends on this fixture or on the other library. Dependency resolution fetches the pinned development dependency; test execution does not fetch codecs or use external executable fallbacks.

From the SwiftJ2K repository root, with Swift 6.2 installed:

```sh
swift test --package-path IntegrationTests/SharedStorage -j 2
swift test --package-path IntegrationTests/SharedStorage -c release -j 2
```

On a supported native sanitizer host, run separately:

```sh
swift test --package-path IntegrationTests/SharedStorage --scratch-path IntegrationTests/SharedStorage/.build/asan -j 2 --sanitize address
swift test --package-path IntegrationTests/SharedStorage --scratch-path IntegrationTests/SharedStorage/.build/tsan -j 2 --sanitize thread
```

## What the fixture exercises

- A single `SwiftJ2K.OwnedImageStorage` allocation, retained through observed provider/lease/read wrappers and through explicit SwiftJLS adapters.
- Exact unsigned twelve-meaningful-bit and full sixteen-bit samples in little-endian sixteen-bit storage; five columns, three rows, twelve-byte row stride and two-byte initial offset. Both modules see the same allocation UUID and thirty-eight-byte retained capacity.
- Synthetic J2K writes followed by JLS reads, and synthetic JLS writes through an adapted lease followed by J2K reads. Checked sample views preserve precision and skip sentinel padding.
- Writer exclusion with either module reserving first, read-before-seal rejection, terminal abort, callback failure, dropped lease and cancellation. Standard `CancellationError` crosses the adapter unchanged; every stable codec error category maps explicitly.
- Caller release before asynchronous reads, sixteen bounded concurrent immutable readers across both modules, and one observed allocation-owner release after the final published views are released.

All pointer borrows remain synchronous within the actual provider's callback. The adapters forward owned references; they do not keep pointers, convert pixels to arrays or create another decoded allocation. The provider's own lifecycle remains authoritative. The fixture adds no `unsafeBitCast`, unchecked concurrency conformance or independent lock that could mistakenly authorise a second writer.

## Synthetic fixture provenance

The literal reference samples are in `Tests/SharedStorageTests/SharedStorageTests.swift`, in `expectedSamples(meaningfulBits:)`. They are newly authored synthetic MIT-licensed fixtures, with no patient data or third-party material. The expected values include zero, the declared maximum, nonzero textured values and an independent physical little-endian check. For the retained-image test, all allocation bytes are initially set to `0xa5`, then the fifteen samples are written at their declared offsets; prefix and row padding retain the sentinel.

The logical digest below covers the fifteen reference samples in row order as two-byte little-endian words, without padding. The storage digest covers the expected thirty-eight-byte allocation including prefix and padding. These reference digests were computed from the literal vectors with Python's standard-library SHA-256; they are fixture metadata, not a claim that Swift tests have run.

| Meaningful bits | Logical-sample SHA-256 | Expected-storage SHA-256 |
| --- | --- | --- |
| 12 | `16fae2bd18f1c635f333bd15178fe1b942bfd0bf19250f7e267fad48c0cfa943` | `eb1991871fbd28c792614073471bfbb065b1dceaa4b6875a08fefe73635689e8` |
| 16 | `5036b5a0328dfd8ab0e5e246a01b2e92893e640a6d71d32adf435440f64158c3` | `0d5219df7bace2055ed0edd77be4210e37d573c5289fb9d8c533241a92b7068d` |

## Evidence boundaries

`Observations` counts successful fixture-owned allocation creation, actual provider read/write callback scopes and observed owner destruction. It does not measure every allocator call, process RSS, bytes moved by a real codec, or a runtime-wide copy count. Sample checks, identity checks, scope observations and inspection of the forwarding adapters together establish the intended synthetic experiment. Broader allocator instrumentation and compressed-format sample-exact transcoding remain later milestone gates.

No runtime image file or intermediate serialisation is used. This fixture does not assert that the operating system never pages memory. It does not test J2K/JPEG-LS compression, HTJ2K, independent compressed-file interoperability, codec speed or diagnostic suitability.

At preparation, a Swift compiler was unavailable locally. Compilation, test results and sanitizer/platform outcomes must be recorded by CI or a native host before claiming this fixture passes. Keep its pinned dependency revision aligned with the reviewed source and include both repository revisions, compiler, target and exact command in the validation evidence.
