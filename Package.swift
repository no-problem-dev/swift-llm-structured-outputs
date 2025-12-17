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
        // メインのアンブレラモジュール
        .library(
            name: "LLMStructuredOutputs",
            targets: ["LLMStructuredOutputs"]
        ),
        // オプション: 高レベルツールキット（プリセット、組み込みツール、共通出力）
        .library(
            name: "LLMToolkits",
            targets: ["LLMToolkits"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.4.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.8.2"),
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

        // MARK: - Layer 0: LLMClient (基本クライアント・プロバイダー)
        .target(
            name: "LLMClient",
            dependencies: ["StructuredMacros"]
        ),

        // MARK: - Layer 1: LLMTool (ツール定義・実行)
        .target(
            name: "LLMTool",
            dependencies: ["LLMClient"]
        ),

        // MARK: - Layer 1: LLMConversation (会話管理)
        .target(
            name: "LLMConversation",
            dependencies: ["LLMClient"]
        ),

        // MARK: - Layer 2: LLMAgent (エージェントループ)
        .target(
            name: "LLMAgent",
            dependencies: ["LLMClient", "LLMTool"]
        ),

        // MARK: - Layer 2: LLMMCP (MCPサーバー統合)
        .target(
            name: "LLMMCP",
            dependencies: [
                "LLMClient",
                "LLMTool",
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),

        // MARK: - Layer 3: LLMConversationalAgent (会話型エージェント)
        .target(
            name: "LLMConversationalAgent",
            dependencies: ["LLMClient", "LLMTool", "LLMAgent"]
        ),

        // MARK: - Layer 3: LLMToolkits (デフォルトプロンプト・ツール集)
        .target(
            name: "LLMToolkits",
            dependencies: ["LLMClient", "LLMTool", "LLMAgent"]
        ),

        // MARK: - Umbrella Module (全モジュールを再エクスポート)
        .target(
            name: "LLMStructuredOutputs",
            dependencies: ["LLMClient", "LLMTool", "LLMConversation", "LLMAgent", "LLMConversationalAgent", "LLMMCP"]
        ),

        // MARK: - Tests
        .testTarget(
            name: "LLMStructuredOutputsTests",
            dependencies: ["LLMStructuredOutputs"]
        ),
        .testTarget(
            name: "LLMMCPTests",
            dependencies: ["LLMMCP", "LLMStructuredOutputs"]
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
