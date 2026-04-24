// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MarketView",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MarketView",
            path: "Sources/MarketView"
        )
    ]
)
