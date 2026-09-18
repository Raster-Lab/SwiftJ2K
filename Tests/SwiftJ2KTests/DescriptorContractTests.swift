// SPDX-License-Identifier: MIT
import Testing
import SwiftJ2K

@Suite("Unsigned greyscale descriptor contract")
struct DescriptorContractTests {
    @Test("Full precision includes 65535 and keeps sample interpretation explicit")
    func fullSixteenBitValues() throws {
        let descriptor = try ImageDescriptor.greyscale16(width: 3, height: 2, rowBytes: 8, offset: 2)
        let destination = try ImageDestination.allocate(descriptor: descriptor)
        let expected: [UInt16] = [0, 1, 65535, 32768, 0x1234, 65534]
        for y in 0..<2 {
            for x in 0..<3 { try destination.setSample(expected[y * 3 + x], x: x, y: y) }
        }
        let image = try destination.seal()
        #expect(image.descriptor.meaningfulBits == 16)
        #expect(image.descriptor.byteOrder == .littleEndian)
        #expect(image.descriptor.sampleType == .unsignedInteger)
        for y in 0..<2 {
            for x in 0..<3 { #expect(try image.sample(x: x, y: y) == expected[y * 3 + x]) }
        }
        try image.storage.withUnsafeBytes { bytes in
            // Offset and row padding are initialised, not interpreted as samples.
            #expect(bytes[0] == 0)
            #expect(bytes[1] == 0)
            #expect(bytes[8] == 0)
            #expect(bytes[9] == 0)
            #expect(bytes[14] == 0xfe)
            #expect(bytes[15] == 0xff)
        }
    }

    @Test("Twelve meaningful bits are preserved in sixteen-bit storage")
    func twelveInSixteen() throws {
        let descriptor = try ImageDescriptor.greyscale16(width: 3, height: 3, meaningfulBits: 12, rowBytes: 8)
        let destination = try ImageDestination.allocate(descriptor: descriptor)
        let expected: [UInt16] = [0, 4095, 1, 2048, 4094, 17, 1023, 255, 4095]
        for y in 0..<3 {
            for x in 0..<3 { try destination.setSample(expected[y * 3 + x], x: x, y: y) }
        }
        let image = try destination.seal()
        #expect(image.descriptor.storageBits == 16)
        #expect(image.descriptor.meaningfulBits == 12)
        for y in 0..<3 {
            for x in 0..<3 { #expect(try image.sample(x: x, y: y) == expected[y * 3 + x]) }
        }
    }

    @Test("The safe sample writer rejects values outside declared precision")
    func precisionRangeIsNotTruncated() throws {
        let descriptor = try ImageDescriptor.greyscale16(width: 1, height: 1, meaningfulBits: 12)
        let destination = try ImageDestination.allocate(descriptor: descriptor)
        #expect(throws: (any Error).self) { try destination.setSample(4096, x: 0, y: 0) }
        destination.abort()
    }

    @Test("A raw borrow cannot make out-of-range words appear as valid samples")
    func invalidHighBitsAreDetectedBySampleView() throws {
        let descriptor = try ImageDescriptor.greyscale16(width: 1, height: 1, meaningfulBits: 12)
        let destination = try ImageDestination.allocate(descriptor: descriptor)
        try destination.withUnsafeMutableBytes { bytes in
            bytes[0] = 0x00
            bytes[1] = 0x10 // 4096 exceeds the source-declared twelve-bit range.
        }
        let image = try destination.seal()
        expectCodecError(.invalidArgument) { try image.sample(x: 0, y: 0) }
    }

    @Test("Low observed extrema do not change source-declared full precision")
    func precisionIsNotInferredFromValues() throws {
        let descriptor = try ImageDescriptor.greyscale16(width: 1, height: 1)
        let destination = try ImageDestination.allocate(descriptor: descriptor)
        try destination.setSample(1, x: 0, y: 0)
        let image = try destination.seal()
        #expect(image.descriptor.meaningfulBits == 16)
        #expect(try image.sample(x: 0, y: 0) == 1)
    }

    @Test("The last sample may end at the exact retained capacity")
    func exactCapacityAndOneByteShort() throws {
        let plane = try PlaneDescriptor(width: 3, height: 2, offset: 2, rowBytes: 8, byteCount: 14)
        let descriptor = try ImageDescriptor(width: 3, height: 2, planes: [plane])
        let tooSmall = try OwnedImageStorage(byteCount: 15)
        #expect(throws: (any Error).self) { try ImageDestination(descriptor: descriptor, storage: tooSmall) }
        // Rejection precedes reservation: the caller can still reserve its owner.
        let smallLease = try tooSmall.reserveWrite()
        smallLease.abort()
        let exact = try OwnedImageStorage(byteCount: 16)
        let destination = try ImageDestination(descriptor: descriptor, storage: exact)
        try destination.setSample(65535, x: 2, y: 1)
        let image = try destination.seal()
        #expect(image.storage.byteCount == 16)
        #expect(image.storage.allocationID == exact.allocationID)
        #expect(try image.sample(x: 2, y: 1) == 65535)
    }

    @Test("Bad row strides are rejected before memory is accessed", arguments: [-8, 0, 1, 4, 5, 7])
    func invalidRowStride(_ rowBytes: Int) throws {
        #expect(throws: (any Error).self) {
            try ImageDescriptor.greyscale16(width: 3, height: 2, rowBytes: rowBytes)
        }
    }

    @Test("Invalid offsets never wrap or allow unaligned sample access", arguments: [-2, -1, 1, 3, Int.max])
    func invalidOffset(_ offset: Int) throws {
        #expect(throws: (any Error).self) {
            try ImageDescriptor.greyscale16(width: 1, height: 1, offset: offset)
        }
    }

    @Test("Invalid meaningful precision is not silently normalised", arguments: [-1, 0, 17, Int.max])
    func invalidPrecision(_ meaningfulBits: Int) throws {
        #expect(throws: (any Error).self) {
            try ImageDescriptor.greyscale16(width: 1, height: 1, meaningfulBits: meaningfulBits)
        }
    }

    @Test("Dimensions and stride arithmetic cannot overflow")
    func arithmeticBoundaries() throws {
        for width in [Int.min, -1, 0, Int.max / 2 + 1, Int.max] {
            #expect(throws: (any Error).self) {
                try ImageDescriptor.greyscale16(width: width, height: 1)
            }
        }
        #expect(throws: (any Error).self) {
            try PlaneDescriptor(width: 1, height: Int.max, rowBytes: 2, byteCount: Int.max)
        }
        #expect(throws: (any Error).self) {
            try PlaneDescriptor(width: 1, height: 2, offset: Int.max - 1, rowBytes: 2, byteCount: 4)
        }
        #expect(throws: (any Error).self) {
            try PlaneDescriptor(width: 3, height: 2, rowBytes: 8, byteCount: 13)
        }
    }

    @Test("Coordinate checks reject negative and one-past-end access")
    func sampleCoordinates() throws {
        let descriptor = try ImageDescriptor.greyscale16(width: 1, height: 1)
        let destination = try ImageDestination.allocate(descriptor: descriptor)
        for coordinate in [(-1, 0), (0, -1), (1, 0), (0, 1), (Int.max, Int.max)] {
            #expect(throws: (any Error).self) {
                try destination.setSample(1, x: coordinate.0, y: coordinate.1)
            }
        }
        destination.abort()
        let readableDestination = try ImageDestination.allocate(descriptor: descriptor)
        let image = try readableDestination.seal()
        for coordinate in [(-1, 0), (0, -1), (1, 0), (0, 1), (Int.max, Int.max)] {
            #expect(throws: (any Error).self) { try image.sample(x: coordinate.0, y: coordinate.1) }
        }
    }

    @Test("Unsupported interpretations never masquerade as greyscale UInt16")
    func unsupportedInterpretations() throws {
        let plane = try PlaneDescriptor(width: 1, height: 1, rowBytes: 2, byteCount: 2)
        #expect(throws: (any Error).self) {
            try ImageDescriptor(width: 1, height: 1, sampleType: .signedInteger, planes: [plane])
        }
        #expect(throws: (any Error).self) {
            try ImageDescriptor(width: 1, height: 1, byteOrder: .bigEndian, planes: [plane])
        }
        #expect(throws: (any Error).self) {
            try ImageDescriptor(width: 1, height: 1, planes: [plane, plane])
        }
    }
}
