// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GameCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GameCore", targets: ["GameCore"]),
        .executable(name: "signalsort-cli", targets: ["signalsort-cli"]),
    ],
    targets: [
        .target(name: "GameCore"),
        .executableTarget(name: "signalsort-cli", dependencies: ["GameCore"]),
        .testTarget(name: "GameCoreTests", dependencies: ["GameCore"]),
    ]
)
