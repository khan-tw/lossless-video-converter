// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FrameKeep",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FrameKeep", targets: ["FrameKeep"])
    ],
    targets: [
        .executableTarget(
            name: "FrameKeep",
            path: ".",
            exclude: [
                ".codex",
                ".gitignore",
                "LICENSE",
                "README.md",
                "build",
                "script",
                "Tests"
            ],
            sources: [
                "App",
                "Models",
                "Services",
                "Stores",
                "Support",
                "Views"
            ]
        ),
        .testTarget(
            name: "FrameKeepTests",
            dependencies: ["FrameKeep"],
            path: "Tests/FrameKeepTests"
        )
    ]
)
