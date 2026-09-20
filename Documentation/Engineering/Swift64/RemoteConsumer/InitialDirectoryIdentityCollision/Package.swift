// swift-tools-version: 6.4
import PackageDescription
let package = Package(name: "RemoteMigrationConsumer", platforms: [.macOS("26.0")],
 dependencies: [.package(url: "https://github.com/Raster-Lab/SwiftJ2K.git", revision: "c19ff80c94eabff959d485b6b7eb3d3d931f3bf8")],
 targets: [.executableTarget(name: "MigrationExample", dependencies: [.product(name: "SwiftJ2K", package: "SwiftJ2K")])],
 swiftLanguageModes: [.v6])
