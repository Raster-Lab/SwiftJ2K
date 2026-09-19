// swift-tools-version: 6.4
import PackageDescription
let package = Package(name: "StorageBench", platforms: [.macOS("27.0")],
 dependencies: [.package(name: "SwiftJ2K", path: "/Users/suresh/Documents/Codex/2026-09-18/create-coding-agents-to-start-work/outputs/SwiftJ2K")],
 targets: [.executableTarget(name: "StorageBench", dependencies: [.product(name:"SwiftJ2K",package:"SwiftJ2K")])],
 swiftLanguageModes:[.v6])
