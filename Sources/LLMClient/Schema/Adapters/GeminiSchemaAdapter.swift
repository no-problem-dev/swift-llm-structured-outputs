import Foundation

// MARK: - GeminiSchemaAdapter

/// Gemini API 用のスキーマ適合
///
/// Gemini API は JSON Schema の一部の機能をサポートしていない場合があります。
/// このアダプターは互換性のないフィールドを除去したスキーマを生成します。
///
/// ## サポートされていない制約（プロンプトに変換）
///
/// - `additionalProperties`: 一部の API バージョンでサポートされていない（除去される）
/// - `exclusiveMinimum`, `exclusiveMaximum`: 未サポート（除去され、プロンプトに変換）
/// - `minLength`, `maxLength`: 未サポート（除去され、プロンプトに変換）
/// - `pattern`: 未サポート（除去され、プロンプトに変換）
///
/// ## サポートされている制約
///
/// - `minItems`, `maxItems`: 配列の要素数制約
/// - `minimum`, `maximum`: 数値の範囲制約（包括的）
/// - `enum`: 列挙値
/// - `format`: 一部のフォーマット（date-time, date, time）
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
/// // Gemini 用に適合（制約追跡付き）
/// let result = adapter.adaptWithConstraints(schema)
/// let adaptedSchema = result.schema
/// // 除去された制約を Prompt に変換
/// if let constraintPrompt = result.toConstraintPrompt() {
///     let finalSystemPrompt = systemPrompt + constraintPrompt
/// }
/// ```
package struct GeminiSchemaAdapter: ProviderSchemaAdapter {
    // MARK: - Initializer

    /// GeminiSchemaAdapter を初期化
    package init() {}

    // MARK: - ProviderSchemaAdapter

    package func adapt(_ schema: JSONSchema) -> JSONSchema {
        adaptWithConstraints(schema, fieldPath: "").schema
    }

    package func adaptWithConstraints(_ schema: JSONSchema, fieldPath: String) -> SchemaAdaptationResult {
        var removedConstraints: [RemovedConstraint] = []

        // プロパティを再帰的に適合（制約追跡付き）
        let (adaptedProperties, propertyConstraints) = adaptPropertiesWithConstraints(
            schema.properties,
            parentPath: fieldPath
        )
        removedConstraints.append(contentsOf: propertyConstraints)

        // items を再帰的に適合（制約追跡付き）
        let (adaptedItems, itemsConstraints) = adaptItemsWithConstraints(
            schema.items,
            parentPath: fieldPath
        )
        removedConstraints.append(contentsOf: itemsConstraints)

        // サポートされていない制約を追跡
        // Gemini は以下をサポートしない:
        // - exclusiveMinimum, exclusiveMaximum
        // - minLength, maxLength
        // - pattern

        if let exclusiveMinimum = schema.exclusiveMinimum {
            removedConstraints.append(RemovedConstraint(
                type: .exclusiveMinimum,
                fieldPath: fieldPath,
                value: .int(exclusiveMinimum)
            ))
        }

        if let exclusiveMaximum = schema.exclusiveMaximum {
            removedConstraints.append(RemovedConstraint(
                type: .exclusiveMaximum,
                fieldPath: fieldPath,
                value: .int(exclusiveMaximum)
            ))
        }

        if let minLength = schema.minLength {
            removedConstraints.append(RemovedConstraint(
                type: .minLength,
                fieldPath: fieldPath,
                value: .int(minLength)
            ))
        }

        if let maxLength = schema.maxLength {
            removedConstraints.append(RemovedConstraint(
                type: .maxLength,
                fieldPath: fieldPath,
                value: .int(maxLength)
            ))
        }

        if let pattern = schema.pattern {
            removedConstraints.append(RemovedConstraint(
                type: .pattern,
                fieldPath: fieldPath,
                value: .string(pattern)
            ))
        }

        // format は一部のみサポート (date-time, date, time)
        // サポートされていないフォーマットはプロンプトに変換
        let supportedFormats: Set<String> = ["date-time", "date", "time"]
        var adaptedFormat: String? = nil
        if let format = schema.format {
            if supportedFormats.contains(format) {
                adaptedFormat = format
            } else {
                // サポートされていないフォーマットを追跡
                removedConstraints.append(RemovedConstraint(
                    type: .format,
                    fieldPath: fieldPath,
                    value: .string(format)
                ))
            }
        }

        let adaptedSchema = JSONSchema(
            type: schema.type,
            description: schema.description,
            properties: adaptedProperties,
            required: schema.required,
            items: adaptedItems,
            additionalProperties: nil,       // Gemini では additionalProperties を除去
            minItems: schema.minItems,        // Gemini は minItems をサポート
            maxItems: schema.maxItems,        // Gemini は maxItems をサポート
            minimum: schema.minimum,          // Gemini は minimum をサポート
            maximum: schema.maximum,          // Gemini は maximum をサポート
            exclusiveMinimum: nil,            // Gemini は exclusiveMinimum をサポートしない
            exclusiveMaximum: nil,            // Gemini は exclusiveMaximum をサポートしない
            minLength: nil,                   // Gemini は minLength をサポートしない
            maxLength: nil,                   // Gemini は maxLength をサポートしない
            pattern: nil,                     // Gemini は pattern をサポートしない
            enum: schema.enum,
            format: adaptedFormat             // サポートされているフォーマットのみ
        )

        return SchemaAdaptationResult(
            schema: adaptedSchema,
            removedConstraints: removedConstraints
        )
    }
}
