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
        )
    ],
    targets: [
        .executableTarget(
            name: "GeniusTraderApp",
            path: "Sources/GeniusTraderApp",
            resources: [.process("Resources")]
        )
    ]
)
