// SPDX-License-Identifier: MIT
import Foundation
import Synchronization
import Testing
import SwiftJ2K

@Suite("Exclusive storage lifecycle")
struct StorageContractTests {
    @Test("One provider rejects overlapping writers, including a reentrant borrow")
    func overlappingWriters() throws {
        let owner = try OwnedImageStorage(byteCount: 64)
        let lease = try owner.reserveWrite()
        expectCodecError(.storageUnavailable) { try owner.reserveWrite() }
        try lease.withUnsafeMutableBytes { bytes in
            bytes[0] = 0x39
            expectCodecError(.storageUnavailable) {
                try lease.withUnsafeMutableBytes { nested in nested[0] = 0xff }
            }
            expectCodecError(.storageUnavailable) { try owner.reserveWrite() }
            expectCodecError(.storageUnavailable) { try lease.finish() }
            #expect(bytes[0] == 0x39)
        }
        let sealed = try lease.finish()
        #expect(sealed.allocationID == owner.allocationID)
        #expect(sealed.byteCount == owner.byteCount)
        #expect(try sealed.withUnsafeBytes { $0[0] } == 0x39)
        expectCodecError(.storageUnavailable) {
            try lease.withUnsafeMutableBytes { $0[0] = 0xff }
        }
        expectCodecError(.storageUnavailable) { try lease.finish() }
        expectCodecError(.storageUnavailable) { try owner.reserveWrite() }
    }

    @Test("Aborted storage never produces a readable image")
    func abortedStorage() throws {
        let owner = try OwnedImageStorage(byteCount: 8)
        let lease = try owner.reserveWrite()
        try lease.withUnsafeMutableBytes { $0[0] = 0x3a }
        lease.abort()
        lease.abort() // Cleanup is idempotent.
        expectCodecError(.storageUnavailable) { try lease.finish() }
        expectCodecError(.storageUnavailable) { try owner.reserveWrite() }
        expectCodecError(.storageUnavailable) {
            try lease.withUnsafeMutableBytes { $0[0] = 0xff }
        }
    }

    @Test("Dropping an unfinished lease invalidates its allocation")
    func unfinishedLeaseDoesNotRestoreAvailability() throws {
        let owner = try OwnedImageStorage(byteCount: 8)
        do {
            let lease = try owner.reserveWrite()
            try lease.withUnsafeMutableBytes { $0[0] = 0x11 }
        }
        expectCodecError(.storageUnavailable) { try owner.reserveWrite() }
    }

    @Test("A throwing write cannot publish a partial frame")
    func throwingBorrowInvalidatesStorage() throws {
        enum Expected: Error, Equatable { case interrupted }
        let owner = try OwnedImageStorage(byteCount: 8)
        let lease = try owner.reserveWrite()
        #expect(throws: Expected.interrupted) {
            try lease.withUnsafeMutableBytes { bytes in
                bytes[0] = 0x77
                throw Expected.interrupted
            }
        }
        expectCodecError(.storageUnavailable) { try lease.finish() }
        expectCodecError(.storageUnavailable) { try owner.reserveWrite() }
    }

    @Test("Sealed readers retain the sole allocation after caller release")
    func earlyOwnerRelease() throws {
        weak var observedOwner: OwnedImageStorage?
        var reader: (any ReadOnlyImageStorage)?
        do {
            let owner = try OwnedImageStorage(byteCount: 8)
            observedOwner = owner
            let lease = try owner.reserveWrite()
            try lease.withUnsafeMutableBytes { $0[7] = 0x61 }
            reader = try lease.finish()
        }
        #expect(observedOwner != nil)
        #expect(try reader?.withUnsafeBytes { $0[7] } == 0x61)
        reader = nil
        #expect(observedOwner == nil)
    }

    @Test("Read access is unavailable until sealing succeeds")
    func readBeforeSeal() throws {
        let owner = try OwnedImageStorage(byteCount: 8)
        expectCodecError(.storageUnavailable) { try owner.readOnlyStorage() }
        let lease = try owner.reserveWrite()
        expectCodecError(.storageUnavailable) { try owner.readOnlyStorage() }
        _ = try lease.finish()
        let reader = try owner.readOnlyStorage()
        #expect(try reader.withUnsafeBytes { $0[0] } == 0)
    }

    @Test("Aborting inside an active borrow retains its allocation until scope exit")
    func abortInsideBorrow() throws {
        let owner = try OwnedImageStorage(byteCount: 8)
        let lease = try owner.reserveWrite()
        expectCodecError(.storageUnavailable) {
            try lease.withUnsafeMutableBytes { bytes in
                bytes[0] = 0x40
                lease.abort()
                // The pointer is still in its original scope; invalidation must
                // prevent publication, not free memory while this scope runs.
                bytes[7] = 0x62
                #expect(bytes[0] == 0x40)
                #expect(bytes[7] == 0x62)
                expectCodecError(.storageUnavailable) { try owner.reserveWrite() }
            }
        }
        expectCodecError(.storageUnavailable) { try lease.finish() }
        expectCodecError(.storageUnavailable) { try owner.readOnlyStorage() }
    }

    @Test("Cancellation remains CancellationError and invalidates partial storage")
    func cancelledBorrow() throws {
        let owner = try OwnedImageStorage(byteCount: 8)
        let lease = try owner.reserveWrite()
        #expect(throws: CancellationError.self) {
            try lease.withUnsafeMutableBytes { bytes in
                bytes[0] = 0x29
                throw CancellationError()
            }
        }
        expectCodecError(.storageUnavailable) { try lease.finish() }
        expectCodecError(.storageUnavailable) { try owner.readOnlyStorage() }
    }

    @Test("An exception in a reader does not invalidate the sealed allocation")
    func throwingReader() throws {
        enum Expected: Error, Equatable { case interrupted }
        let owner = try OwnedImageStorage(byteCount: 8)
        let lease = try owner.reserveWrite()
        try lease.withUnsafeMutableBytes { $0[0] = 0x71 }
        let reader = try lease.finish()
        #expect(throws: Expected.interrupted) {
            try reader.withUnsafeBytes { _ in throw Expected.interrupted }
        }
        #expect(try reader.withUnsafeBytes { $0[0] } == 0x71)
    }

    @Test("Different adapters share one provider's writer exclusion")
    func adapterWriterExclusion() throws {
        let owner = try OwnedImageStorage(byteCount: 8)
        let first = ForwardingWriteOwner(owner)
        let second = ForwardingWriteOwner(owner)
        #expect(first.allocationID == second.allocationID)
        let lease = try first.reserveWrite()
        expectCodecError(.storageUnavailable) { try second.reserveWrite() }
        try lease.withUnsafeMutableBytes { $0[0] = 0x22 }
        let reader = try lease.finish()
        #expect(reader.allocationID == owner.allocationID)
        #expect(try reader.withUnsafeBytes { $0[0] } == 0x22)
    }

    @Test("A published view forwards allocation identity and owns its adapter")
    func adapterLifetime() throws {
        let counter = ReleaseCounter()
        var reader: (any ReadOnlyImageStorage)?
        var expectedID: UUID?
        do {
            let owner = try OwnedImageStorage(byteCount: 8)
            let lease = try owner.reserveWrite()
            try lease.withUnsafeMutableBytes { $0[1] = 0x8a }
            expectedID = owner.allocationID
            reader = ForwardingReadOwner(try lease.finish(), releases: counter)
        }
        #expect(counter.value == 0)
        #expect(reader?.allocationID == expectedID)
        #expect(try reader?.withUnsafeBytes { $0[1] } == 0x8a)
        reader = nil
        #expect(counter.value == 1)
    }

    @Test("Many concurrent readers observe immutable bytes")
    func concurrentReaders() async throws {
        let owner = try OwnedImageStorage(byteCount: 64)
        let lease = try owner.reserveWrite()
        try lease.withUnsafeMutableBytes { bytes in
            for index in 0..<64 { bytes[index] = UInt8(index) }
        }
        let reader = try lease.finish()
        try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<32 {
                group.addTask {
                    var observed = 0
                    for _ in 0..<64 {
                        observed += try reader.withUnsafeBytes { bytes in
                            bytes.reduce(0) { $0 + Int($1) }
                        }
                    }
                    return observed
                }
            }
            for try await sum in group { #expect(sum == 129_024) }
        }
        #expect(try reader.withUnsafeBytes { $0[63] } == 63)
    }
}

private final class ReleaseCounter: Sendable {
    private let count = Mutex(0)
    var value: Int { count.withLock { $0 } }
    func record() { count.withLock { $0 += 1 } }
}

private final class ForwardingReadOwner: ReadOnlyImageStorage {
    private let owner: any ReadOnlyImageStorage
    private let releases: ReleaseCounter
    init(_ owner: any ReadOnlyImageStorage, releases: ReleaseCounter) {
        self.owner = owner
        self.releases = releases
    }
    var byteCount: Int { owner.byteCount }
    var allocationID: UUID { owner.allocationID }
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
        try owner.withUnsafeBytes(body)
    }
    deinit { releases.record() }
}

private final class ForwardingWriteOwner: WritableImageStorage {
    private let owner: any WritableImageStorage
    init(_ owner: any WritableImageStorage) { self.owner = owner }
    var byteCount: Int { owner.byteCount }
    var allocationID: UUID { owner.allocationID }
    func reserveWrite() throws -> any ImageWriteLease { try owner.reserveWrite() }
}
