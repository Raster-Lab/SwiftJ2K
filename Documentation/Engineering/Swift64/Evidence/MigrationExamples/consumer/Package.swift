// swift-tools-version: 6.4
import PackageDescription
let package = Package(
    name: "MigrationDocConsumer",
    platforms: [.macOS("26.0")],
    dependencies: [.package(path: "/Users/suresh/Documents/Codex/2026-09-18/create-coding-agents-to-start-work/outputs/SwiftJ2K")],
    targets: [.executableTarget(name: "MigrationExample", dependencies: [
        .product(name: "SwiftJ2K", package: "SwiftJ2K")
    ])],
    swiftLanguageModes: [.v6]
)
