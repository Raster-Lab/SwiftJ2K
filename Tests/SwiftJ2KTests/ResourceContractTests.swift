// SPDX-License-Identifier: MIT
import Foundation
import Testing
import SwiftJ2K

@Suite("Resource admission and stable error categories")
struct ResourceContractTests {
    @Test("Exactly admitted allocation succeeds; one byte over is rejected")
    func decodedAndAggregateBytes() throws {
        let limits = try ResourceLimits(maximumDecodedBytes: 16, maximumTotalBytes: 16)
        let accepted = try OwnedImageStorage(byteCount: 16, limits: limits)
        #expect(accepted.byteCount == 16)
        expectCodecError(.resourceLimitExceeded) { try OwnedImageStorage(byteCount: 17, limits: limits) }
        let aggregate = try ResourceLimits(maximumDecodedBytes: 32, maximumTotalBytes: 8)
        expectCodecError(.resourceLimitExceeded) { try OwnedImageStorage(byteCount: 9, limits: aggregate) }
        expectCodecError(.invalidArgument) { try OwnedImageStorage(byteCount: 0) }
        expectCodecError(.invalidArgument) { try OwnedImageStorage(byteCount: -1) }
    }

    @Test("Dimension and pixel ceilings are independent")
    func geometryBudgets() throws {
        let dimensions = try ResourceLimits(maximumDimension: 2)
        _ = try ImageDescriptor.greyscale16(width: 2, height: 2, limits: dimensions)
        expectCodecError(.resourceLimitExceeded) {
            try ImageDescriptor.greyscale16(width: 3, height: 1, limits: dimensions)
        }
        let pixels = try ResourceLimits(maximumPixels: 4)
        expectCodecError(.resourceLimitExceeded) {
            try ImageDescriptor.greyscale16(width: 3, height: 2, limits: pixels)
        }
    }

    @Test("Initialisation rechecks the retained capacity, including padding")
    func callerStorageCapacityRechecked() throws {
        let descriptor = try ImageDescriptor.greyscale16(width: 1, height: 1)
        let owner = try OwnedImageStorage(byteCount: 32)
        let limits = try ResourceLimits(maximumDecodedBytes: 16)
        expectCodecError(.resourceLimitExceeded) {
            try ImageDestination(descriptor: descriptor, storage: owner, limits: limits)
        }
        #expect(owner.state == .available)
    }

    @Test("Invalid options fail during construction")
    func invalidLimits() throws {
        expectCodecError(.invalidArgument) { try ResourceLimits(maximumInputBytes: 0) }
        expectCodecError(.invalidArgument) { try ResourceLimits(maximumWorkers: 0) }
        expectCodecError(.invalidArgument) { try ResourceLimits(maximumNestingDepth: 0) }
        expectCodecError(.invalidArgument) { try ResourceLimits(maximumPixels: -1) }
        expectCodecError(.invalidArgument) { try ResourceLimits(maximumFrames: -1) }
        expectCodecError(.invalidArgument) { try ResourceLimits(deadline: .zero) }
        expectCodecError(.invalidArgument) { try ResourceLimits(deadline: .seconds(-1)) }
        expectCodecError(.invalidArgument) { try ResourceLimits(maximumMetadataBytes: -1) }
        expectCodecError(.invalidArgument) {
            try ResourceLimits(maximumMetadataBytes: 1, maximumICCBytes: 2)
        }
    }

    @Test("Metadata keys and values both count towards the budget")
    func metadataByteAccounting() throws {
        let limits = try ResourceLimits(maximumMetadataBytes: 5, maximumICCBytes: 0)
        let accepted = try ImageMetadata(entries: ["a": Data(repeating: 1, count: 4)], limits: limits)
        #expect(accepted.byteCount == 5)
        expectCodecError(.resourceLimitExceeded) {
            try ImageMetadata(entries: ["ab": Data(repeating: 1, count: 4)], limits: limits)
        }
        expectCodecError(.invalidArgument) { try ImageMetadata(entries: ["": Data()]) }
    }

    @Test("A failed metadata admission invalidates the destination before publication")
    func metadataFailureIsTerminal() throws {
        let limits = try ResourceLimits(maximumTotalBytes: 6, maximumMetadataBytes: 8, maximumICCBytes: 0)
        let descriptor = try ImageDescriptor.greyscale16(width: 1, height: 1)
        let owner = try OwnedImageStorage(byteCount: 2)
        let destination = try ImageDestination(descriptor: descriptor, storage: owner, limits: limits)
        let metadata = try ImageMetadata(entries: ["a": Data(repeating: 1, count: 4)])
        expectCodecError(.resourceLimitExceeded) { try destination.seal(metadata: metadata) }
        #expect(owner.state == .invalid)
        expectCodecError(.storageUnavailable) { try owner.readOnlyStorage() }
    }

    @Test("ICC bytes count both individually and with other retained metadata")
    func iccLimits() throws {
        let plane = try PlaneDescriptor(width: 1, height: 1, rowBytes: 2, byteCount: 2)
        let colour = ColourDescription(interpretation: .greyscale, iccData: Data(repeating: 0, count: 3))
        let limits = try ResourceLimits(maximumMetadataBytes: 8, maximumICCBytes: 2)
        expectCodecError(.resourceLimitExceeded) {
            try ImageDescriptor(width: 1, height: 1, colour: colour, planes: [plane], limits: limits)
        }
    }

    @Test("The Watch profile explicitly reduces working-memory ceilings")
    func watchProfile() {
        #expect(ResourceLimits.watch.maximumInputBytes == 16 * 1_048_576)
        #expect(ResourceLimits.watch.maximumDecodedBytes == 32 * 1_048_576)
        #expect(ResourceLimits.watch.maximumWorkspaceBytes == 32 * 1_048_576)
        #expect(ResourceLimits.watch.maximumWorkers <= 2)
        #expect(ResourceLimits.watch.deadline == .seconds(30))
        #expect(ResourceLimits.general.deadline == .seconds(120))
    }
}
