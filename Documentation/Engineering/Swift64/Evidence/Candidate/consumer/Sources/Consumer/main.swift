import SwiftJ2K
let d = try ImageDescriptor.greyscale16(width: 3, height: 1, meaningfulBits: 16, rowBytes: 8)
let image = try ImageDestination.allocate(descriptor: d).writeUInt16 { x, _ in [UInt16(0), 65535, 4095][x] }
guard try image.sampleUInt16(x: 1, y: 0) == 65535 else { throw CodecError(.internalFailure, "Sample mismatch") }
let encoder = try Encoder()
guard !encoder.capabilities.canEncode else { throw CodecError(.internalFailure, "Update this Milestone 1 consumer") }
do { _ = try await encoder.encode(image); throw CodecError(.internalFailure, "Unexpected codec success") }
catch let error as CodecError where error.category == .unsupportedFeature {}
print("Fresh independent consumer passed")
