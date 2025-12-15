import Foundation

// MARK: - ProviderSchemaAdapter

/// JSON Schema をプロバイダー固有の形式に適合させるプロトコル
///
/// 各 LLM プロバイダー（Anthropic, OpenAI, Gemini）は JSON Schema の
/// サポート範囲が異なります。このプロトコルを実装することで、
/// 汎用的な JSON Schema をプロバイダー固有の制約に適合させることができます。
///
/// ## 使用例
///
/// ```swift
/// let schema = JSONSchema.object(
///     properties: [
///         "name": .string(minLength: 1, maxLength: 100),
///         "age": .integer(minimum: 0, maximum: 150)
///     ],
///     required: ["name", "age"]
/// )
///
/// // Anthropic 用に適合
/// let anthropicAdapter = AnthropicSchemaAdapter()
/// let anthropicSchema = anthropicAdapter.adapt(schema)
///
/// // OpenAI 用に適合
/// let openAIAdapter = OpenAISchemaAdapter()
/// let openAISchema = openAIAdapter.adapt(schema)
/// ```
///
/// ## カスタム Adapter の実装
///
/// ```swift
/// struct CustomProviderAdapter: ProviderSchemaAdapter {
///     func adapt(_ schema: JSONSchema) -> JSONSchema {
///         // カスタム変換ロジック
///     }
/// }
/// ```
internal protocol ProviderSchemaAdapter: Sendable {
    /// スキーマをプロバイダー固有の形式に適合させる
    ///
    /// - Parameter schema: 元の JSON Schema
    /// - Returns: プロバイダーに適合した JSON Schema
    func adapt(_ schema: JSONSchema) -> JSONSchema
}

// MARK: - Default Implementation

extension ProviderSchemaAdapter {
    /// プロパティを再帰的に適合させる
    ///
    /// - Parameter properties: プロパティのディクショナリ
    /// - Returns: 適合されたプロパティのディクショナリ
    func adaptProperties(_ properties: [String: JSONSchema]?) -> [String: JSONSchema]? {
        properties?.mapValues { adapt($0) }
    }

    /// items を再帰的に適合させる
    ///
    /// - Parameter items: 配列要素のスキーマ（Box でラップされている）
    /// - Returns: 適合された配列要素のスキーマ
    func adaptItems(_ items: Box<JSONSchema>?) -> JSONSchema? {
        items.map { adapt($0.value) }
    }
}
