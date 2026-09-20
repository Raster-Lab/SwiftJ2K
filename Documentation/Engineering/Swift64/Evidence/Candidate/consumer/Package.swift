// swift-tools-version: 6.4
import PackageDescription
let package = Package(name: "FreshConsumer", platforms: [.macOS(.v26)],
 dependencies: [.package(path: "/Users/suresh/Documents/Codex/2026-09-18/create-coding-agents-to-start-work/outputs/SwiftJ2K")],
 targets: [.executableTarget(name: "Consumer", dependencies: [.product(name: "SwiftJ2K", package: "SwiftJ2K")])],
 swiftLanguageModes: [.v6])
