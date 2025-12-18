import Foundation
import LLMClient

// MARK: - ToolDefinition

/// ツール定義情報（シリアライズ可能）
///
/// プロバイダーへ送信するツール定義を表します。
/// 実行機能は含まず、定義情報のみを保持します。
///
/// ## 使用例
///
/// ```swift
/// let tools = ToolSet {
///     GetWeather()
///     Calculator()
/// }
///
/// // ツール定義を取得
/// for definition in tools.definitions {
///     print("Tool: \(definition.name)")
///     print("Description: \(definition.description)")
/// }
/// ```
public struct ToolDefinition: Sendable, Equatable {
    /// ツール名
    public let name: String

    /// ツールの説明
    public let description: String

    /// 引数のスキーマ
    public let inputSchema: JSONSchema

    public init(name: String, description: String, inputSchema: JSONSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

// MARK: - Tool Extension

extension Tool {
    /// ToolDefinition に変換
    public var definition: ToolDefinition {
        ToolDefinition(
            name: toolName,
            description: toolDescription,
            inputSchema: inputSchema
        )
    }
}
