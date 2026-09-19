// swift-tools-version: 6.4
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(
    name: "SwiftJ2K",
    platforms: [.macOS(.v27), .iOS(.v27), .tvOS(.v27), .visionOS(.v27), .watchOS(.v27)],
    products: [.library(name: "SwiftJ2K", targets: ["SwiftJ2K"]),
               .executable(name: "swiftj2k", targets: ["SwiftJ2KCLI"])],
    targets: [
        .target(name: "SwiftJ2K"),
        .executableTarget(name: "SwiftJ2KCLI", dependencies: ["SwiftJ2K"]),
        .testTarget(name: "SwiftJ2KTests", dependencies: ["SwiftJ2K"])
    ],
    swiftLanguageModes: [.v6]
)
