import Foundation
import SwiftJ2K

@main
struct MigrationExample {
    static func main() async throws {
        // Known application samples after validating the predecessor's packing.
        let samples: [UInt16] = [0, 4095, 17, 2048, 1, 4094]
        let limits = try SwiftJ2K.ResourceLimits(
            maximumDecodedBytes: 1024, maximumMemoryBytes: 4096)
        let descriptor = try SwiftJ2K.ImageDescriptor.greyscale16(
            width: 3, height: 2, meaningfulBits: 12, rowBytes: 8, limits: limits)
        let destination = try SwiftJ2K.ImageDestination.allocate(
            descriptor: descriptor, limits: limits)
        let image = try destination.writeUInt16 { x, y in samples[y * 3 + x] }
        guard try image.sampleUInt16(x: 1, y: 0) == 4095 else {
            throw SwiftJ2K.CodecError(.internalFailure, "Sample adapter mismatch.")
        }
        let encoder = try SwiftJ2K.Encoder()
        guard !encoder.capabilities.canEncode else {
            throw SwiftJ2K.CodecError(.internalFailure, "Revisit this milestone example.")
        }
        do {
            _ = try await encoder.encode(image, options: .init(resourceLimits: limits))
            throw SwiftJ2K.CodecError(.internalFailure, "Unexpected codec success.")
        } catch let error as SwiftJ2K.CodecError where error.category == .unsupportedFeature {
            print("Storage migration example passed; keep predecessor codec routing.")
        }
    }
}
