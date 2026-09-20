# Swift 6.4 feature dispositions at the OS 27 baseline

Contract 0.4.0 records the owner's explicit deployment change. The [earlier register](../Swift64/FEATURE_REGISTER.md) and its probes remain historical evidence for the former OS 26 decision. The current feature decisions are below; no older availability constraint is silently treated as current policy.

| Feature | Current disposition |
| --- | --- |
| F01 — bounded raw-span sample access | Adopt the OS 27 `Swift.ByteOrder` overloads of `RawSpan.load` and `OutputRawSpan.append` in all four Image.swift files. The SDK declarations explicitly require Apple OS 27. Geometry/capacity checks, two-byte initialisation regions, scoped retained-owner borrows and padding boundaries are preserved. Golden endian/odd-address/uninitialised-storage tests cover the same values and lifecycle. |
| F02 — temporary output spans | Available; still deferred until a real bounded codec scratch workspace exists. Persistent Image storage must not be replaced by temporary allocation. |
| F03 — UniqueArray/RigidArray | UniqueArray's OS requirement now fits. Shared immutable owners still need reference semantics, so no current exclusive collection is replaced. Public RigidArray and a Containers module remain absent in this SDK; use no underscored substitute. |
| F04 — UniqueBox | OS requirement now fits, but no genuinely exclusive private operation state currently needs it. Do not weaken shared Image ownership merely to adopt a type. |
| F05 — borrow/mutate accessors | Eligible; no new value-wrapper abstraction is needed in this bounded change. |
| F06 — Iterable | OS requirement now fits. No current collection of noncopyable scratch elements needs borrowing iteration. Revisit when a codec workspace is implemented. |
| F07 — Ref/MutableRef | OS requirement now fits. These projections do not replace retained providers or lease authority. Current synchronous pointer boundaries remain documented; no asynchronous owner is replaced with a nonescaping projection. |
| F08 — async defer | Eligible; current cleanup is synchronous and there are no asynchronous worker resources to drain. Add only with a real cleanup use and cancellation/lifetime proof. |
| F09 — cancellation shields | OS requirement now fits. Existing synchronous invalidation/sealing does not need a shield. Ordinary work and publication remain cancellable. |
| F10 — noncopyable Optional additions | Requested public ref/mutableRef/put/map combinations remain unavailable in this exact SDK even with OS 27, as captured in the earlier negative probes. Raising a deployment floor cannot add missing declarations. |
| F11 — test interoperability/repetition | Existing Swift Testing and fixed ownership/cancellation repetitions remain; CLI behaviour is additionally exercised as real subprocesses. No retry-until-pass policy. |
| F12 — Swift Build/SBOM | Clean/incremental debug/release, standalone consumers, both library and CLI products and their build-associated SBOMs are qualified to the recorded extent. SBOM schema/conformance limits remain explicit. |
| F13 — diagnose | Local severity elevation remains eligible; no new diagnostic suppression or unnecessary attribute is introduced. |

The actual new production feature is the endian-aware span overload; the CLI adds no runtime framework/package dependency beyond its own library and existing platform facilities. This change does not implement codecs, alter public ownership signatures, add a compatibility path for older Apple OS versions, or claim native Linux/device qualification from SDK compilation. Tests execute on macOS 27 arm64, now an actual minimum-OS runtime for that platform. Other Apple 27 targets require their own runtime evidence.
