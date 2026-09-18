// Copyright (c) 2026 Raster Images Private Limited. MIT licensed.

/// Identifies the compiled platform boundary; it does not advertise a codec
/// implementation, native acceleration or completed platform qualification.
enum PlatformProfile: String, Sendable {
    case appleARM64
    case appleSimulatorX86_64
    case appleWatch
    case macOSX86_64
    case linuxARM64
    case linuxX86_64
}

enum PlatformSelection {
    // These are target conditions, never build-host detection in Package.swift.
    // Each optional platform's definition uses the same condition in its own
    // source file, so unrelated integrations are omitted during compilation.
    static let current: PlatformProfile = {
        #if os(Linux) && arch(arm64)
        LinuxARM64Support.profile
        #elseif os(Linux) && arch(x86_64)
        LinuxX86_64Support.profile
        #elseif os(macOS) && arch(x86_64)
        MacOSX86_64Support.profile
        #elseif os(watchOS)
        AppleWatchSupport.profile
        #elseif (os(macOS) || os(iOS) || os(tvOS) || os(visionOS)) && arch(arm64)
        AppleARM64Support.profile
        #elseif (os(iOS) || os(tvOS) || os(visionOS)) && arch(x86_64) && targetEnvironment(simulator)
        AppleSimulatorX86_64Support.profile
        #else
        #error("This target is outside the Swift Image Compression Suite platform contract.")
        #endif
    }()
}
