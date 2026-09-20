# Development-only suite adapter experiment

This separate package is not referenced by any library manifest. Place the four successor checkouts beside one another, all using the Milestone 1 branches. Run `swift run --package-path Integration/ContractHarness` from SwiftJ2K. It explicitly depends on the four checkouts for testing; individual libraries remain standalone.

The synthetic 5×3 cases use 12 or 16 meaningful bits in little-endian 16-bit words, a two-byte prefix and 14-byte rows. One owner is constructed per case. Instrumented mutable/read borrows, identical allocation UUIDs and test-only address equality accompany exact logical-sample comparisons and zero padding checks. Adapters forward the owner without copying pixels. A second writer from another module must fail; local write-lease mappings are exercised separately.

These are API/memory experiments, not compressed-image transcodes. There is no codec or shared-foundation package. The implementation retains synchronous raw borrows and never passes a pointer across `await`. Only scalar allocation/borrow counters are measured; no process-wide allocator or codec-performance claim is made.
