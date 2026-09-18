// Copyright (c) 2026 Raster Images Private Limited
// SPDX-License-Identifier: MIT

import Foundation

/// The output endpoint of this library's native format-pair operation.
///
/// Declaring these targets does not advertise an implemented codec. Check
/// `Transcoder.capabilities.pairs` before attempting a native operation.
public enum TranscodeTarget: String, CaseIterable, Sendable {
    case jpeg2000
    case htj2k
}

/// Fidelity is independent of whether the original image was encoded lossily.
public enum TranscodePreservation: String, Sendable {
    case exactSamples
    case originalBitstream
}

/// An individually qualified directional transcode profile.
public struct TranscodePair: Sendable {
    public let source: EncodedFormat
    public let target: EncodedFormat
    public let preservation: TranscodePreservation
    public let profiles: [String]
    public let processingPaths: [ProcessingPath]

    public init(
        source: EncodedFormat,
        target: EncodedFormat,
        preservation: TranscodePreservation,
        profiles: [String],
        processingPaths: [ProcessingPath]
    ) {
        self.source = source
        self.target = target
        self.preservation = preservation
        self.profiles = profiles
        self.processingPaths = processingPaths
    }
}

/// Native pairs and execution backends that have actually been implemented.
public struct TranscodeCapabilities: Sendable {
    public let pairs: [TranscodePair]
    public let backends: [Backend]

    public init(pairs: [TranscodePair], backends: [Backend]) {
        self.pairs = pairs
        self.backends = backends
    }
}

/// Native transcoding has no quality or pixel-fallback setting.
///
/// Milestone 1 has no implemented format profile to configure. The validated
/// constructor is reserved for later native implementation without suggesting
/// that reversible transcoding already works.
public struct TranscoderConfiguration: Sendable {
    public init() throws {}
}

public struct TranscodeOptions: Sendable {
    public let resourceLimits: ResourceLimits
    public let executionPolicy: ExecutionPolicy
    public let copyPolicy: CopyPolicy
    public let metadataPolicy: MetadataPolicy
    public let progress: ProgressHandler?

    public init(
        resourceLimits: ResourceLimits = .default,
        executionPolicy: ExecutionPolicy = .automatic,
        copyPolicy: CopyPolicy = .requireSharedStorage,
        metadataPolicy: MetadataPolicy = .preserve,
        progress: ProgressHandler? = nil
    ) {
        self.resourceLimits = resourceLimits
        self.executionPolicy = executionPolicy
        self.copyPolicy = copyPolicy
        self.metadataPolicy = metadataPolicy
        self.progress = progress
    }
}

/// The native compressed-format API shape. No codec is migrated in Milestone 1.
///
/// Calls fail explicitly; no compressed output or successful operation report is
/// fabricated. Future JPEG 2000/HTJ2K operation must preserve exact samples and
/// required interpretation, using owned coefficient or image storage throughout.
public struct Transcoder: Sendable {
    public let configuration: TranscoderConfiguration

    public init() throws {
        self.configuration = try TranscoderConfiguration()
    }

    public init(configuration: TranscoderConfiguration) throws {
        self.configuration = configuration
    }

    public var capabilities: TranscodeCapabilities {
        TranscodeCapabilities(pairs: [], backends: [])
    }

    @concurrent
    public func transcode(
        _ data: Data,
        to target: TranscodeTarget,
        options: TranscodeOptions = .init()
    ) async throws -> EncodedImage {
        try Task.checkCancellation()
        try options.resourceLimits.validateInputByteCount(data.count)
        guard options.metadataPolicy == .preserve else {
            throw CodecError(.unsupportedFeature, context: "Native transcoding requires metadata preservation")
        }
        // Parsing, reconstruction and codec algorithms belong to later
        // milestones. Rejecting here retains no source owner or background work.
        throw CodecError(.unsupportedFeature, context: "Native transcoding is unavailable in Milestone 1")
    }
}
