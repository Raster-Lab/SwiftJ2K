// SPDX-License-Identifier: MIT
import Foundation

/// Stable, non-sensitive failure information. Task cancellation uses CancellationError.
public struct CodecError: Error, Sendable, Equatable {
    public enum Category: String, Sendable, CaseIterable {
        case invalidArgument, malformedInput, unsupportedFormat, unsupportedFeature
        case incompatibleImageLayout, resourceLimitExceeded, storageUnavailable
        case backendUnavailable, ioFailure, internalFailure
    }

    public let category: Category
    public let context: String?

    public init(_ category: Category, context: String? = nil) {
        self.category = category
        self.context = context
    }
}

internal func checkedAdd(_ lhs: Int, _ rhs: Int) throws -> Int {
    let (value, overflow) = lhs.addingReportingOverflow(rhs)
    guard !overflow else { throw CodecError(.invalidArgument, context: "integer addition overflow") }
    return value
}

internal func checkedMultiply(_ lhs: Int, _ rhs: Int) throws -> Int {
    let (value, overflow) = lhs.multipliedReportingOverflow(by: rhs)
    guard !overflow else { throw CodecError(.invalidArgument, context: "integer multiplication overflow") }
    return value
}
