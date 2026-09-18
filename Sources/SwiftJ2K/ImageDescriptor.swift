// SPDX-License-Identifier: MIT
import Foundation

public enum SampleType: String, Sendable, Equatable {
    case unsignedInteger, signedInteger, floatingPoint
}

public enum ByteOrder: String, Sendable, Equatable { case littleEndian, bigEndian }
public enum ComponentRole: String, Sendable, Equatable { case greyscale, red, green, blue, alpha, uninterpreted }
public enum AlphaMode: String, Sendable, Equatable { case none, straight, premultiplied }

public struct ColourDescription: Sendable, Equatable {
    public enum Interpretation: String, Sendable { case greyscale, sRGB, unknown }
    public let interpretation: Interpretation
    public let iccData: Data?
    public static let greyscale = ColourDescription(interpretation: .greyscale, iccData: nil)
    public static let unknown = ColourDescription(interpretation: .unknown, iccData: nil)

    public init(interpretation: Interpretation, iccData: Data? = nil) {
        self.interpretation = interpretation
        self.iccData = iccData
    }
}

/// Byte capacity starts at `offset`; it may exclude unused padding after the last row.
/// Milestone 1 validates the common single-component, unsigned 16-bit layout only.
public struct PlaneDescriptor: Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let components: [Int]
    public let offset: Int
    public let sampleStride: Int
    public let pixelStride: Int
    public let rowBytes: Int
    public let byteCount: Int
    public let requiredByteCount: Int

    public init(width: Int, height: Int, components: [Int] = [0], offset: Int = 0,
                sampleStride: Int = 2, pixelStride: Int = 2, rowBytes: Int,
                byteCount: Int) throws {
        guard width > 0, height > 0, offset >= 0, rowBytes > 0, byteCount > 0 else {
            throw CodecError(.invalidArgument, context: "invalid plane geometry")
        }
        guard components == [0], sampleStride == 2, pixelStride == 2,
              offset.isMultiple(of: 2), rowBytes.isMultiple(of: 2) else {
            throw CodecError(.incompatibleImageLayout, context: "requires aligned greyscale16 plane")
        }
        let rowPayload = try checkedMultiply(width, 2)
        guard rowBytes >= rowPayload else {
            throw CodecError(.incompatibleImageLayout, context: "row stride is smaller than payload")
        }
        let lastRowOffset = try checkedMultiply(height - 1, rowBytes)
        let lastByte = try checkedAdd(lastRowOffset, rowPayload)
        guard lastByte <= byteCount else {
            throw CodecError(.incompatibleImageLayout, context: "plane capacity is too short")
        }
        self.width = width
        self.height = height
        self.components = components
        self.offset = offset
        self.sampleStride = sampleStride
        self.pixelStride = pixelStride
        self.rowBytes = rowBytes
        self.byteCount = byteCount
        requiredByteCount = try checkedAdd(offset, byteCount)
    }
}

public struct ImageDescriptor: Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let sampleType: SampleType
    public let storageBits: Int
    public let meaningfulBits: Int
    public let byteOrder: ByteOrder
    public let components: [ComponentRole]
    public let colour: ColourDescription
    public let alpha: AlphaMode
    public let planes: [PlaneDescriptor]
    public let requiredByteCount: Int

    public init(width: Int, height: Int, sampleType: SampleType = .unsignedInteger,
                storageBits: Int = 16, meaningfulBits: Int = 16,
                byteOrder: ByteOrder = .littleEndian, components: [ComponentRole] = [.greyscale],
                colour: ColourDescription = .greyscale, alpha: AlphaMode = .none,
                planes: [PlaneDescriptor], limits: ResourceLimits = .default) throws {
        guard width > 0, height > 0, meaningfulBits > 0, meaningfulBits <= storageBits else {
            throw CodecError(.invalidArgument, context: "invalid dimensions or precision")
        }
        guard width <= limits.maximumDimension, height <= limits.maximumDimension else {
            throw CodecError(.resourceLimitExceeded, context: "dimension budget")
        }
        let pixels = try checkedMultiply(width, height)
        guard pixels <= limits.maximumPixels else {
            throw CodecError(.resourceLimitExceeded, context: "pixel count budget")
        }
        guard sampleType == .unsignedInteger, storageBits == 16,
              byteOrder == .littleEndian, components == [.greyscale],
              colour.interpretation == .greyscale, alpha == .none else {
            throw CodecError(.unsupportedFeature, context: "Milestone 1 supports unsigned greyscale16 storage")
        }
        guard planes.count == 1, let plane = planes.first,
              plane.width == width, plane.height == height else {
            throw CodecError(.incompatibleImageLayout, context: "requires one full-size plane")
        }
        let iccBytes = colour.iccData?.count ?? 0
        guard iccBytes <= limits.maximumICCBytes, iccBytes <= limits.maximumMetadataBytes else {
            throw CodecError(.resourceLimitExceeded, context: "ICC budget")
        }
        try limits.validatePixelByteCount(plane.requiredByteCount)
        self.width = width
        self.height = height
        self.sampleType = sampleType
        self.storageBits = storageBits
        self.meaningfulBits = meaningfulBits
        self.byteOrder = byteOrder
        self.components = components
        self.colour = colour
        self.alpha = alpha
        self.planes = planes
        requiredByteCount = plane.requiredByteCount
    }

    public static func greyscale16(width: Int, height: Int, meaningfulBits: Int = 16,
                                   rowBytes: Int? = nil, offset: Int = 0,
                                   limits: ResourceLimits = .default) throws -> ImageDescriptor {
        guard width > 0, height > 0 else {
            throw CodecError(.invalidArgument, context: "invalid dimensions")
        }
        let stride = try rowBytes ?? checkedMultiply(width, 2)
        let capacity = try checkedMultiply(stride, height)
        let plane = try PlaneDescriptor(width: width, height: height, offset: offset,
                                        rowBytes: stride, byteCount: capacity)
        return try ImageDescriptor(width: width, height: height, meaningfulBits: meaningfulBits,
                                   planes: [plane], limits: limits)
    }

    internal func sampleOffset(x: Int, y: Int) throws -> Int {
        guard x >= 0, x < width, y >= 0, y < height, let plane = planes.first else {
            throw CodecError(.invalidArgument, context: "sample coordinates out of range")
        }
        // All products and sums were bounded by validated plane geometry at construction.
        return plane.offset + y * plane.rowBytes + x * plane.pixelStride
    }

    internal var maximumSample: UInt16 { UInt16((UInt32(1) << meaningfulBits) - 1) }
}

/// Bounded, immutable ancillary metadata. Required colour/sample meaning belongs in the descriptor.
public struct ImageMetadata: Sendable, Equatable {
    public let entries: [String: Data]
    public let byteCount: Int
    public static let empty = ImageMetadata()

    private init() { entries = [:]; byteCount = 0 }

    public init(entries: [String: Data], limits: ResourceLimits = .default) throws {
        var bytes = 0
        for (key, value) in entries {
            guard !key.isEmpty else { throw CodecError(.invalidArgument, context: "empty metadata key") }
            bytes = try checkedAdd(bytes, key.utf8.count)
            bytes = try checkedAdd(bytes, value.count)
            guard bytes <= limits.maximumMetadataBytes else {
                throw CodecError(.resourceLimitExceeded, context: "metadata budget")
            }
        }
        self.entries = entries
        byteCount = bytes
    }
}
