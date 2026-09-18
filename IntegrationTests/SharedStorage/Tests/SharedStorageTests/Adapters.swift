// SPDX-License-Identifier: MIT
import Foundation
import Synchronization
import SwiftJ2K
import SwiftJLS

/// Fixture-local observations. This counts the owned allocation factory and
/// actual borrow callbacks, not all allocations or memory traffic in the process.
final class Observations: Sendable {
    struct Snapshot: Sendable {
        var allocations = 0
        var ownerReleases = 0
        var readScopes = 0
        var writeScopes = 0
    }
    private let counters = Mutex(Snapshot())
    var snapshot: Snapshot { counters.withLock { $0 } }
    func allocated() { counters.withLock { $0.allocations += 1 } }
    func released() { counters.withLock { $0.ownerReleases += 1 } }
    func read() { counters.withLock { $0.readScopes += 1 } }
    func wrote() { counters.withLock { $0.writeScopes += 1 } }
}

/// The only pixel allocation site in this fixture. All later wrappers retain it.
final class ObservedJ2KOwner: SwiftJ2K.WritableImageStorage {
    let allocation: SwiftJ2K.OwnedImageStorage
    let observations: Observations
    init(byteCount: Int, observations: Observations) throws {
        allocation = try SwiftJ2K.OwnedImageStorage(byteCount: byteCount)
        self.observations = observations
        observations.allocated()
    }
    var byteCount: Int { allocation.byteCount }
    var allocationID: UUID { allocation.allocationID }
    func reserveWrite() throws -> any SwiftJ2K.ImageWriteLease {
        ObservedJ2KLease(lease: try allocation.reserveWrite(), owner: self)
    }
    func readOnlyStorage() throws -> any SwiftJ2K.ReadOnlyImageStorage {
        ObservedJ2KReader(storage: try allocation.readOnlyStorage(), owner: self)
    }
    deinit { observations.released() }
}

private final class ObservedJ2KLease: SwiftJ2K.ImageWriteLease {
    let lease: any SwiftJ2K.ImageWriteLease
    let owner: ObservedJ2KOwner
    init(lease: any SwiftJ2K.ImageWriteLease, owner: ObservedJ2KOwner) {
        self.lease = lease
        self.owner = owner
    }
    var byteCount: Int { lease.byteCount }
    var allocationID: UUID { lease.allocationID }
    func withUnsafeMutableBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) throws -> R {
        try lease.withUnsafeMutableBytes { bytes in
            owner.observations.wrote()
            return try body(bytes)
        }
    }
    func finish() throws -> any SwiftJ2K.ReadOnlyImageStorage {
        ObservedJ2KReader(storage: try lease.finish(), owner: owner)
    }
    func abort() { lease.abort() }
    deinit { lease.abort() }
}

private final class ObservedJ2KReader: SwiftJ2K.ReadOnlyImageStorage {
    let storage: any SwiftJ2K.ReadOnlyImageStorage
    let owner: ObservedJ2KOwner
    init(storage: any SwiftJ2K.ReadOnlyImageStorage, owner: ObservedJ2KOwner) {
        self.storage = storage
        self.owner = owner
    }
    var byteCount: Int { storage.byteCount }
    var allocationID: UUID { storage.allocationID }
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
        try storage.withUnsafeBytes { bytes in
            owner.observations.read()
            return try body(bytes)
        }
    }
}

/// Distinct SwiftJLS protocol conformance around a real SwiftJ2K provider.
/// No independent lock/state machine: the actual provider owns exclusivity.
final class JLSWritableAdapter: SwiftJLS.WritableImageStorage {
    let owner: any SwiftJ2K.WritableImageStorage
    init(owner: any SwiftJ2K.WritableImageStorage) { self.owner = owner }
    var byteCount: Int { owner.byteCount }
    var allocationID: UUID { owner.allocationID }
    func reserveWrite() throws -> any SwiftJLS.ImageWriteLease {
        try translatedToJLS { JLSWriteLeaseAdapter(lease: try owner.reserveWrite()) }
    }
}

private final class JLSWriteLeaseAdapter: SwiftJLS.ImageWriteLease {
    let lease: any SwiftJ2K.ImageWriteLease
    init(lease: any SwiftJ2K.ImageWriteLease) { self.lease = lease }
    var byteCount: Int { lease.byteCount }
    var allocationID: UUID { lease.allocationID }
    func withUnsafeMutableBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) throws -> R {
        try translatedToJLS { try lease.withUnsafeMutableBytes(body) }
    }
    func finish() throws -> any SwiftJLS.ReadOnlyImageStorage {
        try translatedToJLS { JLSReadAdapter(storage: try lease.finish()) }
    }
    func abort() { lease.abort() }
    deinit { lease.abort() }
}

final class JLSReadAdapter: SwiftJLS.ReadOnlyImageStorage {
    let storage: any SwiftJ2K.ReadOnlyImageStorage
    init(storage: any SwiftJ2K.ReadOnlyImageStorage) { self.storage = storage }
    var byteCount: Int { storage.byteCount }
    var allocationID: UUID { storage.allocationID }
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
        try translatedToJLS { try storage.withUnsafeBytes(body) }
    }
}

func translatedToJLS<R>(_ body: () throws -> R) throws -> R {
    do {
        return try body()
    } catch let error as SwiftJ2K.CodecError {
        let category: SwiftJLS.CodecError.Category
        switch error.category {
        case .invalidArgument: category = .invalidArgument
        case .malformedInput: category = .malformedInput
        case .unsupportedFormat: category = .unsupportedFormat
        case .unsupportedFeature: category = .unsupportedFeature
        case .incompatibleImageLayout: category = .incompatibleImageLayout
        case .resourceLimitExceeded: category = .resourceLimitExceeded
        case .storageUnavailable: category = .storageUnavailable
        case .backendUnavailable: category = .backendUnavailable
        case .ioFailure: category = .ioFailure
        case .internalFailure: category = .internalFailure
        }
        throw SwiftJLS.CodecError(category, context: error.context)
    }
    // CancellationError, SwiftJLS errors and other callback errors propagate
    // unchanged; no pointer, enum or protocol is reinterpreted across modules.
}

/// Explicit mapping of the initial qualified profile only. Later layouts need
/// their own mapping and tests rather than an assumption about Swift type layout.
func jlsDescriptor(from source: SwiftJ2K.ImageDescriptor) throws -> SwiftJLS.ImageDescriptor {
    guard source.sampleType == .unsignedInteger, source.storageBits == 16,
          source.byteOrder == .littleEndian, source.components == [.greyscale],
          source.colour.interpretation == .greyscale, source.alpha == .none,
          source.planes.count == 1, let plane = source.planes.first else {
        throw SwiftJLS.CodecError(.unsupportedFeature, context: "fixture profile requires unsigned greyscale16")
    }
    let mappedPlane = try SwiftJLS.PlaneDescriptor(
        width: plane.width, height: plane.height, components: plane.components,
        offset: plane.offset, sampleStride: plane.sampleStride, pixelStride: plane.pixelStride,
        rowBytes: plane.rowBytes, byteCount: plane.byteCount)
    return try SwiftJLS.ImageDescriptor(
        width: source.width, height: source.height, sampleType: .unsignedInteger,
        storageBits: source.storageBits, meaningfulBits: source.meaningfulBits,
        byteOrder: .littleEndian, components: [.greyscale],
        colour: SwiftJLS.ColourDescription(interpretation: .greyscale, iccData: source.colour.iccData),
        alpha: .none, planes: [mappedPlane])
}

func jlsImage(from source: SwiftJ2K.Image) throws -> SwiftJLS.Image {
    try SwiftJLS.Image(
        descriptor: jlsDescriptor(from: source.descriptor),
        storage: JLSReadAdapter(storage: source.storage),
        metadata: SwiftJLS.ImageMetadata(entries: source.metadata.entries))
}
