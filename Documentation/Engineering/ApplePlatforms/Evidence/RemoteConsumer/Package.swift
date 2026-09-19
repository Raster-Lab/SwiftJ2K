// swift-tools-version: 6.4
import PackageDescription
let package = Package(
    name: "RemoteConsumerSwiftJ2K",
    platforms: [.macOS("27.0")],
    dependencies: [.package(url: "https://github.com/Raster-Lab/SwiftJ2K.git", revision: "9a3cc81f04ec5925dc1041132c80eaab4a9f0f8d")],
    targets: [.executableTarget(name: "Consumer", dependencies: [.product(name: "SwiftJ2K", package: "SwiftJ2K")])],
    swiftLanguageModes: [.v6]
)
