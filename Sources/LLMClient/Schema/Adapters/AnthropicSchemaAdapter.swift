import Foundation

// MARK: - AnthropicSchemaAdapter

/// Anthropic API 用のスキーマ適合
///
/// Anthropic API は JSON Schema の一部の制約をサポートしていません。
/// このアダプターはサポートされていない制約を除去したスキーマを生成します。
///
/// ## サポートされていない制約
///
/// - `maxItems`: 未サポート（除去される）
/// - `minItems`: 0 と 1 以外の値は未サポート（0 または 1 に制限、それ以外は除去）
/// - `minimum`, `maximum`: 未サポート（除去される）
/// - `exclusiveMinimum`, `exclusiveMaximum`: 未サポート（除去される）
/// - `minLength`, `maxLength`: 未サポート（除去される）
///
/// ## サポートされている制約
///
/// - `pattern`: 正規表現パターン
/// - `enum`: 列挙値
/// - `format`: 文字列フォーマット
/// - `additionalProperties`: 追加プロパティの許可
///
/// ## 使用例
///
/// ```swift
/// let adapter = AnthropicSchemaAdapter()
/// let schema = JSONSchema.string(minLength: 1, maxLength: 100)
///
/// // Anthropic 用に適合（minLength, maxLength は除去される）
/// let adapted = adapter.adapt(schema)
/// ```
package struct AnthropicSchemaAdapter: ProviderSchemaAdapter {
    // MARK: - Initializer

    /// AnthropicSchemaAdapter を初期化
    package init() {}

    // MARK: - ProviderSchemaAdapter

    package func adapt(_ schema: JSONSchema) -> JSONSchema {
        // minItems のサニタイズ（0 または 1 のみ許可）
        let adaptedMinItems: Int? = if let minItems = schema.minItems, minItems <= 1 {
            minItems
        } else {
            nil
        }

        // プロパティを再帰的に適合
        let adaptedProperties = adaptProperties(schema.properties)

        // items を再帰的に適合
        let adaptedItems = adaptItems(schema.items)

        return JSONSchema(
            type: schema.type,
            description: schema.description,
            properties: adaptedProperties,
            required: schema.required,
            items: adaptedItems,
            additionalProperties: schema.additionalProperties,
            minItems: adaptedMinItems,
            maxItems: nil,           // Anthropic は maxItems をサポートしない
            minimum: nil,            // Anthropic は minimum をサポートしない
            maximum: nil,            // Anthropic は maximum をサポートしない
            exclusiveMinimum: nil,   // Anthropic は exclusiveMinimum をサポートしない
            exclusiveMaximum: nil,   // Anthropic は exclusiveMaximum をサポートしない
            minLength: nil,          // Anthropic は minLength をサポートしない
            maxLength: nil,          // Anthropic は maxLength をサポートしない
            pattern: schema.pattern,
            enum: schema.enum,
            format: schema.format
        )
    }
}
