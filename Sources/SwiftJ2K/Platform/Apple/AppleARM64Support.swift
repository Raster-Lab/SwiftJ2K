// Copyright (c) 2026 Raster Images Private Limited. MIT licensed.

#if (os(macOS) || os(iOS) || os(tvOS) || os(visionOS)) && arch(arm64)
enum AppleARM64Support {
    static let profile = PlatformProfile.appleARM64
}
#endif
