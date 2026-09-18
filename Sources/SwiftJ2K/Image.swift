// SPDX-License-Identifier: MIT
import Foundation

public struct Image: Sendable {
    public let descriptor: ImageDescriptor
    public let storage: any ReadOnlyImageStorage
    public let metadata: ImageMetadata

    public init(descriptor: ImageDescriptor, storage: any ReadOnlyImageStorage,
                metadata: ImageMetadata = .empty, limits: ResourceLimits = .default) throws {
        try validateStorage(descriptor: descriptor, byteCount: storage.byteCount, limits: limits)
        try validateMetadata(descriptor: descriptor, metadata: metadata,
                             storageBytes: storage.byteCount, limits: limits)
        // The provider must be permanently sealed; the borrow also verifies actual accessible size.
        try storage.withUnsafeBytes { bytes in
            try validateBorrow(bytes, expectedByteCount: storage.byteCount)
        }
        self.descriptor = descriptor
        self.storage = storage
        self.metadata = metadata
    }

    /// Reads an exact unsigned sample without exposing a pointer. No normalisation or truncation.
    public func sample(x: Int, y: Int) throws -> UInt16 {
        let offset = try descriptor.sampleOffset(x: x, y: y)
        return try storage.withUnsafeBytes { bytes in
            try validateBorrow(bytes, expectedByteCount: storage.byteCount)
            guard offset <= bytes.count - 2 else {
                throw CodecError(.storageUnavailable, context: "provider capacity changed")
            }
            let value = UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
            guard value <= descriptor.maximumSample else {
                throw CodecError(.invalidArgument, context: "sample exceeds meaningful precision")
            }
            return value
        }
    }
}

/// Reserves its provider immediately on construction. Failure/abort is terminal, with no reuse.
/// Scoped writes are synchronous; the destination is the Sendable owner across asynchronous work.
public final class ImageDestination: Sendable {
    public let descriptor: ImageDescriptor
    public let storage: any WritableImageStorage
    private let lease: any ImageWriteLease
    private let limits: ResourceLimits

    public var allocationID: UUID { lease.allocationID }
    public var byteCount: Int { lease.byteCount }

    public init(descriptor: ImageDescriptor, storage: any WritableImageStorage,
                limits: ResourceLimits = .default) throws {
        try validateStorage(descriptor: descriptor, byteCount: storage.byteCount, limits: limits)
        try validateMetadata(descriptor: descriptor, metadata: .empty,
                             storageBytes: storage.byteCount, limits: limits)
        let reserved = try storage.reserveWrite()
        guard reserved.byteCount == storage.byteCount, reserved.allocationID == storage.allocationID else {
            reserved.abort()
            throw CodecError(.storageUnavailable, context: "write lease does not match provider")
        }
        self.descriptor = descriptor
        self.storage = storage
        lease = reserved
        self.limits = limits
    }

    public static func allocate(descriptor: ImageDescriptor,
                                limits: ResourceLimits = .default) throws -> ImageDestination {
        try Task.checkCancellation()
        try validateStorage(descriptor: descriptor, byteCount: descriptor.requiredByteCount, limits: limits)
        try validateMetadata(descriptor: descriptor, metadata: .empty,
                             storageBytes: descriptor.requiredByteCount, limits: limits)
        let storage = try OwnedImageStorage(byteCount: descriptor.requiredByteCount, limits: limits)
        return try ImageDestination(descriptor: descriptor, storage: storage, limits: limits)
    }

    /// Advanced unsafe access. Do not retain/return the pointer, use it after return, or cross await.
    /// A throwing callback invalidates this destination; callbacks execute outside internal locks.
    public func withUnsafeMutableBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) throws -> R {
        try lease.withUnsafeMutableBytes { bytes in
            try validateBorrow(UnsafeRawBufferPointer(bytes), expectedByteCount: lease.byteCount)
            return try body(bytes)
        }
    }

    /// Writes a range-checked sample without pointer access; untouched samples/padding remain zero.
    public func setSample(_ value: UInt16, x: Int, y: Int) throws {
        let offset = try descriptor.sampleOffset(x: x, y: y)
        guard value <= descriptor.maximumSample else {
            throw CodecError(.invalidArgument, context: "sample exceeds meaningful precision")
        }
        try withUnsafeMutableBytes { bytes in
            guard offset <= bytes.count - 2 else {
                throw CodecError(.storageUnavailable, context: "provider capacity changed")
            }
            bytes[offset] = UInt8(truncatingIfNeeded: value)
            bytes[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
        }
    }

    /// Permanently publishes immutable storage. All producer work must have joined before calling.
    public func seal(metadata: ImageMetadata = .empty) throws -> Image {
        do {
            try validateMetadata(descriptor: descriptor, metadata: metadata,
                                 storageBytes: lease.byteCount, limits: limits)
            let sealed = try lease.finish()
            guard sealed.allocationID == lease.allocationID, sealed.byteCount == lease.byteCount else {
                throw CodecError(.storageUnavailable, context: "sealed storage does not match write lease")
            }
            return try Image(descriptor: descriptor, storage: sealed, metadata: metadata, limits: limits)
        } catch {
            lease.abort()
            throw error
        }
    }

    public func abort() { lease.abort() }
    deinit { lease.abort() }
}

private func validateStorage(descriptor: ImageDescriptor, byteCount: Int,
                             limits: ResourceLimits) throws {
    guard byteCount >= descriptor.requiredByteCount else {
        throw CodecError(.incompatibleImageLayout, context: "allocation is too short")
    }
    guard descriptor.width <= limits.maximumDimension, descriptor.height <= limits.maximumDimension,
          try checkedMultiply(descriptor.width, descriptor.height) <= limits.maximumPixels else {
        throw CodecError(.resourceLimitExceeded, context: "image geometry budget")
    }
    try limits.validatePixelByteCount(byteCount)
}

private func validateBorrow(_ bytes: UnsafeRawBufferPointer, expectedByteCount: Int) throws {
    guard bytes.count == expectedByteCount, let address = bytes.baseAddress else {
        throw CodecError(.storageUnavailable, context: "provider capacity or base address changed")
    }
    guard UInt(bitPattern: address).isMultiple(of: 2) else {
        throw CodecError(.incompatibleImageLayout, context: "provider base address is unaligned")
    }
}

private func validateMetadata(descriptor: ImageDescriptor, metadata: ImageMetadata,
                              storageBytes: Int, limits: ResourceLimits) throws {
    let iccBytes = descriptor.colour.iccData?.count ?? 0
    let metadataBytes = try checkedAdd(metadata.byteCount, iccBytes)
    let totalBytes = try checkedAdd(storageBytes, metadataBytes)
    guard iccBytes <= limits.maximumICCBytes, metadataBytes <= limits.maximumMetadataBytes,
          totalBytes <= limits.maximumTotalBytes else {
        throw CodecError(.resourceLimitExceeded, context: "retained image and metadata budget")
    }
}
