// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GeniusTrader",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "GeniusTraderApp",
            targets: ["GeniusTraderApp"]
        ),
        .library(
            name: "GeniusTraderUI",
            targets: ["GeniusTraderUI"]
        )
    ],
    targets: [
        .executableTarget(
            name: "GeniusTraderApp",
            dependencies: ["GeniusTraderUI"],
            path: "Sources/GeniusTraderApp",
            resources: [.process("Resources")]
        ),
        .target(
            name: "GeniusTraderUI",
            path: "Sources/GeniusTraderUI"
        )
    ]
)
