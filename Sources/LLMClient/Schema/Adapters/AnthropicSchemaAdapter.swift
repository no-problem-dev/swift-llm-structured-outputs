import Foundation

// MARK: - AnthropicSchemaAdapter

/// Anthropic API 用のスキーマ適合
///
/// Anthropic API は JSON Schema の一部の制約をサポートしていません。
/// このアダプターはサポートされていない制約を除去したスキーマを生成します。
///
/// ## サポートされていない制約（プロンプトに変換）
///
/// - `maxItems`: 未サポート（除去され、プロンプトに変換）
/// - `minItems`: 0 と 1 以外の値は未サポート（2以上は除去され、プロンプトに変換）
/// - `minimum`, `maximum`: 未サポート（除去され、プロンプトに変換）
/// - `exclusiveMinimum`, `exclusiveMaximum`: 未サポート（除去され、プロンプトに変換）
/// - `minLength`, `maxLength`: 未サポート（除去され、プロンプトに変換）
///
/// ## サポートされている制約
///
/// - `pattern`: 正規表現パターン（注: 一部の高度なパターンは非対応）
/// - `enum`: 列挙値
/// - `format`: 文字列フォーマット
/// - `additionalProperties`: 追加プロパティの許可
///
/// ## pattern の制限事項
///
/// 以下の正規表現機能は Anthropic でサポートされていません：
/// - Backreferences
/// - Lookahead/Lookbehind
/// - Word boundaries (`\b`)
///
/// ## 使用例
///
/// ```swift
/// let adapter = AnthropicSchemaAdapter()
/// let schema = JSONSchema.string(minLength: 1, maxLength: 100)
///
/// // Anthropic 用に適合（制約追跡付き）
/// let result = adapter.adaptWithConstraints(schema)
/// let adaptedSchema = result.schema
/// // 除去された制約を Prompt に変換
/// if let constraintPrompt = result.toConstraintPrompt() {
///     let finalSystemPrompt = systemPrompt + constraintPrompt
/// }
/// ```
package struct AnthropicSchemaAdapter: ProviderSchemaAdapter {
    // MARK: - Initializer

    /// AnthropicSchemaAdapter を初期化
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

        // minItems のサニタイズ（0 または 1 のみ許可）
        // 2以上の値は除去してプロンプトに変換
        var adaptedMinItems: Int? = nil
        if let minItems = schema.minItems {
            if minItems <= 1 {
                adaptedMinItems = minItems
            } else {
                // 2以上の minItems は除去してプロンプトに変換
                removedConstraints.append(RemovedConstraint(
                    type: .minItems,
                    fieldPath: fieldPath,
                    value: .int(minItems)
                ))
            }
        }

        // maxItems は完全に非サポート
        if let maxItems = schema.maxItems {
            removedConstraints.append(RemovedConstraint(
                type: .maxItems,
                fieldPath: fieldPath,
                value: .int(maxItems)
            ))
        }

        // 数値制約は非サポート
        if let minimum = schema.minimum {
            removedConstraints.append(RemovedConstraint(
                type: .minimum,
                fieldPath: fieldPath,
                value: .int(minimum)
            ))
        }

        if let maximum = schema.maximum {
            removedConstraints.append(RemovedConstraint(
                type: .maximum,
                fieldPath: fieldPath,
                value: .int(maximum)
            ))
        }

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

        // 文字列長制約は非サポート
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

        let adaptedSchema = JSONSchema(
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
            pattern: schema.pattern, // サポートされている（一部制限あり）
            enum: schema.enum,
            format: schema.format    // サポートされている
        )

        return SchemaAdaptationResult(
            schema: adaptedSchema,
            removedConstraints: removedConstraints
        )
    }
}
