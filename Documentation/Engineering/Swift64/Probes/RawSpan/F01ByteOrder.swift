@main struct F01ByteOrder {
    static func main() {
        var bytes: [UInt8] = [0, 0x34, 0x12, 0]
        bytes.withUnsafeMutableBytes { buffer in
            var span = unsafe MutableRawSpan(_unsafeBytes: buffer)
            let value = span.load(fromByteOffset: 1, as: UInt16.self, .littleEndian)
            span.storeBytes(of: value, toByteOffset: 1, as: UInt16.self, .bigEndian)
        }
        precondition(bytes == [0, 0x12, 0x34, 0])
        print("F01 explicit Swift.ByteOrder passed")
    }
}
