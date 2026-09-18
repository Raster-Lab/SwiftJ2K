// SPDX-License-Identifier: MIT
import Foundation
import Testing
import SwiftJ2K

@Suite("Finite storage admission and platform resource policy")
struct ResourcePolicyTests {
    @Test("A caller's smaller ICC budget rejects before reserving external storage")
    func descriptorMetadataAdmissionPrecedesReservation() throws {
        let plane = try PlaneDescriptor(width: 1, height: 1, rowBytes: 2, byteCount: 2)
        let colour = ColourDescription(interpretation: .greyscale, iccData: Data([1, 2]))
        let descriptor = try ImageDescriptor(width: 1, height: 1, colour: colour, planes: [plane])
        let owner = try OwnedImageStorage(byteCount: 2)
        let limits = try ResourceLimits(maximumMetadataBytes: 0, maximumICCBytes: 0)
        do {
            _ = try ImageDestination(descriptor: descriptor, storage: owner, limits: limits)
            Issue.record("ICC admission must occur before a write reservation")
        } catch let error as CodecError {
            #expect(error.category == .resourceLimitExceeded)
        }
        // The descriptor was rejected before taking the caller's one writer.
        let lease = try owner.reserveWrite()
        lease.abort()
    }

    @Test("A caller's smaller total budget denies a valid image before allocation")
    func totalBudgetDeniesAllocation() throws {
        let descriptor = try ImageDescriptor.greyscale16(width: 3, height: 2, rowBytes: 8)
        let limits = try ResourceLimits(maximumDecodedBytes: 32, maximumTotalBytes: 8)
        do {
            _ = try ImageDestination.allocate(descriptor: descriptor, limits: limits)
            Issue.record("A smaller total budget must deny destination allocation")
        } catch let error as CodecError {
            #expect(error.category == .resourceLimitExceeded)
        }
    }

    @Test("Row padding counts towards the decoded allocation budget")
    func paddingCountsTowardsAdmission() throws {
        let descriptor = try ImageDescriptor.greyscale16(width: 1, height: 3, rowBytes: 8)
        let limits = try ResourceLimits(maximumDecodedBytes: 6)
        do {
            _ = try ImageDestination.allocate(descriptor: descriptor, limits: limits)
            Issue.record("Six sample bytes do not cover padded storage")
        } catch let error as CodecError {
            #expect(error.category == .resourceLimitExceeded)
        }
    }

    @Test("An exact storage budget remains usable")
    func exactBudgetAllowsStorage() throws {
        let descriptor = try ImageDescriptor.greyscale16(width: 1, height: 1)
        let limits = try ResourceLimits(maximumDecodedBytes: 2, maximumTotalBytes: 2)
        let destination = try ImageDestination.allocate(descriptor: descriptor, limits: limits)
        try destination.setSample(65535, x: 0, y: 0)
        let image = try destination.seal()
        #expect(try image.sample(x: 0, y: 0) == 65535)
    }

    @Test("Invalid resource policies reject rather than normalise")
    func invalidLimits() throws {
        #expect(throws: (any Error).self) { try ResourceLimits(maximumInputBytes: 0) }
        #expect(throws: (any Error).self) { try ResourceLimits(maximumWorkers: -1) }
        #expect(throws: (any Error).self) { try ResourceLimits(deadline: .zero) }
        #expect(throws: (any Error).self) {
            try ResourceLimits(maximumMetadataBytes: 1, maximumICCBytes: 2)
        }
    }

    @Test("Platform defaults select the bounded Watch profile when building for Watch")
    func platformDefaults() {
        #if os(watchOS)
        #expect(ResourceLimits.default == .watch)
        #expect(ResourceLimits.default.maximumDecodedBytes == 32 * 1_048_576)
        #expect(ResourceLimits.default.maximumWorkers <= 2)
        #expect(ResourceLimits.default.deadline == .seconds(30))
        #else
        #expect(ResourceLimits.default == .general)
        #expect(ResourceLimits.default.maximumDecodedBytes == 512 * 1_048_576)
        #expect(ResourceLimits.default.maximumWorkers <= 8)
        #expect(ResourceLimits.default.deadline == .seconds(120))
        #endif
    }
}
