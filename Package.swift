// swift-tools-version: 6.2
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
        // オプション: MCPサーバー統合（外部MCPサーバーとの接続サポート）
        .library(
            name: "LLMMCP",
            targets: ["LLMMCP"]
        ),
        // オプション: 動的構造化出力（ランタイムでの型定義）
        .library(
            name: "LLMDynamicStructured",
            targets: ["LLMDynamicStructured"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", .upToNextMajor(from: "602.0.0")),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", .upToNextMajor(from: "1.4.0")),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", .upToNextMajor(from: "0.10.0")),
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

        // MARK: - Layer 1: LLMDynamicStructured (動的構造化出力)
        .target(
            name: "LLMDynamicStructured",
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
            dependencies: [
                "LLMClient",
                "LLMTool",
                "LLMConversation",
                "LLMAgent",
                "LLMConversationalAgent",
                "LLMDynamicStructured"
            ]
        ),

        // MARK: - Unit Tests (モジュール別テストターゲット)

        // LLMClient テスト（Prompt, Provider, Retry, Schema, Media）
        .testTarget(
            name: "LLMClientTests",
            dependencies: ["LLMClient"],
            path: "Tests/LLMClientTests"
        ),

        // LLMTool テスト（ToolSet, ToolResult）
        .testTarget(
            name: "LLMToolTests",
            dependencies: ["LLMTool", "LLMClient"],
            path: "Tests/LLMToolTests"
        ),

        // LLMAgent テスト
        .testTarget(
            name: "LLMAgentTests",
            dependencies: ["LLMAgent", "LLMTool", "LLMClient"],
            path: "Tests/LLMAgentTests"
        ),

        // LLMConversation テスト
        .testTarget(
            name: "LLMConversationTests",
            dependencies: ["LLMConversation", "LLMClient"],
            path: "Tests/LLMConversationTests"
        ),

        // LLMConversationalAgent テスト
        .testTarget(
            name: "LLMConversationalAgentTests",
            dependencies: ["LLMConversationalAgent", "LLMAgent", "LLMTool", "LLMClient"],
            path: "Tests/LLMConversationalAgentTests"
        ),

        // LLMDynamicStructured テスト
        .testTarget(
            name: "LLMDynamicStructuredTests",
            dependencies: ["LLMDynamicStructured", "LLMClient"],
            path: "Tests/LLMDynamicStructuredTests"
        ),

        // LLMMCP テスト
        .testTarget(
            name: "LLMMCPTests",
            dependencies: ["LLMMCP", "LLMTool", "LLMClient"],
            path: "Tests/LLMMCPTests"
        ),

        // StructuredMacros テスト
        .testTarget(
            name: "StructuredMacrosTests",
            dependencies: [
                "StructuredMacros",
                "LLMClient",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
            path: "Tests/StructuredMacrosTests"
        ),

        // MARK: - Integration Tests
        .testTarget(
            name: "IntegrationTests",
            dependencies: ["LLMStructuredOutputs"],
            path: "Tests/IntegrationTests"
        ),
    ]
)
