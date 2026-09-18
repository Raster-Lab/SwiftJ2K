// SPDX-License-Identifier: MIT
import Foundation

/// Finite admission ceilings. These engineering defaults are not device memory guarantees.
public struct ResourceLimits: Sendable, Equatable {
    public let maximumInputBytes: Int
    public let maximumOutputBytes: Int
    public let maximumDecodedBytes: Int
    public let maximumWorkspaceBytes: Int
    public let maximumTotalBytes: Int
    public let maximumPixels: Int
    public let maximumDimension: Int
    public let maximumFrames: Int
    public let maximumMetadataBytes: Int
    public let maximumICCBytes: Int
    public let maximumNestingDepth: Int
    public let maximumWorkers: Int
    public let deadline: Duration

    public static let general = ResourceLimits(watchProfile: false)
    public static let watch = ResourceLimits(watchProfile: true)

    public static var `default`: ResourceLimits {
        #if os(watchOS)
        .watch
        #else
        .general
        #endif
    }

    private init(watchProfile: Bool) {
        maximumInputBytes = (watchProfile ? 16 : 256) * 1_048_576
        maximumOutputBytes = maximumInputBytes
        maximumDecodedBytes = (watchProfile ? 32 : 512) * 1_048_576
        maximumWorkspaceBytes = maximumDecodedBytes
        maximumTotalBytes = (watchProfile ? 96 : 1024) * 1_048_576
        maximumPixels = 64_000_000
        maximumDimension = 1_000_000
        maximumFrames = 256
        maximumMetadataBytes = 16 * 1_048_576
        maximumICCBytes = 4 * 1_048_576
        maximumNestingDepth = 32
        maximumWorkers = min(max(ProcessInfo.processInfo.activeProcessorCount, 1), watchProfile ? 2 : 8)
        deadline = .seconds(watchProfile ? 30 : 120)
    }

    public init(
        maximumInputBytes: Int = ResourceLimits.default.maximumInputBytes,
        maximumOutputBytes: Int = ResourceLimits.default.maximumOutputBytes,
        maximumDecodedBytes: Int = ResourceLimits.default.maximumDecodedBytes,
        maximumWorkspaceBytes: Int = ResourceLimits.default.maximumWorkspaceBytes,
        maximumTotalBytes: Int = ResourceLimits.default.maximumTotalBytes,
        maximumPixels: Int = ResourceLimits.default.maximumPixels,
        maximumDimension: Int = ResourceLimits.default.maximumDimension,
        maximumFrames: Int = ResourceLimits.default.maximumFrames,
        maximumMetadataBytes: Int = ResourceLimits.default.maximumMetadataBytes,
        maximumICCBytes: Int = ResourceLimits.default.maximumICCBytes,
        maximumNestingDepth: Int = ResourceLimits.default.maximumNestingDepth,
        maximumWorkers: Int = ResourceLimits.default.maximumWorkers,
        deadline: Duration = ResourceLimits.default.deadline
    ) throws {
        let positive = [maximumInputBytes, maximumOutputBytes, maximumDecodedBytes,
                        maximumWorkspaceBytes, maximumTotalBytes, maximumPixels,
                        maximumDimension, maximumFrames, maximumNestingDepth, maximumWorkers]
        guard positive.allSatisfy({ $0 > 0 }), maximumMetadataBytes >= 0,
              maximumICCBytes >= 0, maximumICCBytes <= maximumMetadataBytes,
              deadline > .zero else {
            throw CodecError(.invalidArgument, context: "invalid resource limits")
        }
        self.maximumInputBytes = maximumInputBytes
        self.maximumOutputBytes = maximumOutputBytes
        self.maximumDecodedBytes = maximumDecodedBytes
        self.maximumWorkspaceBytes = maximumWorkspaceBytes
        self.maximumTotalBytes = maximumTotalBytes
        self.maximumPixels = maximumPixels
        self.maximumDimension = maximumDimension
        self.maximumFrames = maximumFrames
        self.maximumMetadataBytes = maximumMetadataBytes
        self.maximumICCBytes = maximumICCBytes
        self.maximumNestingDepth = maximumNestingDepth
        self.maximumWorkers = maximumWorkers
        self.deadline = deadline
    }

    internal func validateInputByteCount(_ count: Int) throws {
        guard count >= 0 else { throw CodecError(.invalidArgument, context: "negative byte count") }
        guard count <= maximumInputBytes, count <= maximumTotalBytes else {
            throw CodecError(.resourceLimitExceeded, context: "compressed input budget")
        }
    }

    internal func validatePixelByteCount(_ count: Int) throws {
        guard count > 0 else { throw CodecError(.invalidArgument, context: "empty storage") }
        guard count <= maximumDecodedBytes, count <= maximumTotalBytes else {
            throw CodecError(.resourceLimitExceeded, context: "decoded storage budget")
        }
    }
}
