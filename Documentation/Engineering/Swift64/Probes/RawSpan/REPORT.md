# Swift 6.4 F01/F02 availability and adoption evidence

Executed 19 September 2026. Read the supplied distribution README, common manifesto v1.0.0 and suite supplement v1.0.0 in that order. The current successor contract was 0.2.1 when this task started; parent advances the compiler contract separately. Scope is the four successors, as confirmed by the owner to the parent agent.

## Pinned environment

- Xcode 27.0, build 27A266a; Apple Swift 6.4, swiftlang-6.4.0.34.1, clang-2100.3.34.1; driver 1.168.6.
- Host: arm64, macOS 27.0 build 26A428. SDK: MacOSX27.0.sdk.
- Commands use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, Swift 6 language mode and local module/build caches. See each JSON argv/command entry and corresponding log for exact commands and exit status.
- Compiling for `arm64-apple-macosx26.0` is minimum-target compilation evidence. Executables ran on macOS 27, not macOS 26. Actual macOS 26, native Intel and Linux runtime execution remain open.

## Installed declarations and availability

These are from the installed SDK's `Swift.swiftmodule/arm64e-apple-macos.swiftinterface`, not inferred from proposal examples. Exact excerpts and original line numbers are in `selected-declarations.txt`.

F01 declarations in the implicit `Swift` standard-library module:

```swift
RawSpan.load<T>(fromByteOffset: Int, as: T.Type) -> T
    where T: ConvertibleFromBytes
MutableRawSpan.storeBytes<T>(of: T, toByteOffset: Int, as: T.Type)
    where T: BitwiseCopyable, T: ConvertibleToBytes
OutputRawSpan.append<T>(_: T, as: T.Type)
    where T: BitwiseCopyable, T: ConvertibleToBytes
```

The load/append/store implementations emit into the client. Their containing span types/extensions carry macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2 and visionOS 1.0 availability in this SDK. This is declaration evidence, not a qualification claim for those older deployment platforms. The task preserves the suite's OS 26 minima.

`Swift.ByteOrder` and the extra byte-order-argument load/store/append overloads carry `@available(anyAppleOS 27.0, *)`. `F01ByteOrder.swift` correctly fails compilation when targeted at macOS 26 and succeeds for macOS 27. The adopted code uses native-order load/append plus `UInt16(littleEndian:)` / `UInt16(bigEndian:)` and `.littleEndian` / `.bigEndian`, so no OS-27 branch or floor increase is needed.

The bridge to existing provider closures is explicit: `RawSpan(_unsafeBytes:)`, `OutputRawSpan(buffer:initializedCount:)`, and consuming `OutputRawSpan.finalize(for:)` are unsafe bridges to the existing owning-provider lifetime. They remain inside synchronous retained-owner/exclusive-lease closures. The safe load/append operation still has bounds preconditions; existing validated descriptors and provider-capacity checks prove its extent before access.

F02 declarations:

```swift
withTemporaryAllocation<T, R, E>(of: T.Type, capacity: Int,
    _ body: (inout OutputSpan<T>) throws(E) -> R) throws(E) -> R
    where E: Error, T: ~Copyable, R: ~Copyable
withTemporaryAllocation<R, E>(byteCount: Int, alignment: Int,
    _ body: (inout OutputRawSpan) throws(E) -> R) throws(E) -> R
    where E: Error, R: ~Copyable
```

Both carry the same older Apple availability annotation and `@_alwaysEmitIntoClient @_transparent`. Their implementations wrap `withUnsafeTemporaryAllocation`, track initialised elements and clean up in `defer`. Client linking required no explicit new runtime library: macOS26 target info reports `compatibilityLibraries: []`; verbose link commands and `otool -L` results are retained. That evidence covers the tested probe instantiations only.

## Probe results

| Probe | Target/configuration | Outcome |
| --- | --- | --- |
| F01Portable | arm64 macOS26/27, debug | Compile and run passed |
| F01Portable | arm64 macOS26, optimised | Compile and run passed |
| F01Portable | macOS26 strict-memory-safety + warnings-as-errors | Typecheck passed |
| F01Portable | x86_64 macOS26 | Typecheck passed; no native Intel run |
| F01ByteOrder | arm64 macOS26 | Expected availability rejection, compile exit 1 |
| F01ByteOrder | arm64 macOS27 | Compile and run passed |
| F01Output | arm64 macOS26, debug and optimised | Compile and run passed |
| F02Temporary | arm64 macOS26/27, debug; macOS26 optimised | Compile and run passed |
| F02Temporary | macOS26 strict-memory-safety + warnings-as-errors | Typecheck passed |
| F02Temporary | x86_64 macOS26 | Typecheck passed; no native Intel run |

`F01Portable.swift` checks unaligned access, both byte orders, signed Int16 minimum, truncation, negative/huge/out-of-range offsets and sentinel preservation. Its MutableRawSpan source is deliberately already initialised; that writer is probe-only.

`F01Output.swift` instead writes an initially uninitialised two-byte sample at an odd physical address, comparing independently specified bytes and adjacent sentinels. This matches the production provider-initialisation contract.

`F02Temporary.swift` verifies bounded/empty typed scratch, raw scratch, summation, and three exactly-once element destructions: two after throwing during partial initialisation and one after normal exit. No temporary pointer escapes or suspension occurs. It does not prove stack placement, zero allocation or performance.

## Final production change and regression results

All four `Sources/<Module>/Image.swift` files now use safe RawSpan load for `sampleUInt16` and a per-sample OutputRawSpan initialisation for `writeUInt16`. The two-byte output span wraps supplied storage; it creates no new sample buffer. Public names/signatures, sample meaning, endian behaviour, padding, ownership, lease state and cancellation remain unchanged. Every file has SHA-256 `a5f050b9334d533cd4f0d01b73bb7e465b9e50718abf7c07eb80dc0109e97e0e` at handover.

Whole-buffer MutableRawSpan storage was rejected during review: its initialisation invariant would strengthen obligations on external writable providers, which currently need to initialise published bytes only before sealing. OutputRawSpan with initialised count zero preserves that contract. F02 is deferred for production: current Milestone 1 has no bounded predictor/transform/entropy scratch to improve; it must not replace the owning final image allocation.

The new `Swift64SampleAccessTests` passed all six cases in each successor with explicit Swift Build (`--build-system swiftbuild`), separate scratch/cache directories and the installed Xcode toolchain: 24 total passes, zero failures/skips in these final focused runs. Coverage: independent endian golden fixtures, odd physical read/write addresses, initially uninitialised provider samples, unchanged padding, packed/padded 12/16-bit values/extrema, allocation identity, short provider refusal, coordinate overflow avoidance and invalidation after overprecision input. `focused-tests/results.json` and per-repository logs retain exact commands/results. Full suite, sanitizers, platform matrix and benchmarks are parent responsibilities.

Two test-authoring compilation failures were corrected without suppression: a complex array-concatenation expression exceeded type-checking time (split into explicit appends); passing a callback directly to a Mutex API violated its sending-result closure constraints (use the existing scoped invocation pattern). Initial logs remain in `focused-tests/initial-typecheck/` and `focused-tests/initial-provider-typecheck/`. `before-output-span/` records an intermediate passing five-test implementation; it is not final candidate evidence. Final `git diff --check` passed in all four repositories.

## Primary references

Safe byte conversions and temporary allocation are implemented Swift 6.4 features. The installed SDK controls the availability conclusions above. See [SE-0525](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0525-rawspan-safe-loading-api.md) and [SE-0524](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0524-span-temporary-allocation.md).

Apple documents the distinction between initialized mutable spans and output spans that track an initialized prefix; that distinction motivated the final provider-compatible writer. See [Swift safe memory access types](https://developer.apple.com/documentation/swift/mutablespan).
