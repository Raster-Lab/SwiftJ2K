# Platform and build contract

Contract **0.2.1**. The table is intended support, not a claim of completed builds.

| Environment | Minimum / architecture | Validation responsibility |
| --- | --- | --- |
| macOS | 26.0; Apple arm64 primary | Full core, CLI, unit/regression, memory, performance and acceleration tests |
| macOS | 26.0; Intel x86_64 secondary | Native build/run and core/CLI correctness; isolated Intel support |
| iOS and iPadOS | 26.0; supported Apple devices and simulators | Library build, simulator tests and representative device tests |
| tvOS | 26.0; supported Apple devices and simulators | Library build and applicable runtime tests |
| visionOS | 26.0; supported Apple devices and simulators | Library build and applicable runtime tests |
| watchOS | 26.0; SDK-supported Watch architectures and simulators | Library build, bounded-memory runtime profile, cancellation/resource tests |
| Linux ARM64 | Ubuntu 24.04 reference distribution; AArch64 | Native build/run, scalar core, CLI and regression; optional ARM optimisation |
| Linux x86_64 | Ubuntu 24.04 reference distribution | Native build/run, scalar core, CLI and regression; isolated Intel optimisation |

**PLAT-01.** Minimum tools/compiler Swift 6.2, Swift 6 language mode and complete concurrency checking throughout library, CLI and test targets. Keep a Swift 6.2 build to enforce the minimum even when CI also uses a newer stable toolchain. Pin SDK/toolchain/container revisions in evidence. Use an Xcode supporting OS 26 SDKs. iPadOS uses the iOS SwiftPM deployment setting. Linux has its own distribution/runtime baseline; it has no Apple-style OS 26 floor. Ubuntu 24.04 is this foundation's concrete engineering baseline; wider distribution support needs evidence and a recorded expansion.

**PLAT-02.** The Apple deployment minimum is exactly 26.0 unless an approved contract change raises it. An SDK update alone must not raise package minima. Do not assume watchOS shares every framework or architecture of macOS/iOS. Probe API availability per target. No 32-bit Intel or general Linux ARMv7 support is implied. Windows is outside the current scope.

## Compile-time segregation

**PLAT-03.** Separate common scalar algorithms from Apple framework integration, Linux integration, ARM-specific kernels and x86-specific kernels. Share OS-independent SIMD primitives where they genuinely apply to both operating systems. Keep macOS Intel and Linux Intel glue separately removable. Common scalar code remains available on Apple Silicon and must not be misclassified as legacy Intel code.

Use Swift target-platform and architecture compilation conditions and target/dependency selection to omit unavailable implementations, imports, native objects and resources. A folder name alone does not exclude code. A manifest is evaluated on the build host; do not use host OS/CPU detection to decide the target architecture during cross-compilation. Centralise selection and test target configurations. Match equivalent conditions at C/C++ boundaries if retained. Never select a backend using the machine's branding alone.

**PLAT-04.** An Apple arm64 product contains no Linux-only or x86-only implementation; Linux products contain no Apple-framework link requirements. A universal macOS artifact may intentionally contain separate arm64 and x86_64 slices. Validate each slice rather than calling the whole universal file ARM-only. Runtime capability dispatch is appropriate only among backends compiled for that target. Optional GPU/SIMD unavailability must not remove codec correctness.

**PLAT-05.** Ship a usable scalar path on every claimed environment. Apple Accelerate/Metal/Core Video adapters are optional and availability-guarded. Do not fall back to OS JPEG decoding on Apple while leaving the advertised Linux native decoder missing. Optional C/C++ kernels remain small, audited and compared with the scalar reference; no external codec runtime is permitted.

## Build and packaging acceptance

Milestone 1 creates the package and CI. The package declares the exact deployment floors and Swift 6 language mode without unsafe manifest flags. Platform qualification is recorded separately from the intended matrix above; a workflow file is not evidence that its jobs ran.

When implemented, validate a fresh URL-based consumer of each library, using a versioned prerelease when dependency resolution requires one. It must not discover sibling checkouts or require another suite package. Do not require manifest unsafe flags that make the package unusable as a dependency. Keep examples, benchmarks and CLI entry points out of library test linkage where they can hijack a test executable's main function.

For every target, retain exact build/test invocations, SDK version, target triple, host/device and outcome. Cross-compilation proves buildability, not runtime correctness. Rosetta/emulation is supplemental evidence, not a substitute for native Intel/Linux ARM runtime gates. If a required runner/device is unavailable, mark that gate unexecuted and do not publish support as verified. Do not silently reduce scope to the agent's local machine.

Initial CI should run complete core correctness on macOS arm64 and both Linux architectures, plus an Apple SDK build matrix. Add native macOS Intel and representative Apple runtime checks before the stable release claims those targets. Resource-limited Watch tests use their explicit profile; they must not be disabled merely to make the matrix green.

References: [Swift Linux toolchains](https://www.swift.org/install/linux/ubuntu/24_04/), [Xcode SDK compatibility](https://developer.apple.com/xcode/system-requirements), [Swift compilation conditions](https://github.com/swiftlang/swift-book/blob/main/TSPL.docc/ReferenceManual/Statements.md#conditional-compilation-block).
