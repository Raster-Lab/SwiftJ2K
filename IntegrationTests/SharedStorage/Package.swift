// swift-tools-version: 6.2
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(
    name: "SharedStorageIntegration",
    platforms: [
        .macOS("26.0"), .iOS("26.0"), .tvOS("26.0"),
        .visionOS("26.0"), .watchOS("26.0")
    ],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/Raster-Lab/SwiftJLS.git",
                 revision: "d394e4eff3b85d9da9f2f3a6af09a898ffe7d57d")
    ],
    targets: [
        .testTarget(name: "SharedStorageTests", dependencies: [
            .product(name: "SwiftJ2K", package: "SwiftJ2K"),
            .product(name: "SwiftJLS", package: "SwiftJLS")
        ])
    ],
    swiftLanguageModes: [.v6]
)
