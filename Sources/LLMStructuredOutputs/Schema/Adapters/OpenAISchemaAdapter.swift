import Foundation

// MARK: - OpenAISchemaAdapter

/// OpenAI API 用のスキーマ適合
///
/// OpenAI Structured Outputs には厳格な制約があります。
/// このアダプターはこれらの制約に適合したスキーマを生成します。
///
/// ## OpenAI Structured Outputs の制約
///
/// - `additionalProperties`: オブジェクト型では必ず `false` に設定
/// - `required`: すべてのプロパティを含める必要がある
/// - オプショナルフィールドは型を `["original_type", "null"]` の union 型で表現
///   （※この変換はマクロ側で対応が必要）
///
/// ## サポートされていない制約
///
/// - `format`: 未サポート（除去される）
/// - `minLength`, `maxLength`: 未サポート（除去される）
/// - `pattern`: 未サポート（除去される）
/// - `minimum`, `maximum`: 未サポート（除去される）
/// - `exclusiveMinimum`, `exclusiveMaximum`: 未サポート（除去される）
///
/// ## サポートされている制約
///
/// - `minItems`, `maxItems`: 配列の要素数制約
/// - `enum`: 列挙値
///
/// ## 使用例
///
/// ```swift
/// let adapter = OpenAISchemaAdapter()
/// let schema = JSONSchema.object(
///     properties: ["name": .string()],
///     required: ["name"]
/// )
///
/// // OpenAI 用に適合
/// // - additionalProperties: false が設定される
/// // - required にすべてのプロパティが含まれる
/// let adapted = adapter.adapt(schema)
/// ```
///
/// ## 注意事項
///
/// このアダプターは既存のスキーマからオプショナル情報を推論できないため、
/// すべてのプロパティを required として扱います。
/// オプショナルフィールドのサポートはマクロ側で別途対応が必要です。
internal struct OpenAISchemaAdapter: ProviderSchemaAdapter {
    // MARK: - Initializer

    /// OpenAISchemaAdapter を初期化
    init() {}

    // MARK: - ProviderSchemaAdapter

    func adapt(_ schema: JSONSchema) -> JSONSchema {
        // プロパティを再帰的に適合
        let adaptedProperties = adaptProperties(schema.properties)

        // items を再帰的に適合
        let adaptedItems = adaptItems(schema.items)

        // OpenAI では required 配列にすべてのプロパティキーを含める必要がある
        let allRequired: [String]?
        if let props = adaptedProperties {
            allRequired = Array(props.keys).sorted()
        } else {
            allRequired = schema.required
        }

        return JSONSchema(
            type: schema.type,
            description: schema.description,
            properties: adaptedProperties,
            required: allRequired,
            items: adaptedItems,
            additionalProperties: schema.type == .object ? false : schema.additionalProperties,
            minItems: schema.minItems,
            maxItems: schema.maxItems,
            minimum: nil,            // OpenAI は minimum をサポートしない
            maximum: nil,            // OpenAI は maximum をサポートしない
            exclusiveMinimum: nil,   // OpenAI は exclusiveMinimum をサポートしない
            exclusiveMaximum: nil,   // OpenAI は exclusiveMaximum をサポートしない
            minLength: nil,          // OpenAI は minLength をサポートしない
            maxLength: nil,          // OpenAI は maxLength をサポートしない
            pattern: nil,            // OpenAI は pattern をサポートしない
            enum: schema.enum,
            format: nil              // OpenAI は format をサポートしない
        )
    }
}
