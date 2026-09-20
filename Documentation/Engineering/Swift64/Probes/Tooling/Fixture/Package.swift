// swift-tools-version: 6.4
import PackageDescription
let package = Package(
    name: "ToolingFixture",
    platforms: [.macOS(.v26)],
    products: [.library(name: "ToolingLibrary", targets: ["ToolingLibrary"]),
               .executable(name: "ToolingProbe", targets: ["ToolingProbe"])],
    targets: [.target(name: "ToolingLibrary", resources: [.process("Resources")]),
              .executableTarget(name: "ToolingProbe", dependencies: ["ToolingLibrary"]),
              .testTarget(name: "ToolingTests", dependencies: ["ToolingLibrary"])],
    swiftLanguageModes: [.v6])
