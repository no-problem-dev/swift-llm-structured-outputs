// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "swift-llm-structured-outputs",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "LLMStructuredOutputs",
            targets: ["LLMStructuredOutputs"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.4.0"),
    ],
    targets: [
        // MARK: - Macro Implementation
        .macro(
            name: "StructuredMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // MARK: - Main Library
        .target(
            name: "LLMStructuredOutputs",
            dependencies: ["StructuredMacros"]
        ),

        // MARK: - Tests
        .testTarget(
            name: "LLMStructuredOutputsTests",
            dependencies: ["LLMStructuredOutputs"]
        ),
        .testTarget(
            name: "StructuredMacrosTests",
            dependencies: [
                "StructuredMacros",
                "LLMStructuredOutputs",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
