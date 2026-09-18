enum OutputProbeError: Error { case mismatch }
@main struct F01Output {
    static func main() throws {
        let allocation = UnsafeMutableRawPointer.allocate(byteCount: 5, alignment: 2)
        defer { allocation.deallocate() }
        // Only sentinels are initialised; the odd-address sample starts uninitialised.
        let bytes = UnsafeMutableRawBufferPointer(start: allocation, count: 5)
        bytes[0] = 0xa5; bytes[3] = 0xa5; bytes[4] = 0xa5
        let sampleBytes = UnsafeMutableRawBufferPointer(rebasing: bytes[1..<3])
        var sample = unsafe OutputRawSpan(buffer: sampleBytes, initializedCount: 0)
        sample.append(UInt16(0xabcd).bigEndian, as: UInt16.self)
        let initialised = unsafe sample.finalize(for: sampleBytes)
        guard initialised == 2, Array(bytes) == [0xa5, 0xab, 0xcd, 0xa5, 0xa5] else {
            throw OutputProbeError.mismatch
        }
        print("F01 OutputRawSpan passed: uninitialised odd-address sample and preserved sentinels")
    }
}
