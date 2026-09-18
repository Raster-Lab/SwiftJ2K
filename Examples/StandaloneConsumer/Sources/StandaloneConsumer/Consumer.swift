// Copyright (c) 2026 Raster Images Private Limited
// SPDX-License-Identifier: MIT

import Foundation
import SwiftJ2K

private struct ConsumerFailure: Error {
    let message: String
}

private func require(_ condition: Bool, _ message: String) throws {
    guard condition else { throw ConsumerFailure(message: message) }
}

/// A real downstream owner adapter using only the public module interface.
/// It retains the original allocation; it never copies sample bytes.
private final class ConsumerReadOwner: ReadOnlyImageStorage {
    private let owner: any ReadOnlyImageStorage
    init(_ owner: any ReadOnlyImageStorage) { self.owner = owner }
    var byteCount: Int { owner.byteCount }
    var allocationID: UUID { owner.allocationID }
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
        try owner.withUnsafeBytes(body)
    }
}

@main
private enum StandaloneConsumer {
    static func main() async throws {
        let reader: ConsumerReadOwner
        let allocationID: UUID
        weak var observedOwner: OwnedImageStorage?
        do {
            let owner = try OwnedImageStorage(byteCount: 16)
            observedOwner = owner
            allocationID = owner.allocationID
            let lease = try owner.reserveWrite()
            try lease.withUnsafeMutableBytes { bytes in
                // Explicit little-endian test words: 0, 4095 and 65535.
                bytes[0] = 0; bytes[1] = 0
                bytes[2] = 0xff; bytes[3] = 0x0f
                bytes[4] = 0xff; bytes[5] = 0xff
            }
            reader = ConsumerReadOwner(try lease.finish())
        }
        await Task.yield()
        try require(observedOwner != nil, "The adapter failed to retain its allocation")
        try require(reader.allocationID == allocationID, "The adapter changed allocation identity")
        let bytesMatch = try reader.withUnsafeBytes { bytes in
            bytes[0] == 0 && bytes[1] == 0 && bytes[2] == 0xff && bytes[3] == 0x0f
                && bytes[4] == 0xff && bytes[5] == 0xff
        }
        try require(bytesMatch, "The retained sample bytes changed")

        let encoder = try Encoder()
        let decoder = try Decoder()
        try require(!encoder.capabilities.supportsEncoding, "An unimplemented encoder was advertised")
        try require(!decoder.capabilities.supportsDecoding, "An unimplemented decoder was advertised")
        for precision in [12, 16] {
            let maximum: UInt16 = precision == 12 ? 4095 : 65535
            let expected: [UInt16] = [0, 1, maximum, maximum - 1, 37, 1024]
            let descriptor = try ImageDescriptor.greyscale16(
                width: 3, height: 2, meaningfulBits: precision, rowBytes: 8, offset: 2
            )
            let destination = try ImageDestination.allocate(descriptor: descriptor)
            for y in 0..<2 {
                for x in 0..<3 {
                    try destination.setSample(expected[y * 3 + x], x: x, y: y)
                }
            }
            let image = try destination.seal()
            let adapted = try Image(
                descriptor: image.descriptor,
                storage: ConsumerReadOwner(image.storage),
                metadata: image.metadata
            )
            await Task.yield()
            try require(adapted.storage.allocationID == image.storage.allocationID,
                        "A descriptor adapter changed allocation identity")
            try require(adapted.descriptor.meaningfulBits == precision,
                        "An adapter changed meaningful precision")
            for y in 0..<2 {
                for x in 0..<3 {
                    let value = try adapted.sample(x: x, y: y)
                    try require(value == expected[y * 3 + x], "A logical sample changed")
                }
            }
            do {
                _ = try await encoder.encode(adapted)
                throw ConsumerFailure(message: "An unimplemented encoder returned success")
            } catch let error as CodecError {
                try require(error.category == .unsupportedFeature, "Unexpected encoder error category")
            }
        }

        let transcoder = try Transcoder(configuration: TranscoderConfiguration())
        try require(transcoder.capabilities.pairs.isEmpty, "Unimplemented native support was advertised")
        for target in TranscodeTarget.allCases {
            do {
                _ = try await transcoder.transcode(Data(), to: target)
                throw ConsumerFailure(message: "An unimplemented native operation returned success")
            } catch let error as CodecError {
                try require(error.category == .unsupportedFeature, "Unexpected native API failure category")
            }
        }
        print("Public consumer passed: retained storage and native API feasibility. Codec implementation remains deferred.")
    }
}
