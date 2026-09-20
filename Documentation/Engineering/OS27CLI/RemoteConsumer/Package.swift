// swift-tools-version: 6.4
import PackageDescription
let package = Package(name: "RemoteMigrationConsumer", platforms: [.macOS("27.0")],
 dependencies: [.package(url: "https://github.com/Raster-Lab/SwiftJ2K.git", revision: "4957daf8caab470a09aae393c8703b4fd93842c3")],
 targets: [.executableTarget(name: "MigrationExample", dependencies: [.product(name: "SwiftJ2K", package: "SwiftJ2K")])],
 swiftLanguageModes: [.v6])
