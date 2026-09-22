// swift-tools-version: 6.2
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(
    name: "URLConsumer",
    platforms: [.macOS(.v26)],
    dependencies: [.package(url: "https://github.com/Raster-Lab/SwiftJ2K.git", revision: "67273dbb5a195c1b2a1f47f311d9a1e4cd7f9203")],
    targets: [.executableTarget(name: "URLConsumer", dependencies: [.product(name: "SwiftJ2K", package: "SwiftJ2K")])],
    swiftLanguageModes: [.v6]
)
