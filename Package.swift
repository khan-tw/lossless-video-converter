// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LosslessVideoConverter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LosslessVideoConverter", targets: ["LosslessVideoConverter"])
    ],
    targets: [
        .executableTarget(
            name: "LosslessVideoConverter",
            path: ".",
            exclude: [
                "dist-native",
                ".gitignore",
                "LICENSE",
                "Open Lossless Video Converter.command",
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
            name: "LosslessVideoConverterTests",
            dependencies: ["LosslessVideoConverter"],
            path: "Tests/LosslessVideoConverterTests"
        )
    ]
)
