// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Taskly",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Taskly",
            path: "Sources/Taskly",
            resources: [.copy("Fonts")]
        )
    ]
)
