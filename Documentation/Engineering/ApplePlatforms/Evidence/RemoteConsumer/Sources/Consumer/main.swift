import Foundation
import SwiftJ2K

enum ConsumerFailure: Error { case samples, unexpectedCapability, unexpectedCodecSuccess }
let descriptor = try ImageDescriptor.greyscale16(width: 3, height: 2, meaningfulBits: 16, rowBytes: 8)
let destination = try ImageDestination.allocate(descriptor: descriptor)
let identity = destination.storage.allocationID
let samples: [UInt16] = [0, 65535, 4095, 1, 32768, 17]
let image = try destination.writeUInt16 { x, y in samples[y * 3 + x] }
guard image.storage.allocationID == identity else { throw ConsumerFailure.samples }
for y in 0..<2 {
    for x in 0..<3 {
        guard try image.sampleUInt16(x: x, y: y) == samples[y * 3 + x] else { throw ConsumerFailure.samples }
    }
}
let encoder = try SwiftJ2K.Encoder()
guard !encoder.capabilities.canEncode else { throw ConsumerFailure.unexpectedCapability }
do {
    _ = try await encoder.encode(image)
    throw ConsumerFailure.unexpectedCodecSuccess
} catch let error as CodecError where error.category == .unsupportedFeature {}
print("SwiftJ2K: fresh published consumer passed; sample storage works and codec operations remain unavailable.")
