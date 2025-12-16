import Foundation

// MARK: - GeminiSchemaAdapter

/// Gemini API 用のスキーマ適合
///
/// Gemini API は JSON Schema の一部の機能をサポートしていない場合があります。
/// このアダプターは互換性のないフィールドを除去したスキーマを生成します。
///
/// ## サポートされていない可能性のある制約
///
/// - `additionalProperties`: 一部の API バージョンでサポートされていない可能性
///   （除去される）
///
/// ## サポートされている制約
///
/// - `minItems`, `maxItems`: 配列の要素数制約
/// - `minimum`, `maximum`: 数値の範囲制約
/// - `exclusiveMinimum`, `exclusiveMaximum`: 排他的な範囲制約
/// - `minLength`, `maxLength`: 文字列の長さ制約
/// - `pattern`: 正規表現パターン
/// - `enum`: 列挙値
/// - `format`: 文字列フォーマット
///
/// ## 使用例
///
/// ```swift
/// let adapter = GeminiSchemaAdapter()
/// let schema = JSONSchema.object(
///     properties: ["name": .string()],
///     additionalProperties: false
/// )
///
/// // Gemini 用に適合（additionalProperties が除去される）
/// let adapted = adapter.adapt(schema)
/// ```
package struct GeminiSchemaAdapter: ProviderSchemaAdapter {
    // MARK: - Initializer

    /// GeminiSchemaAdapter を初期化
    package init() {}

    // MARK: - ProviderSchemaAdapter

    package func adapt(_ schema: JSONSchema) -> JSONSchema {
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
            additionalProperties: nil,  // Gemini では additionalProperties を除去
            minItems: schema.minItems,
            maxItems: schema.maxItems,
            minimum: schema.minimum,
            maximum: schema.maximum,
            exclusiveMinimum: schema.exclusiveMinimum,
            exclusiveMaximum: schema.exclusiveMaximum,
            minLength: schema.minLength,
            maxLength: schema.maxLength,
            pattern: schema.pattern,
            enum: schema.enum,
            format: schema.format
        )
    }
}
