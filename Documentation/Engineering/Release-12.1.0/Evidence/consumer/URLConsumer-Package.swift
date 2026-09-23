// swift-tools-version: 6.2
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(
    name: "URLConsumer",
    platforms: [.macOS(.v26)],
    dependencies: [.package(url: "https://github.com/Raster-Lab/SwiftJ2K.git", revision: "f3e13a061963dc5af62605071aa6d0243105f6f4")],
    targets: [.executableTarget(name: "URLConsumer", dependencies: [.product(name: "SwiftJ2K", package: "SwiftJ2K")])],
    swiftLanguageModes: [.v6]
)
