// swift-tools-version: 6.2
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(
    name: "URLConsumer",
    platforms: [.macOS(.v26)],
    dependencies: [.package(url: "https://github.com/Raster-Lab/SwiftJ2K.git", revision: "45a36992f2daab547cc058097b648f71053e3cab")],
    targets: [.executableTarget(name: "URLConsumer", dependencies: [.product(name: "SwiftJ2K", package: "SwiftJ2K")])],
    swiftLanguageModes: [.v6]
)
