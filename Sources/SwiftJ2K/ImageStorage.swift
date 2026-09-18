// SPDX-License-Identifier: MIT
import Foundation
import Synchronization

#if canImport(Darwin)
import Darwin
#elseif os(Linux)
import Glibc
#else
#error("Swift Image Compression Suite currently supports Apple platforms and Linux")
#endif

/// An owning, permanently sealed storage provider. A borrow is synchronous and cannot span await.
/// Unsafe caller duty: never return, retain, mutate or otherwise escape the supplied pointer.
/// Conforming providers must retain the actual allocation and reject reads before sealing.
public protocol ReadOnlyImageStorage: AnyObject, Sendable {
    var byteCount: Int { get }
    var allocationID: UUID { get }
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) throws -> R
}

/// Advanced providers enforce the same exclusive lifecycle across every alias and module adapter.
/// Capacity and allocation identity remain constant. Providers initialise all exported bytes.
public protocol WritableImageStorage: AnyObject, Sendable {
    var byteCount: Int { get }
    var allocationID: UUID { get }
    func reserveWrite() throws -> any ImageWriteLease
}

/// One exclusive operation on retained storage. A lease cannot authorise concurrent mutable borrows.
/// A throwing mutable borrow invalidates the lease. `finish` rejects active borrows. `abort` is
/// idempotent, prevents publication, and retains memory until all active borrows have ended.
/// Destroying an unsealed lease must abort it. Unsafe pointers must not escape their callback.
public protocol ImageWriteLease: AnyObject, Sendable {
    var byteCount: Int { get }
    var allocationID: UUID { get }
    func withUnsafeMutableBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) throws -> R
    func finish() throws -> any ReadOnlyImageStorage
    func abort()
}

/// The sole unchecked bridge: an allocation, not a publicly shareable pointer or mutable provider.
/// Safety proof: its address/capacity never change; the only owner calls mutable access after
/// reserving its Mutex-protected exclusive borrow. Reads occur only after permanent sealing.
/// Callbacks run outside the lock but retain the owner/lease until they return. Abort cannot free
/// or reuse bytes. calloc initialises padding and free runs exactly once after the final owner.
/// External unsafe callbacks retain the usual no-escape/no-mutation-after-borrow obligations.
private final class RawAllocation: @unchecked Sendable {
    let pointer: UnsafeMutableRawPointer
    let byteCount: Int

    init(byteCount: Int) throws {
        guard let allocation = calloc(1, byteCount) else {
            throw CodecError(.storageUnavailable, context: "pixel allocation failed")
        }
        pointer = allocation
        self.byteCount = byteCount
    }

    deinit { free(pointer) }
}

/// Safe zero-initialised owning allocation for the shared greyscale16 profile.
/// The provider and all leases use checked Sendable conformance; mutable state lives in Mutex.
public final class OwnedImageStorage: WritableImageStorage, Sendable {
    public enum State: String, Sendable { case available, writing, sealed, invalid }

    private struct Lifecycle {
        var state: State = .available
        var token: UUID?
        var borrowActive = false
    }

    public let byteCount: Int
    public let allocationID: UUID
    private let allocation: RawAllocation
    private let lifecycle = Mutex(Lifecycle())

    public var state: State { lifecycle.withLock { $0.state } }

    public init(byteCount: Int, limits: ResourceLimits = .default) throws {
        try limits.validatePixelByteCount(byteCount)
        allocation = try RawAllocation(byteCount: byteCount)
        self.byteCount = byteCount
        allocationID = UUID()
    }

    public func reserveWrite() throws -> any ImageWriteLease {
        let token = UUID()
        try lifecycle.withLock { state in
            guard state.state == .available else {
                throw CodecError(.storageUnavailable, context: "storage is already reserved or terminal")
            }
            state.token = token
            state.state = .writing
        }
        return WriteLease(owner: self, token: token)
    }

    /// Returns an immutable interface only after sealing; it exposes no writer or raw adoption API.
    public func readOnlyStorage() throws -> any ReadOnlyImageStorage {
        try lifecycle.withLock { state in
            guard state.state == .sealed else {
                throw CodecError(.storageUnavailable, context: "storage is not sealed")
            }
        }
        return SealedStorage(owner: self)
    }

    private func withMutableBytes<R>(token: UUID,
        _ body: (UnsafeMutableRawBufferPointer) throws -> R) throws -> R {
        try lifecycle.withLock { state in
            guard state.state == .writing, state.token == token, !state.borrowActive else {
                throw CodecError(.storageUnavailable, context: "write lease unavailable or borrow overlaps")
            }
            state.borrowActive = true
        }
        defer { lifecycle.withLock { $0.borrowActive = false } }
        do {
            let result = try body(UnsafeMutableRawBufferPointer(start: allocation.pointer, count: byteCount))
            try lifecycle.withLock { state in
                guard state.state == .writing, state.token == token else {
                    throw CodecError(.storageUnavailable, context: "storage invalidated during write borrow")
                }
            }
            return result
        } catch {
            abort(token: token)
            throw error
        }
    }

    private func finish(token: UUID) throws -> any ReadOnlyImageStorage {
        try lifecycle.withLock { state in
            guard state.state == .writing, state.token == token, !state.borrowActive else {
                throw CodecError(.storageUnavailable, context: "cannot seal unavailable or borrowed storage")
            }
            state.state = .sealed
        }
        return SealedStorage(owner: self)
    }

    private func abort(token: UUID) {
        lifecycle.withLock { state in
            if state.state == .writing && state.token == token { state.state = .invalid }
        }
    }

    private func withReadBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
        try lifecycle.withLock { state in
            guard state.state == .sealed else {
                throw CodecError(.storageUnavailable, context: "storage is not sealed")
            }
        }
        return try body(UnsafeRawBufferPointer(start: allocation.pointer, count: byteCount))
    }

    private final class WriteLease: ImageWriteLease, Sendable {
        let owner: OwnedImageStorage
        let token: UUID
        var byteCount: Int { owner.byteCount }
        var allocationID: UUID { owner.allocationID }

        init(owner: OwnedImageStorage, token: UUID) { self.owner = owner; self.token = token }
        func withUnsafeMutableBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) throws -> R {
            try owner.withMutableBytes(token: token, body)
        }
        func finish() throws -> any ReadOnlyImageStorage { try owner.finish(token: token) }
        func abort() { owner.abort(token: token) }
        deinit { owner.abort(token: token) }
    }

    private final class SealedStorage: ReadOnlyImageStorage, Sendable {
        let owner: OwnedImageStorage
        var byteCount: Int { owner.byteCount }
        var allocationID: UUID { owner.allocationID }

        init(owner: OwnedImageStorage) { self.owner = owner }
        func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
            try owner.withReadBytes(body)
        }
    }
}
