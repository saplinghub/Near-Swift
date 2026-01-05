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
    dependencies: [
        .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.4.1")
    ],
    targets: [
        .executableTarget(
            name: "NearCountdown",
            dependencies: [
                .product(name: "Lottie", package: "lottie-spm")
            ],
            path: ".",
            exclude: ["build-dmg.sh", "dist", "README.md", "Info.plist", "Resources/doc"],
            sources: [
                "App.swift",
                "Models",
                "Services",
                "Views",
                "Utils"
            ],
            resources: [
                .process("Resources/icons"),
                .process("Resources/lottie")
            ]
        )
    ]
)