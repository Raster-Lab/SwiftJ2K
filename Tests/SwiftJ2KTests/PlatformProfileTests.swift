// SPDX-License-Identifier: MIT
import Testing
import SwiftJ2K

@Test func platformDefaultsEnforceWatchAdmissionBeforeAllocation() throws {
    // Exactly 32 MiB and one row over it. Descriptor construction allocates no
    // pixel buffer, so this tests Watch admission without exhausting the device.
    let boundary = try ImageDescriptor.greyscale16(
        width: 4096, height: 4096, limits: .watch)
    #expect(boundary.requiredByteCount == 32 * 1024 * 1024)
    do {
        _ = try ImageDescriptor.greyscale16(width: 4096, height: 4097, limits: .watch)
        Issue.record("The Watch decoded-storage ceiling must reject an extra row.")
    } catch let error as CodecError {
        #expect(error.category == .resourceLimitExceeded)
    }

    #if os(watchOS)
    #expect(EncodeOptions().resourceLimits.maximumDecodedBytes == 32 * 1024 * 1024)
    #expect(DecodeOptions().resourceLimits.maximumWorkers == 2)
    #expect(DecodeOptions().resourceLimits.deadlineSeconds == 30)
    do {
        _ = try ImageDescriptor.greyscale16(width: 4096, height: 4097)
        Issue.record("Watch must select its bounded profile by default.")
    } catch let error as CodecError {
        #expect(error.category == .resourceLimitExceeded)
    }
    #else
    #expect(EncodeOptions().resourceLimits.maximumDecodedBytes == 512 * 1024 * 1024)
    #expect(DecodeOptions().resourceLimits.deadlineSeconds == 120)
    let admitted = try ImageDescriptor.greyscale16(width: 4096, height: 4097)
    #expect(admitted.requiredByteCount == 4096 * 4097 * 2)
    #endif
}
