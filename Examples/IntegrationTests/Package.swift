// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IntegrationTests",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "IntegrationTests",
            dependencies: [
                .product(name: "LLMStructuredOutputs", package: "swift-llm-structured-outputs"),
            ],
            path: "Sources"
        ),
    ]
)
