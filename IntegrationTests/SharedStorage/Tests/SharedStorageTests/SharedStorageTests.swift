// SPDX-License-Identifier: MIT
import Foundation
import Testing
import SwiftJ2K
import SwiftJLS

@Suite("Two-module synthetic shared storage")
struct SharedStorageTests {
    @Test("J2K-owned pixels remain exact through a JLS view across await", arguments: [12, 16])
    func retainedImageHandoff(_ meaningfulBits: Int) async throws {
        let observations = Observations()
        var pair: PublishedPair? = try publishedPair(meaningfulBits: meaningfulBits, observations: observations)
        #expect(observations.snapshot.allocations == 1)
        #expect(observations.snapshot.ownerReleases == 0)
        if let current = pair {
            try await readAcrossAwait(current)
            #expect(observations.snapshot.ownerReleases == 0)
        }
        pair = nil
        #expect(observations.snapshot.ownerReleases == 1)
        #expect(observations.snapshot.writeScopes == 16)
        #expect(observations.snapshot.readScopes >= 30)
        #expect(observations.snapshot.allocations == 1)
    }

    @Test("Either module reserves the one provider, excluding the other", arguments: [false, true])
    func writerExclusionInBothOrderings(_ jlsFirst: Bool) throws {
        let observations = Observations()
        let descriptor = try SwiftJ2K.ImageDescriptor.greyscale16(width: 1, height: 1)
        let owner = try ObservedJ2KOwner(byteCount: 2, observations: observations)
        let adapter = JLSWritableAdapter(owner: owner)
        if jlsFirst {
            let destination = try SwiftJLS.ImageDestination(descriptor: jlsDescriptor(from: descriptor), storage: adapter)
            expectJ2KError(.storageUnavailable) {
                try SwiftJ2K.ImageDestination(descriptor: descriptor, storage: owner)
            }
            expectJ2KError(.storageUnavailable) { try owner.readOnlyStorage() }
            try destination.setSample(65535, x: 0, y: 0)
            let image = try destination.seal()
            #expect(try image.sample(x: 0, y: 0) == 65535)
            #expect(image.storage.allocationID == owner.allocationID)
        } else {
            let destination = try SwiftJ2K.ImageDestination(descriptor: descriptor, storage: owner)
            expectJLSError(.storageUnavailable) {
                try SwiftJLS.ImageDestination(descriptor: jlsDescriptor(from: descriptor), storage: adapter)
            }
            try destination.setSample(65535, x: 0, y: 0)
            let image = try destination.seal()
            #expect(try jlsImage(from: image).sample(x: 0, y: 0) == 65535)
        }
        #expect(owner.allocation.state == .sealed)
        expectJLSError(.storageUnavailable) { try adapter.reserveWrite() }
        expectJ2KError(.storageUnavailable) { try owner.reserveWrite() }
    }

    @Test("JLS writes through the adapter into the actual J2K allocation", arguments: [12, 16])
    func adaptedWriterAndNativeReader(_ meaningfulBits: Int) throws {
        let observations = Observations()
        let descriptor = try sourceDescriptor(meaningfulBits: meaningfulBits)
        let owner = try ObservedJ2KOwner(byteCount: descriptor.requiredByteCount, observations: observations)
        let destination = try SwiftJLS.ImageDestination(
            descriptor: jlsDescriptor(from: descriptor), storage: JLSWritableAdapter(owner: owner))
        let expected = expectedSamples(meaningfulBits: meaningfulBits)
        for y in 0..<3 {
            for x in 0..<5 { try destination.setSample(expected[y * 5 + x], x: x, y: y) }
        }
        let jls = try destination.seal()
        let j2k = try SwiftJ2K.Image(descriptor: descriptor, storage: owner.readOnlyStorage())
        #expect(jls.storage.allocationID == j2k.storage.allocationID)
        #expect(jls.storage.byteCount == 38)
        #expect(j2k.storage.byteCount == 38)
        for y in 0..<3 {
            for x in 0..<5 {
                #expect(try jls.sample(x: x, y: y) == expected[y * 5 + x])
                #expect(try j2k.sample(x: x, y: y) == expected[y * 5 + x])
            }
        }
        #expect(observations.snapshot.allocations == 1)
        #expect(observations.snapshot.writeScopes == 15)
        #expect(observations.snapshot.readScopes >= 30)
    }

    @Test("An aborted JLS destination invalidates both aliases")
    func abortIsShared() throws {
        let observations = Observations()
        let owner = try ObservedJ2KOwner(byteCount: 2, observations: observations)
        let descriptor = try SwiftJ2K.ImageDescriptor.greyscale16(width: 1, height: 1)
        let adapter = JLSWritableAdapter(owner: owner)
        let destination = try SwiftJLS.ImageDestination(descriptor: jlsDescriptor(from: descriptor), storage: adapter)
        try destination.setSample(17, x: 0, y: 0)
        destination.abort()
        #expect(owner.allocation.state == .invalid)
        expectJLSError(.storageUnavailable) { try destination.seal() }
        expectJLSError(.storageUnavailable) { try adapter.reserveWrite() }
        expectJ2KError(.storageUnavailable) { try owner.readOnlyStorage() }
        expectJ2KError(.storageUnavailable) { try owner.reserveWrite() }
    }

    @Test("A throwing JLS callback preserves its error and prevents publication")
    func callbackFailureIsShared() throws {
        enum Expected: Error, Equatable { case interrupted }
        let observations = Observations()
        let owner = try ObservedJ2KOwner(byteCount: 2, observations: observations)
        let destination = try SwiftJLS.ImageDestination(
            descriptor: SwiftJLS.ImageDescriptor.greyscale16(width: 1, height: 1),
            storage: JLSWritableAdapter(owner: owner))
        #expect(throws: Expected.interrupted) {
            try destination.withUnsafeMutableBytes { bytes in
                bytes[0] = 0x29
                throw Expected.interrupted
            }
        }
        #expect(owner.allocation.state == .invalid)
        expectJLSError(.storageUnavailable) { try destination.seal() }
        expectJ2KError(.storageUnavailable) { try owner.readOnlyStorage() }
    }

    @Test("Cancellation crosses module adapters as CancellationError")
    func cancelledProducer() async throws {
        let observations = Observations()
        let owner = try ObservedJ2KOwner(byteCount: 2, observations: observations)
        let destination = try SwiftJLS.ImageDestination(
            descriptor: SwiftJLS.ImageDescriptor.greyscale16(width: 1, height: 1),
            storage: JLSWritableAdapter(owner: owner))
        let producer = Task {
            try destination.withUnsafeMutableBytes { bytes in
                bytes[0] = 0x22
                withUnsafeCurrentTask { $0?.cancel() }
                try Task.checkCancellation()
            }
        }
        do {
            try await producer.value
            Issue.record("Cancelled synthetic producer returned success")
        } catch is CancellationError {
            // The adapter must not translate cancellation into CodecError.
        } catch {
            Issue.record("Cancellation changed type: \(type(of: error))")
        }
        #expect(owner.allocation.state == .invalid)
        expectJLSError(.storageUnavailable) { try destination.seal() }
        expectJ2KError(.storageUnavailable) { try owner.readOnlyStorage() }
        #expect(observations.snapshot.writeScopes == 1)
    }

    @Test("Dropping an unfinished cross-module lease aborts its provider")
    func droppedAdaptedLease() throws {
        let observations = Observations()
        let owner = try ObservedJ2KOwner(byteCount: 2, observations: observations)
        try reserveAndDrop(owner)
        #expect(owner.allocation.state == .invalid)
        expectJ2KError(.storageUnavailable) { try owner.reserveWrite() }
    }

    @Test("Every stable provider error category is mapped explicitly")
    func stableErrorTranslation() throws {
        for category in SwiftJ2K.CodecError.Category.allCases {
            let adapter = JLSWritableAdapter(owner: FailingJ2KOwner(category: category))
            do {
                _ = try adapter.reserveWrite()
                Issue.record("Expected translated provider error")
            } catch let error as SwiftJLS.CodecError {
                #expect(error.category.rawValue == category.rawValue)
                #expect(error.context == "synthetic provider failure")
            } catch {
                Issue.record("Provider error escaped with incorrect type")
            }
        }
    }
}

private struct PublishedPair: Sendable {
    let j2k: SwiftJ2K.Image
    let jls: SwiftJLS.Image
    let expected: [UInt16]
}

private func sourceDescriptor(meaningfulBits: Int) throws -> SwiftJ2K.ImageDescriptor {
    try SwiftJ2K.ImageDescriptor.greyscale16(
        width: 5, height: 3, meaningfulBits: meaningfulBits, rowBytes: 12, offset: 2)
}

private func expectedSamples(meaningfulBits: Int) -> [UInt16] {
    if meaningfulBits == 12 {
        return [0, 4095, 1, 2048, 17, 4094, 63, 1023, 255, 3072, 16, 3584, 2, 4001, 128]
    }
    return [0, 65535, 1, 32768, 0xabcd, 65534, 63, 0x1234, 255, 0xff00, 16, 49152, 2, 60001, 128]
}

/// Returns only image owners. The allocating caller and its destination go away.
private func publishedPair(meaningfulBits: Int, observations: Observations) throws -> PublishedPair {
    let descriptor = try sourceDescriptor(meaningfulBits: meaningfulBits)
    let owner = try ObservedJ2KOwner(byteCount: descriptor.requiredByteCount, observations: observations)
    let destination = try SwiftJ2K.ImageDestination(descriptor: descriptor, storage: owner)
    try destination.withUnsafeMutableBytes { bytes in
        for index in bytes.indices { bytes[index] = 0xa5 }
    }
    let expected = expectedSamples(meaningfulBits: meaningfulBits)
    for y in 0..<3 {
        for x in 0..<5 { try destination.setSample(expected[y * 5 + x], x: x, y: y) }
    }
    let metadata = try SwiftJ2K.ImageMetadata(entries: ["fixture": Data([1, 2, 3])])
    let j2k = try destination.seal(metadata: metadata)
    let jls = try jlsImage(from: j2k)
    return PublishedPair(j2k: j2k, jls: jls, expected: expected)
}

@concurrent
private func readAcrossAwait(_ pair: PublishedPair) async throws {
    await Task.yield()
    #expect(pair.j2k.storage.allocationID == pair.jls.storage.allocationID)
    #expect(pair.j2k.storage.byteCount == 38)
    #expect(pair.jls.storage.byteCount == 38)
    #expect(pair.j2k.descriptor.meaningfulBits == pair.jls.descriptor.meaningfulBits)
    #expect(pair.jls.descriptor.planes.first?.offset == 2)
    #expect(pair.jls.descriptor.planes.first?.rowBytes == 12)
    #expect(pair.jls.metadata.entries == pair.j2k.metadata.entries)
    for y in 0..<3 {
        for x in 0..<5 {
            #expect(try pair.j2k.sample(x: x, y: y) == pair.expected[y * 5 + x])
            #expect(try pair.jls.sample(x: x, y: y) == pair.expected[y * 5 + x])
        }
    }
    try pair.jls.storage.withUnsafeBytes { bytes in
        for index in [0, 1, 12, 13, 24, 25, 36, 37] { #expect(bytes[index] == 0xa5) }
        if pair.jls.descriptor.meaningfulBits == 16 {
            // The sample 0xabcd at (4,0) independently establishes little endian.
            #expect(bytes[10] == 0xcd)
            #expect(bytes[11] == 0xab)
        } else {
            #expect(bytes[4] == 0xff)
            #expect(bytes[5] == 0x0f)
        }
    }
    let expectedSum = pair.expected.reduce(0) { $0 + Int($1) }
    try await withThrowingTaskGroup(of: Int.self) { group in
        for index in 0..<16 {
            group.addTask {
                await Task.yield()
                var sum = 0
                for y in 0..<3 {
                    for x in 0..<5 {
                        let value: UInt16
                        if index.isMultiple(of: 2) {
                            value = try pair.j2k.sample(x: x, y: y)
                        } else {
                            value = try pair.jls.sample(x: x, y: y)
                        }
                        sum += Int(value)
                    }
                }
                return sum
            }
        }
        for try await sum in group { #expect(sum == expectedSum) }
    }
}

private func reserveAndDrop(_ owner: ObservedJ2KOwner) throws {
    let adapter = JLSWritableAdapter(owner: owner)
    let lease = try adapter.reserveWrite()
    try lease.withUnsafeMutableBytes { $0[0] = 0x71 }
}

private final class FailingJ2KOwner: SwiftJ2K.WritableImageStorage {
    let category: SwiftJ2K.CodecError.Category
    let allocationID = UUID()
    let byteCount = 2
    init(category: SwiftJ2K.CodecError.Category) { self.category = category }
    func reserveWrite() throws -> any SwiftJ2K.ImageWriteLease {
        throw SwiftJ2K.CodecError(category, context: "synthetic provider failure")
    }
}

private func expectJ2KError<R>(_ category: SwiftJ2K.CodecError.Category,
                             sourceLocation: SourceLocation = #_sourceLocation,
                             _ body: () throws -> R) {
    do {
        _ = try body()
        Issue.record("Expected SwiftJ2K error", sourceLocation: sourceLocation)
    } catch let error as SwiftJ2K.CodecError {
        #expect(error.category == category, sourceLocation: sourceLocation)
    } catch {
        Issue.record("Incorrect SwiftJ2K boundary error type", sourceLocation: sourceLocation)
    }
}

private func expectJLSError<R>(_ category: SwiftJLS.CodecError.Category,
                             sourceLocation: SourceLocation = #_sourceLocation,
                             _ body: () throws -> R) {
    do {
        _ = try body()
        Issue.record("Expected SwiftJLS error", sourceLocation: sourceLocation)
    } catch let error as SwiftJLS.CodecError {
        #expect(error.category == category, sourceLocation: sourceLocation)
    } catch {
        Issue.record("Incorrect SwiftJLS boundary error type", sourceLocation: sourceLocation)
    }
}
