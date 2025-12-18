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
/// // Anthropic 用に適合（制約情報付き）
/// let anthropicAdapter = AnthropicSchemaAdapter()
/// let result = anthropicAdapter.adaptWithConstraints(schema)
/// let anthropicSchema = result.schema
/// // 除去された制約を Prompt に変換（RemovedConstraint+Prompt.swift）
/// if let constraintPrompt = result.toConstraintPrompt() {
///     let finalSystemPrompt = systemPrompt + constraintPrompt
/// }
///
/// // OpenAI 用に適合
/// let openAIAdapter = OpenAISchemaAdapter()
/// let openAIResult = openAIAdapter.adaptWithConstraints(schema)
/// ```
///
/// ## カスタム Adapter の実装
///
/// ```swift
/// struct CustomProviderAdapter: ProviderSchemaAdapter {
///     func adapt(_ schema: JSONSchema) -> JSONSchema {
///         // カスタム変換ロジック
///     }
///
///     func adaptWithConstraints(_ schema: JSONSchema, fieldPath: String) -> SchemaAdaptationResult {
///         // 制約追跡付きの変換ロジック
///     }
/// }
/// ```
internal protocol ProviderSchemaAdapter: Sendable {
    /// スキーマをプロバイダー固有の形式に適合させる
    ///
    /// - Parameter schema: 元の JSON Schema
    /// - Returns: プロバイダーに適合した JSON Schema
    func adapt(_ schema: JSONSchema) -> JSONSchema

    /// スキーマをプロバイダー固有の形式に適合させ、除去された制約を追跡
    ///
    /// - Parameters:
    ///   - schema: 元の JSON Schema
    ///   - fieldPath: 現在のフィールドパス（再帰呼び出し用）
    /// - Returns: 適合結果（スキーマと除去された制約）
    func adaptWithConstraints(_ schema: JSONSchema, fieldPath: String) -> SchemaAdaptationResult
}

// MARK: - Default Implementation

extension ProviderSchemaAdapter {
    /// 制約追跡付き適合のデフォルト実装（ルートから開始）
    func adaptWithConstraints(_ schema: JSONSchema) -> SchemaAdaptationResult {
        adaptWithConstraints(schema, fieldPath: "")
    }

    /// プロパティを再帰的に適合させる
    ///
    /// - Parameter properties: プロパティのディクショナリ
    /// - Returns: 適合されたプロパティのディクショナリ
    func adaptProperties(_ properties: [String: JSONSchema]?) -> [String: JSONSchema]? {
        properties?.mapValues { adapt($0) }
    }

    /// プロパティを再帰的に適合させ、除去された制約を収集
    ///
    /// - Parameters:
    ///   - properties: プロパティのディクショナリ
    ///   - parentPath: 親フィールドのパス
    /// - Returns: 適合されたプロパティと除去された制約
    func adaptPropertiesWithConstraints(
        _ properties: [String: JSONSchema]?,
        parentPath: String
    ) -> ([String: JSONSchema]?, [RemovedConstraint]) {
        guard let properties = properties else { return (nil, []) }

        var adaptedProperties: [String: JSONSchema] = [:]
        var allConstraints: [RemovedConstraint] = []

        for (key, value) in properties {
            let fieldPath = parentPath.isEmpty ? key : "\(parentPath).\(key)"
            let result = adaptWithConstraints(value, fieldPath: fieldPath)
            adaptedProperties[key] = result.schema
            allConstraints.append(contentsOf: result.removedConstraints)
        }

        return (adaptedProperties, allConstraints)
    }

    /// items を再帰的に適合させる
    ///
    /// - Parameter items: 配列要素のスキーマ（Box でラップされている）
    /// - Returns: 適合された配列要素のスキーマ
    func adaptItems(_ items: Box<JSONSchema>?) -> JSONSchema? {
        items.map { adapt($0.value) }
    }

    /// items を再帰的に適合させ、除去された制約を収集
    ///
    /// - Parameters:
    ///   - items: 配列要素のスキーマ（Box でラップされている）
    ///   - parentPath: 親フィールドのパス
    /// - Returns: 適合されたスキーマと除去された制約
    func adaptItemsWithConstraints(
        _ items: Box<JSONSchema>?,
        parentPath: String
    ) -> (JSONSchema?, [RemovedConstraint]) {
        guard let items = items else { return (nil, []) }
        let itemPath = "\(parentPath)[]"
        let result = adaptWithConstraints(items.value, fieldPath: itemPath)
        return (result.schema, result.removedConstraints)
    }
}
