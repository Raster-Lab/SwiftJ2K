enum ProbeError: Error { case outOfBounds, mismatch }
enum ProbeByteOrder { case little, big }

func load16(_ bytes: borrowing RawSpan, offset: Int, order: ProbeByteOrder) throws -> UInt16 {
    guard offset >= 0, offset <= bytes.byteCount,
          bytes.byteCount - offset >= MemoryLayout<UInt16>.size else { throw ProbeError.outOfBounds }
    let native = bytes.load(fromByteOffset: offset, as: UInt16.self)
    return order == .little ? UInt16(littleEndian: native) : UInt16(bigEndian: native)
}

func store16(_ bytes: inout MutableRawSpan, value: UInt16, offset: Int, order: ProbeByteOrder) throws {
    guard offset >= 0, offset <= bytes.byteCount,
          bytes.byteCount - offset >= MemoryLayout<UInt16>.size else { throw ProbeError.outOfBounds }
    let stored = order == .little ? value.littleEndian : value.bigEndian
    bytes.storeBytes(of: stored, toByteOffset: offset, as: UInt16.self)
}

@main struct F01Portable {
    static func main() throws {
        var bytes: [UInt8] = [0xaa, 0x34, 0x12, 0xcc, 0x80, 0x00, 0xdd]
        try bytes.withUnsafeBytes { buffer in
            let span = unsafe RawSpan(_unsafeBytes: buffer)
            guard try load16(span, offset: 1, order: .little) == 0x1234,
                  try load16(span, offset: 1, order: .big) == 0x3412 else { throw ProbeError.mismatch }
            let signed = span.load(fromByteOffset: 4, as: Int16.self)
            guard Int16(bigEndian: signed) == .min else { throw ProbeError.mismatch }
            for offset in [-1, 6, 7, Int.max] {
                do { _ = try load16(span, offset: offset, order: .little); throw ProbeError.mismatch }
                catch ProbeError.outOfBounds { }
            }
        }
        try bytes.withUnsafeMutableBytes { buffer in
            var span = unsafe MutableRawSpan(_unsafeBytes: buffer)
            try store16(&span, value: 0xabcd, offset: 1, order: .big)
            try store16(&span, value: .max, offset: 4, order: .little)
            for offset in [-1, 6, 7, Int.max] {
                do { try store16(&span, value: 1, offset: offset, order: .little); throw ProbeError.mismatch }
                catch ProbeError.outOfBounds { }
            }
        }
        guard bytes == [0xaa, 0xab, 0xcd, 0xcc, 0xff, 0xff, 0xdd] else { throw ProbeError.mismatch }
        for count in 0...1 {
            let truncated = Array(bytes.prefix(count))
            try truncated.withUnsafeBytes { buffer in
                let span = unsafe RawSpan(_unsafeBytes: buffer)
                do { _ = try load16(span, offset: 0, order: .little); throw ProbeError.mismatch }
                catch ProbeError.outOfBounds { }
            }
        }
        print("F01 portable passed: unaligned load/store, endian conversion, signed minimum, bounded truncation/offset rejection, preserved sentinels")
    }
}
