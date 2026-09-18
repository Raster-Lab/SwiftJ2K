// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwiftJ2KStandaloneConsumer",
    platforms: [
        .macOS("26.0"), .iOS("26.0"), .tvOS("26.0"),
        .visionOS("26.0"), .watchOS("26.0")
    ],
    dependencies: [.package(path: "../..")],
    targets: [
        .executableTarget(
            name: "StandaloneConsumer",
            dependencies: [.product(name: "SwiftJ2K", package: "SwiftJ2K")]
        )
    ],
    swiftLanguageModes: [.v6]
)
