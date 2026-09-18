// SPDX-License-Identifier: MIT
import Foundation
import Testing
import SwiftJ2K

@Suite("Honest JPEG 2000 capability boundary")
struct CodecBoundaryTests {
    @Test("The public capability matrix advertises no migrated codec yet")
    func emptyCapabilitiesAndLosslessDefault() throws {
        let encoder = try Encoder()
        let decoder = try Decoder()
        #expect(encoder.configuration.mode == .lossless)
        #expect(EncoderConfiguration.lossless.mode == .lossless)
        #expect(encoder.capabilities == Encoder.capabilities)
        #expect(decoder.capabilities == Decoder.capabilities)
        for capability in [encoder.capabilities, decoder.capabilities] {
            #expect(!capability.supportsEncoding)
            #expect(!capability.supportsDecoding)
            #expect(!capability.supportsInspection)
            #expect(capability.formats.isEmpty)
            #expect(capability.compressionModes.isEmpty)
            #expect(capability.meaningfulBits == nil)
            #expect(capability.backends.isEmpty)
        }
    }

    @Test("Default construction never supplies a lossy approximation")
    func losslessDefaultDoesNotEncodeLossyData() async throws {
        let encoder = try Encoder()
        let descriptor = try ImageDescriptor.greyscale16(width: 1, height: 1)
        let destination = try ImageDestination.allocate(descriptor: descriptor)
        try destination.setSample(65535, x: 0, y: 0)
        let image = try destination.seal()
        do {
            _ = try await encoder.encode(image)
            Issue.record("Milestone 1 must not emit a pretend JPEG 2000 bitstream")
        } catch let error as CodecError {
            #expect(error.category == .unsupportedFeature)
        }
        // A failed encoder must leave its immutable input intact.
        #expect(try image.sample(x: 0, y: 0) == 65535)
    }

    @Test("Unimplemented lossy and near-lossless configurations are rejected")
    func unsupportedModes() throws {
        for mode in [CompressionMode.lossy, .nearLossless(maximumAbsoluteError: 1)] {
            do {
                _ = try EncoderConfiguration(mode: mode)
                Issue.record("An unavailable compression mode must fail explicitly")
            } catch let error as CodecError {
                #expect(error.category == .unsupportedFeature)
            }
        }
    }

    @Test("Inspect and decode do not infer JPEG 2000 support from a familiar marker")
    func markerDoesNotPretendToDecode() async throws {
        let bytes = Data([0xff, 0x4f, 0xff, 0xd9])
        let decoder = try Decoder()
        do {
            _ = try decoder.inspect(bytes)
            Issue.record("A marker-only input is not implemented JPEG 2000 inspection")
        } catch let error as CodecError {
            #expect(error.category == .unsupportedFeature)
        }
        do {
            _ = try await decoder.decode(bytes)
            Issue.record("No JPEG 2000 algorithm was migrated in Milestone 1")
        } catch let error as CodecError {
            #expect(error.category == .unsupportedFeature)
        }
    }

    @Test("Failed caller-storage decode cannot publish a partial frame")
    func failingDestinationDecode() async throws {
        let descriptor = try ImageDescriptor.greyscale16(width: 1, height: 1)
        let destination = try ImageDestination.allocate(descriptor: descriptor)
        let decoder = try Decoder()
        do {
            _ = try await decoder.decode(Data(), into: destination)
            Issue.record("A scaffold decoder must report unsupportedFeature")
        } catch let error as CodecError {
            #expect(error.category == .unsupportedFeature)
        }
        expectCodecError(.storageUnavailable) { try destination.seal() }
    }

    @Test("Task cancellation keeps CancellationError and invalidates destination")
    func cancelledDestinationDecode() async throws {
        let descriptor = try ImageDescriptor.greyscale16(width: 1, height: 1)
        let destination = try ImageDestination.allocate(descriptor: descriptor)
        let decoder = try Decoder()
        let work = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            do {
                _ = try await decoder.decode(Data(), into: destination)
                Issue.record("A cancelled operation must not succeed")
            } catch is CancellationError {
                // Cancellation is intentionally not converted into CodecError.
            } catch {
                Issue.record("Expected CancellationError, received \(type(of: error))")
            }
        }
        await work.value
        expectCodecError(.storageUnavailable) { try destination.seal() }
    }
}
