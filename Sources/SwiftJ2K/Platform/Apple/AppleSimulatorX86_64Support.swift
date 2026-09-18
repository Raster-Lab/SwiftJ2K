// Copyright (c) 2026 Raster Images Private Limited. MIT licensed.

#if (os(iOS) || os(tvOS) || os(visionOS)) && arch(x86_64) && targetEnvironment(simulator)
enum AppleSimulatorX86_64Support {
    static let profile = PlatformProfile.appleSimulatorX86_64
}
#endif
