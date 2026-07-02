// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "app-tracker",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "app-tracker",
            path: "Sources/app-tracker"
        )
    ]
)
