// Copyright (c) 2026 Raster Images Private Limited. MIT licensed.

// Watch uses the selected SDK's supported architectures, including its distinct
// device and simulator triples. It is deliberately not blanket-gated on arm64.
#if os(watchOS)
enum AppleWatchSupport {
    static let profile = PlatformProfile.appleWatch
}
#endif
