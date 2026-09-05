// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Cage",
    platforms: [.macOS(.v11)],
    products: [
        .library(name: "CageCore", targets: ["CageCore"]),
        .executable(name: "Cage", targets: ["CageApp"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            exact: "2.9.6"
        ),
    ],
    targets: [
        .target(name: "CageCore"),
        .executableTarget(
            name: "CageApp",
            dependencies: [
                "CageCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
        .testTarget(name: "CageCoreTests", dependencies: ["CageCore"]),
        .testTarget(name: "CageAppTests", dependencies: ["CageApp"]),
    ]
)
