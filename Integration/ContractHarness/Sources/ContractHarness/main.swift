// SPDX-License-Identifier: Apache-2.0
// Development-only experiment. No codec algorithms or compressed inputs.
import Foundation
import Synchronization
import SwiftJ2K
import SwiftJLS
import SwiftJXL
import SwiftJLI

struct ExperimentFailure: Error { let message: String }
func require(_ condition: Bool, _ message: String) throws {
    guard condition else { throw ExperimentFailure(message: message) }
}

final class Metrics: Sendable {
    struct Counts: Sendable { var allocations = 0; var writes = 0; var reads = 0 }
    let counts = Mutex(Counts())
}

final class InstrumentedOwner: SwiftJ2K.WritableImageStorage, Sendable {
    let underlying: SwiftJ2K.OwnedImageStorage
    let metrics: Metrics
    var byteCount: Int { underlying.byteCount }
    var allocationID: UUID { underlying.allocationID }
    init(byteCount: Int, metrics: Metrics) throws {
        underlying = try SwiftJ2K.OwnedImageStorage(byteCount: byteCount)
        self.metrics = metrics
        metrics.counts.withLock { $0.allocations += 1 }
    }
    func reserveWrite() throws -> SwiftJ2K.StorageWriteLease { try underlying.reserveWrite() }
    func withUnsafeMutableBytes<R>(lease: SwiftJ2K.StorageWriteLease,
        _ body: (UnsafeMutableRawBufferPointer) throws -> R) throws -> R {
        try underlying.withUnsafeMutableBytes(lease: lease) { bytes in
            metrics.counts.withLock { $0.writes += 1 }
            return try body(bytes)
        }
    }
    func finishAndSeal(lease: SwiftJ2K.StorageWriteLease) throws -> any SwiftJ2K.ReadOnlyImageStorage {
        CountingReadOwner(underlying: try underlying.finishAndSeal(lease: lease), metrics: metrics)
    }
    func abortAndInvalidate(lease: SwiftJ2K.StorageWriteLease) throws {
        try underlying.abortAndInvalidate(lease: lease)
    }
}
struct CountingReadOwner: SwiftJ2K.ReadOnlyImageStorage {
    let underlying: any SwiftJ2K.ReadOnlyImageStorage
    let metrics: Metrics
    var byteCount: Int { underlying.byteCount }
    var allocationID: UUID { underlying.allocationID }
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
        metrics.counts.withLock { $0.reads += 1 }
        return try underlying.withUnsafeBytes(body)
    }
}

struct SwiftJLSReadAdapter: SwiftJLS.ReadOnlyImageStorage {
    let underlying: any SwiftJ2K.ReadOnlyImageStorage
    var byteCount: Int { underlying.byteCount }
    var allocationID: UUID { underlying.allocationID }
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
        try underlying.withUnsafeBytes(body)
    }
}

struct SwiftJXLReadAdapter: SwiftJXL.ReadOnlyImageStorage {
    let underlying: any SwiftJ2K.ReadOnlyImageStorage
    var byteCount: Int { underlying.byteCount }
    var allocationID: UUID { underlying.allocationID }
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
        try underlying.withUnsafeBytes(body)
    }
}

struct SwiftJLIReadAdapter: SwiftJLI.ReadOnlyImageStorage {
    let underlying: any SwiftJ2K.ReadOnlyImageStorage
    var byteCount: Int { underlying.byteCount }
    var allocationID: UUID { underlying.allocationID }
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
        try underlying.withUnsafeBytes(body)
    }
}

// Local tokens map explicitly to the issuing provider's tokens. No memory/type casts.
final class JLSWriteAdapter: SwiftJLS.WritableImageStorage, Sendable {
    let underlying: any SwiftJ2K.WritableImageStorage
    private let leases = Mutex<[SwiftJLS.StorageWriteLease: SwiftJ2K.StorageWriteLease]>([:])
    var byteCount: Int { underlying.byteCount }
    var allocationID: UUID { underlying.allocationID }
    init(_ underlying: any SwiftJ2K.WritableImageStorage) { self.underlying = underlying }
    private func mapped<R>(_ body: () throws -> R) throws -> R {
        do { return try body() }
        catch let error as SwiftJ2K.CodecError {
            throw SwiftJLS.CodecError(SwiftJLS.CodecError.Category(rawValue: error.category.rawValue) ?? .internalFailure, error.message)
        }
    }
    func reserveWrite() throws -> SwiftJLS.StorageWriteLease {
        try mapped {
            let base = try underlying.reserveWrite()
            let local = SwiftJLS.StorageWriteLease()
            leases.withLock { $0[local] = base }
            return local
        }
    }
    private func resolve(_ local: SwiftJLS.StorageWriteLease) throws -> SwiftJ2K.StorageWriteLease {
        guard let base = leases.withLock({ $0[local] }) else {
            throw SwiftJLS.CodecError(.storageUnavailable, "Unknown adapter lease.")
        }
        return base
    }
    func withUnsafeMutableBytes<R>(lease: SwiftJLS.StorageWriteLease,
        _ body: (UnsafeMutableRawBufferPointer) throws -> R) throws -> R {
        try mapped { try underlying.withUnsafeMutableBytes(lease: resolve(lease), body) }
    }
    func finishAndSeal(lease: SwiftJLS.StorageWriteLease) throws -> any SwiftJLS.ReadOnlyImageStorage {
        try mapped {
            let sealed = try underlying.finishAndSeal(lease: resolve(lease))
            leases.withLock { _ = $0.removeValue(forKey: lease) }
            return SwiftJLSReadAdapter(underlying: sealed)
        }
    }
    func abortAndInvalidate(lease: SwiftJLS.StorageWriteLease) throws {
        try mapped {
            try underlying.abortAndInvalidate(lease: resolve(lease))
            leases.withLock { _ = $0.removeValue(forKey: lease) }
        }
    }
}

@main struct ContractExperiment {
    static func main() async throws {
        for precision in [12, 16] {
            let metrics = Metrics()
            let descriptor = try SwiftJ2K.ImageDescriptor.greyscale16(width: 5, height: 3,
                meaningfulBits: precision, rowBytes: 14, offset: 2)
            let owner = try InstrumentedOwner(byteCount: descriptor.requiredByteCount, metrics: metrics)
            let destination = try SwiftJ2K.ImageDestination(descriptor: descriptor, storage: owner)
            let jlsDescriptor = try SwiftJLS.ImageDescriptor.greyscale16(width: 5, height: 3,
                meaningfulBits: precision, rowBytes: 14, offset: 2)
            do {
                _ = try SwiftJLS.ImageDestination(descriptor: jlsDescriptor, storage: JLSWriteAdapter(owner))
                throw ExperimentFailure(message: "A cross-module second writer was accepted.")
            } catch let error as SwiftJLS.CodecError {
                try require(error.category == .storageUnavailable, "Adapter error category changed.")
            }
            let maximum = precision == 12 ? 4095 : 65535
            var writeAddress: UInt = 0 // test-only equality; never dereferenced or logged
            let image = try destination.write { bytes in
                writeAddress = UInt(bitPattern: bytes.baseAddress)
                for y in 0..<3 {
                    for x in 0..<5 {
                        let value = (x + y) % 2 == 0 ? maximum : (x + y * 5)
                        let at = 2 + y * 14 + x * 2
                        bytes[at] = UInt8(value & 255)
                        bytes[at + 1] = UInt8(value >> 8)
                    }
                }
            }
            let jls = try SwiftJLS.Image(descriptor: jlsDescriptor,
                storage: SwiftJLSReadAdapter(underlying: image.storage))
            let jxl = try SwiftJXL.Image(descriptor: .greyscale16(width: 5, height: 3,
                meaningfulBits: precision, rowBytes: 14, offset: 2),
                storage: SwiftJXLReadAdapter(underlying: image.storage))
            let jli = try SwiftJLI.Image(descriptor: .greyscale16(width: 5, height: 3,
                meaningfulBits: precision, rowBytes: 14, offset: 2),
                storage: SwiftJLIReadAdapter(underlying: image.storage))
            try require([jls.storage.allocationID, jxl.storage.allocationID, jli.storage.allocationID]
                .allSatisfy { $0 == owner.allocationID }, "Allocation identity changed across modules.")
            let expectedAddress = writeAddress
            let check: @Sendable (UnsafeRawBufferPointer) throws -> Void = { bytes in
                try require(UInt(bitPattern: bytes.baseAddress) == expectedAddress, "A pixel copy occurred.")
                try require(bytes.count == 44 && bytes[0] == 0 && bytes[1] == 0, "Capacity or prefix changed.")
                for y in 0..<3 {
                    for x in 0..<5 {
                        let at = 2 + y * 14 + x * 2
                        let value = Int(bytes[at]) | Int(bytes[at + 1]) << 8
                        let expected = (x + y) % 2 == 0 ? maximum : (x + y * 5)
                        try require(value == expected, "Logical sample changed.")
                    }
                    for padding in 10..<14 {
                        try require(bytes[2 + y * 14 + padding] == 0, "Padding was not initialised.")
                    }
                }
            }
            try image.storage.withUnsafeBytes(check)
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try jls.storage.withUnsafeBytes(check) }
                group.addTask { try jxl.storage.withUnsafeBytes(check) }
                group.addTask { try jli.storage.withUnsafeBytes(check) }
                try await group.waitForAll()
            }
            let counts = metrics.counts.withLock { $0 }
            try require(counts.allocations == 1 && counts.writes == 1 && counts.reads >= 4,
                "Expected owner allocation/borrow instrumentation was not observed.")
            print("PASS: \(precision)-in-16, 5x3 padded storage, 1 pixel allocation, 0 adapter copy bytes, shared identity, concurrent reads, second writer rejected")
        }
        // The opposite adapter direction actually writes through a local lease mapping.
        let metrics = Metrics()
        let owner = try InstrumentedOwner(byteCount: 2, metrics: metrics)
        let destination = try SwiftJLS.ImageDestination(descriptor: .greyscale16(width: 1, height: 1),
            storage: JLSWriteAdapter(owner))
        let image = try destination.write { $0[0] = 255; $0[1] = 255 }
        try require(image.storage.allocationID == owner.allocationID, "Writable adapter changed identity.")
        try image.storage.withUnsafeBytes { try require($0[0] == 255 && $0[1] == 255, "Mapped write failed.") }
        print("PASS: local write-lease mapping and exact UInt16 maximum")
    }
}
