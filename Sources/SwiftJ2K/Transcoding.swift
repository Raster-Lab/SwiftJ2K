// SPDX-License-Identifier: Apache-2.0
import Foundation

/// Native compressed endpoints. No direction is implemented in Milestone 1.
public enum TranscodeTarget: String, Sendable, CaseIterable {
    case jpeg2000, htj2k
}

/// These fidelity guarantees are distinct; sample preservation differs from bitstream restoration.
public enum TranscodePreservation: Sendable {
    case exactSamples, originalBitstream
}

/// A qualified native format-pair path, once codec migration supplies one.
public enum TranscodeProcessingPath: Sendable {
    case coefficients, reconstruction, sharedSamples
}

/// Empty capability collections mean no direction has been implemented or qualified.
public struct TranscodeCapability: Sendable {
    public let source: TranscodeTarget
    public let target: TranscodeTarget
    public let preservation: TranscodePreservation
    public let profileLimits: [String]
    public let processingPaths: [TranscodeProcessingPath]
}

/// Immutable lossless policy. Configuration does not imply an implemented codec.
public struct TranscoderConfiguration: Sendable {
    public let mode: CompressionMode

    public init(mode: CompressionMode = .lossless) throws {
        guard mode == .lossless else {
            throw CodecError(.unsupportedFeature, "Native transcoding requires the lossless preservation policy.")
        }
        self.mode = mode
    }

    private init(lossless: Bool) { mode = .lossless }
    public static let `default` = Self(lossless: true)
}

/// The common operation policies have exactly the encode option vocabulary.
public typealias TranscodeOptions = EncodeOptions

/// Feasibility-only API. No JPEG 2000/HTJ2K parser, fallback or private format is used.
public struct Transcoder: Sendable {
    public let configuration: TranscoderConfiguration
    public let capabilities: [TranscodeCapability] = []

    public init(configuration: TranscoderConfiguration = .default) throws {
        self.configuration = configuration
    }

    /// Always rejects until a later milestone qualifies the native operation.
    /// Runs on the generic executor; retains compressed input until return.
    @concurrent
    public func transcode(_ data: Data, to target: TranscodeTarget,
                          options: TranscodeOptions = .init()) async throws -> EncodedImage {
        try Task.checkCancellation()
        guard data.count <= options.resourceLimits.maximumCompressedBytes,
              data.count <= options.resourceLimits.maximumMemoryBytes else {
            throw CodecError(.resourceLimitExceeded, "Compressed input exceeds the admission budget.")
        }
        if case .required(.accelerated) = options.executionPolicy {
            throw CodecError(.backendUnavailable, "No accelerated backend is implemented.")
        }
        try Task.checkCancellation()
        throw CodecError(.unsupportedFeature, "Native transcoding is not implemented in Milestone 1.")
    }
}
