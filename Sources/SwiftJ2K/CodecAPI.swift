// SPDX-License-Identifier: MIT
import Foundation

public enum CompressionMode: Sendable, Equatable {
    case lossless
    case nearLossless(maximumAbsoluteError: Int)
    case lossy
}

public enum EncodedFormat: String, Sendable, Equatable, CaseIterable {
    case jpeg2000, htj2k, jpegLS, jpegXL, jpeg
}

public enum Backend: String, Sendable, Equatable { case scalarCPU, metal, accelerate }
public enum ExecutionPolicy: Sendable, Equatable {
    case automatic, scalarCPU, preferred(Backend), required(Backend)
}
public enum CopyPolicy: String, Sendable, Equatable { case requireSharedStorage, allowCopy }
public enum MetadataPolicy: String, Sendable, Equatable { case preserve, discardAncillary }
public enum Fidelity: String, Sendable, Equatable { case exactSamples, boundedSampleError, lossySamples, originalBitstream }
public enum ProcessingPath: String, Sendable, Equatable { case samples, coefficients, jpegReconstruction }

public struct ProgressUpdate: Sendable, Equatable {
    public let phase: String
    public let completedUnits: Int
    public let totalUnits: Int?
    public let isComplete: Bool

    public init(phase: String, completedUnits: Int, totalUnits: Int? = nil,
                isComplete: Bool = false) throws {
        guard !phase.isEmpty, completedUnits >= 0,
              totalUnits.map({ $0 >= completedUnits }) ?? true else {
            throw CodecError(.invalidArgument, context: "invalid progress")
        }
        self.phase = phase
        self.completedUnits = completedUnits
        self.totalUnits = totalUnits
        self.isComplete = isComplete
    }
}

public typealias ProgressHandler = @Sendable (ProgressUpdate) -> Void

public struct CopyEvent: Sendable, Equatable {
    public let reason: String
    public let bytesMoved: Int
    public let sourceLayout: String
    public let destinationLayout: String

    public init(reason: String, bytesMoved: Int, sourceLayout: String,
                destinationLayout: String) throws {
        guard bytesMoved >= 0 else { throw CodecError(.invalidArgument, context: "negative copy count") }
        self.reason = reason
        self.bytesMoved = bytesMoved
        self.sourceLayout = sourceLayout
        self.destinationLayout = destinationLayout
    }
}

/// Measurements remain nil when unobserved. No Milestone 1 codec operation fabricates a report.
public struct OperationReport: Sendable {
    public let backend: Backend
    public let fallbackReason: String?
    public let fidelity: Fidelity
    public let processingPath: ProcessingPath
    public let copyEvents: [CopyEvent]
    public let pixelAllocationCount: Int?
    public let peakPixelBytes: Int?
    public let peakWorkspaceBytes: Int?
    public let elapsed: Duration?
    public let discardedMetadataKeys: [String]

    public init(backend: Backend, fallbackReason: String? = nil, fidelity: Fidelity,
                processingPath: ProcessingPath, copyEvents: [CopyEvent] = [],
                pixelAllocationCount: Int? = nil, peakPixelBytes: Int? = nil,
                peakWorkspaceBytes: Int? = nil, elapsed: Duration? = nil,
                discardedMetadataKeys: [String] = []) throws {
        guard [pixelAllocationCount, peakPixelBytes, peakWorkspaceBytes].allSatisfy({ $0.map({ $0 >= 0 }) ?? true }),
              elapsed.map({ $0 >= .zero }) ?? true else {
            throw CodecError(.invalidArgument, context: "invalid report measurement")
        }
        self.backend = backend
        self.fallbackReason = fallbackReason
        self.fidelity = fidelity
        self.processingPath = processingPath
        self.copyEvents = copyEvents
        self.pixelAllocationCount = pixelAllocationCount
        self.peakPixelBytes = peakPixelBytes
        self.peakWorkspaceBytes = peakWorkspaceBytes
        self.elapsed = elapsed
        self.discardedMetadataKeys = discardedMetadataKeys
    }
}

public struct CodecCapabilities: Sendable, Equatable {
    public let supportsEncoding: Bool
    public let supportsDecoding: Bool
    public let supportsInspection: Bool
    public let formats: [EncodedFormat]
    public let compressionModes: [CompressionMode]
    public let sampleTypes: [SampleType]
    public let meaningfulBits: ClosedRange<Int>?
    public let layouts: [String]
    public let backends: [Backend]

    /// Empty supported sets are deliberate: codec algorithms begin in a later milestone.
    internal static let unimplemented = CodecCapabilities(
        supportsEncoding: false, supportsDecoding: false, supportsInspection: false,
        formats: [], compressionModes: [], sampleTypes: [], meaningfulBits: nil, layouts: [], backends: [])
}

/// Codec-specific knobs will be introduced with qualified implementations; none is enabled yet.
public struct EncoderCodecOptions: Sendable, Equatable { public init() {} }
public struct DecoderCodecOptions: Sendable, Equatable { public init() {} }

public struct EncoderConfiguration: Sendable, Equatable {
    public let mode: CompressionMode
    public let codecOptions: EncoderCodecOptions
    public static let lossless = EncoderConfiguration(defaultLossless: ())

    private init(defaultLossless: Void) { mode = .lossless; codecOptions = EncoderCodecOptions() }

    public init(mode: CompressionMode = .lossless,
                codecOptions: EncoderCodecOptions = EncoderCodecOptions()) throws {
        if case .nearLossless(let error) = mode, error <= 0 {
            throw CodecError(.invalidArgument, context: "near-lossless error must be positive")
        }
        guard mode == .lossless else {
            throw CodecError(.unsupportedFeature, context: "compression mode is not implemented")
        }
        self.mode = mode
        self.codecOptions = codecOptions
    }
}

public struct DecoderConfiguration: Sendable, Equatable {
    public let codecOptions: DecoderCodecOptions
    public static let preserving = DecoderConfiguration(defaultPreserving: ())
    private init(defaultPreserving: Void) { codecOptions = DecoderCodecOptions() }
    public init(codecOptions: DecoderCodecOptions = DecoderCodecOptions()) throws {
        self.codecOptions = codecOptions
    }
}

public struct EncodeOptions: Sendable {
    public let resourceLimits: ResourceLimits
    public let executionPolicy: ExecutionPolicy
    public let copyPolicy: CopyPolicy
    public let metadataPolicy: MetadataPolicy
    public let progress: ProgressHandler?

    public init(resourceLimits: ResourceLimits = .default, executionPolicy: ExecutionPolicy = .automatic,
                copyPolicy: CopyPolicy = .requireSharedStorage, metadataPolicy: MetadataPolicy = .preserve,
                progress: ProgressHandler? = nil) {
        self.resourceLimits = resourceLimits
        self.executionPolicy = executionPolicy
        self.copyPolicy = copyPolicy
        self.metadataPolicy = metadataPolicy
        self.progress = progress
    }
}

public struct DecodeOptions: Sendable {
    public let resourceLimits: ResourceLimits
    public let executionPolicy: ExecutionPolicy
    public let copyPolicy: CopyPolicy
    public let metadataPolicy: MetadataPolicy
    public let progress: ProgressHandler?

    public init(resourceLimits: ResourceLimits = .default, executionPolicy: ExecutionPolicy = .automatic,
                copyPolicy: CopyPolicy = .requireSharedStorage, metadataPolicy: MetadataPolicy = .preserve,
                progress: ProgressHandler? = nil) {
        self.resourceLimits = resourceLimits
        self.executionPolicy = executionPolicy
        self.copyPolicy = copyPolicy
        self.metadataPolicy = metadataPolicy
        self.progress = progress
    }
}

public struct ImageInfo: Sendable {
    public let format: EncodedFormat
    public let descriptor: ImageDescriptor
    public let frameCount: Int
    public let metadata: ImageMetadata
}

public struct EncodedImage: Sendable {
    public let data: Data
    public let format: EncodedFormat
    public let mode: CompressionMode
    public let report: OperationReport
}

public struct DecodedImage: Sendable {
    public let image: Image
    public let report: OperationReport
}

/// Public API feasibility shell. No encoder is implemented; capabilities and errors say so.
public struct Encoder: Sendable {
    public let configuration: EncoderConfiguration
    public static let capabilities = CodecCapabilities.unimplemented
    public var capabilities: CodecCapabilities { Self.capabilities }
    public init(configuration: EncoderConfiguration = .lossless) throws { self.configuration = configuration }

    /// Runs on the generic concurrent executor, never implying async alone moves CPU work.
    @concurrent public func encode(_ image: Image, options: EncodeOptions = EncodeOptions()) async throws -> EncodedImage {
        try Task.checkCancellation()
        try options.resourceLimits.validatePixelByteCount(image.storage.byteCount)
        throw CodecError(.unsupportedFeature, context: "codec encoding begins after Milestone 1")
    }
}

/// Public API feasibility shell. No parser or decoder is implemented.
public struct Decoder: Sendable {
    public let configuration: DecoderConfiguration
    public static let capabilities = CodecCapabilities.unimplemented
    public var capabilities: CodecCapabilities { Self.capabilities }
    public init(configuration: DecoderConfiguration = .preserving) throws { self.configuration = configuration }

    public func inspect(_ data: Data, options: DecodeOptions = DecodeOptions()) throws -> ImageInfo {
        try Task.checkCancellation()
        try options.resourceLimits.validateInputByteCount(data.count)
        throw CodecError(.unsupportedFeature, context: "codec inspection begins after Milestone 1")
    }

    @concurrent public func decode(_ data: Data, options: DecodeOptions = DecodeOptions()) async throws -> DecodedImage {
        try Task.checkCancellation()
        try options.resourceLimits.validateInputByteCount(data.count)
        throw CodecError(.unsupportedFeature, context: "codec decoding begins after Milestone 1")
    }

    @concurrent public func decode(_ data: Data, into destination: ImageDestination,
                                  options: DecodeOptions = DecodeOptions()) async throws -> DecodedImage {
        // No error path may leave a partially written destination publishable.
        defer { destination.abort() }
        try Task.checkCancellation()
        try options.resourceLimits.validateInputByteCount(data.count)
        try options.resourceLimits.validatePixelByteCount(destination.byteCount)
        throw CodecError(.unsupportedFeature, context: "codec decoding begins after Milestone 1")
    }
}
