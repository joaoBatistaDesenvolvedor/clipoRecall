// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClipRecall",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClipRecall",
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
