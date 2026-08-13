// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DeskBuddies",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DeskBuddies", targets: ["DeskBuddies"])
    ],
    targets: [
        .executableTarget(
            name: "DeskBuddies",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "DeskBuddiesTests",
            dependencies: ["DeskBuddies"],
            path: "Tests"
        )
    ]
)
