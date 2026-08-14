// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "apple-eventkit-mcp",
    platforms: [
        // String form is required: the `.v26` enum case is unavailable at
        // swift-tools-version 5.9.
        .macOS("26.0")
    ],
    products: [
        .executable(
            name: "apple-eventkit-mcp",
            targets: ["apple-eventkit-mcp"]
        ),
        .library(
            name: "AppleEventKitMCPCore",
            targets: ["AppleEventKitMCPCore"]
        )
    ],
    targets: [
        .target(
            name: "AppleEventKitMCPCore",
            path: "Sources/AppleEventKitMCPCore"
        ),
        .executableTarget(
            name: "apple-eventkit-mcp",
            dependencies: ["AppleEventKitMCPCore"],
            path: "Sources/apple-eventkit-mcp"
        ),
        .testTarget(
            name: "AppleEventKitMCPCoreTests",
            dependencies: ["AppleEventKitMCPCore"],
            path: "Tests/AppleEventKitMCPCoreTests"
        )
    ]
)
