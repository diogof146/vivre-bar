// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "vivre-bar",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .executable(name: "vivre-bar", targets: ["VivreBar"]),
    ],
    targets: [
        .executableTarget(
            name: "VivreBar",
            resources: [
                .copy("Resources"),
            ]
        ),
    ]
)
