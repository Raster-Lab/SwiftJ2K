// SPDX-License-Identifier: MIT
import Dispatch
import Foundation
import Synchronization
import Testing
import SwiftJ2K

@Suite("Concurrent exclusive-borrow boundaries")
struct ConcurrentWriteTests {
    @Test("A second thread cannot write, seal or replace an active producer")
    func activeProducerExcludesWriters() throws {
        let owner = try OwnedImageStorage(byteCount: 16)
        let lease = try owner.reserveWrite()
        let entered = DispatchSemaphore(value: 0)
        let resume = DispatchSemaphore(value: 0)
        let done = DispatchSemaphore(value: 0)
        let result = BorrowCompletion()
        DispatchQueue.global().async {
            defer { done.signal() }
            do {
                try lease.withUnsafeMutableBytes { bytes in
                    bytes[0] = 0x31
                    entered.signal()
                    guard resume.wait(timeout: .now() + 10) == .success else {
                        throw CodecError(.internalFailure, context: "test producer timeout")
                    }
                    bytes[15] = 0x79
                }
                result.record(success: true)
            } catch { result.record(success: false) }
        }
        let producerStarted = entered.wait(timeout: .now() + 10) == .success
        #expect(producerStarted)
        if producerStarted {
            expectCodecError(.storageUnavailable) {
                try lease.withUnsafeMutableBytes { $0[0] = 0xff }
            }
            expectCodecError(.storageUnavailable) { try lease.finish() }
            expectCodecError(.storageUnavailable) { try owner.reserveWrite() }
        }
        resume.signal()
        #expect(done.wait(timeout: .now() + 10) == .success)
        #expect(result.succeeded == true)
        let reader = try lease.finish()
        #expect(try reader.withUnsafeBytes { $0[0] } == 0x31)
        #expect(try reader.withUnsafeBytes { $0[15] } == 0x79)
    }

    @Test("Independent allocations have different identities")
    func allocationIdentityDistinguishesOwners() throws {
        let first = try OwnedImageStorage(byteCount: 8)
        let second = try OwnedImageStorage(byteCount: 8)
        #expect(first.allocationID != second.allocationID)
        let lease = try first.reserveWrite()
        let sealed = try lease.finish()
        #expect(sealed.allocationID == first.allocationID)
    }
}

private final class BorrowCompletion: Sendable {
    private let result = Mutex<Bool?>(nil)
    var succeeded: Bool? { result.withLock { $0 } }
    func record(success: Bool) { result.withLock { $0 = success } }
}
