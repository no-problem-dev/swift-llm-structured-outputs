// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ExamplesCommon",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ExamplesCommon",
            targets: ["ExamplesCommon"]
        )
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .target(
            name: "ExamplesCommon",
            dependencies: [
                .product(name: "LLMStructuredOutputs", package: "swift-llm-structured-outputs")
            ],
            path: "Sources"
        )
    ]
)
