// SPDX-License-Identifier: Apache-2.0
import Foundation
import SwiftJ2K

@main struct Consumer {
    static func main() async throws {
        let descriptor = try SwiftJ2K.ImageDescriptor.greyscale16(width: 3, height: 2,
            meaningfulBits: 12, rowBytes: 8)
        let destination = try SwiftJ2K.ImageDestination.allocate(descriptor: descriptor)
        let image = try destination.writeUInt16 { x, y in UInt16(x == 0 ? 4095 : y * 3 + x) }
        guard try image.sampleUInt16(x: 0, y: 1) == 4095 else {
            throw SwiftJ2K.CodecError(.internalFailure, "Synthetic sample changed.")
        }
        let encoder = try SwiftJ2K.Encoder()
        let decoder = try SwiftJ2K.Decoder()
        guard encoder.capabilities.canEncode, decoder.capabilities.canDecode else {
            throw SwiftJ2K.CodecError(.internalFailure, "Scalar lossless coverage is not advertised.")
        }
        let encoded = try await encoder.encode(image)
        let info = try decoder.inspect(encoded.data)
        guard info.descriptor.width == 3, info.descriptor.meaningfulBits == 12 else {
            throw SwiftJ2K.CodecError(.internalFailure, "Inspection disagrees with the source descriptor.")
        }
        let decoded = try await decoder.decode(encoded.data)
        for y in 0..<2 {
            for x in 0..<3 where try decoded.image.sampleUInt16(x: x, y: y) != image.sampleUInt16(x: x, y: y) {
                throw SwiftJ2K.CodecError(.internalFailure, "Lossless round trip changed a sample.")
            }
        }
        print("Independent SwiftJ2K consumer passed; \(encoded.data.count)-byte lossless codestream round-tripped.")
    }
}
