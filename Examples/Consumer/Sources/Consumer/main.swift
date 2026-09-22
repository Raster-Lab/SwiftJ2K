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
        guard !encoder.capabilities.canEncode, !decoder.capabilities.canDecode else {
            throw SwiftJ2K.CodecError(.internalFailure, "Unexpected codec capability.")
        }
        do {
            _ = try await encoder.encode(image)
            throw SwiftJ2K.CodecError(.internalFailure, "Unimplemented encoding succeeded.")
        } catch let error as SwiftJ2K.CodecError where error.category == .unsupportedFeature {}
        print("Independent SwiftJ2K consumer passed; synthetic storage only.")
    }
}
