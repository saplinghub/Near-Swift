// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NearCountdown",
    platforms: [
        .macOS("12.0")
    ],
    products: [
        .executable(
            name: "NearCountdown",
            targets: ["NearCountdown"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "NearCountdown",
            dependencies: [],
            path: ".",
            exclude: ["build-dmg.sh", "dist", "README.md", "Info.plist", "Resources", "Resources/doc"],
            sources: [
                "App.swift",
                "Models",
                "Services",
                "Views",
                "Utils"
            ],
            resources: [
                .process("Resources/icons"),
                .process("Resources/fonts"),
                .process("Resources/sounds")
            ]
        )
    ]
)