// swift-tools-version: 6.2
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(
    name: "SwiftJ2K",
    platforms: [
        .macOS("26.0"), .iOS("26.0"), .tvOS("26.0"),
        .visionOS("26.0"), .watchOS("26.0")
    ],
    products: [.library(name: "SwiftJ2K", targets: ["SwiftJ2K"])],
    targets: [
        .target(name: "SwiftJ2K"),
        .testTarget(name: "SwiftJ2KTests", dependencies: ["SwiftJ2K"])
    ],
    swiftLanguageModes: [.v6]
)
