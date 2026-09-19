// swift-tools-version: 6.4
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(
    name: "SwiftJ2K",
    platforms: [.macOS(.v26), .iOS(.v26), .tvOS(.v26), .visionOS(.v26), .watchOS(.v26)],
    products: [.library(name: "SwiftJ2K", targets: ["SwiftJ2K"])],
    targets: [
        .target(name: "SwiftJ2K"),
        .testTarget(name: "SwiftJ2KTests", dependencies: ["SwiftJ2K"])
    ],
    swiftLanguageModes: [.v6]
)
