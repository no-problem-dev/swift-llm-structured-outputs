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
/// ## サポートされていない制約（プロンプトに変換）
///
/// - `format`: 未サポート（除去され、プロンプトに変換）
/// - `minLength`, `maxLength`: 未サポート（除去され、プロンプトに変換）
/// - `pattern`: 未サポート（除去され、プロンプトに変換）
/// - `minimum`, `maximum`: 未サポート（除去され、プロンプトに変換）
/// - `exclusiveMinimum`, `exclusiveMaximum`: 未サポート（除去され、プロンプトに変換）
/// - `minItems`, `maxItems`: 未サポート（除去され、プロンプトに変換）
///
/// ## サポートされている制約
///
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
/// // OpenAI 用に適合（制約追跡付き）
/// let result = adapter.adaptWithConstraints(schema)
/// let adaptedSchema = result.schema
/// // 除去された制約を Prompt に変換
/// if let constraintPrompt = result.toConstraintPrompt() {
///     let finalSystemPrompt = systemPrompt + constraintPrompt
/// }
/// ```
///
/// ## 注意事項
///
/// このアダプターは既存のスキーマからオプショナル情報を推論できないため、
/// すべてのプロパティを required として扱います。
/// オプショナルフィールドのサポートはマクロ側で別途対応が必要です。
package struct OpenAISchemaAdapter: ProviderSchemaAdapter {
    // MARK: - Initializer

    /// OpenAISchemaAdapter を初期化
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

        // OpenAI では required 配列にすべてのプロパティキーを含める必要がある
        let allRequired: [String]?
        if let props = adaptedProperties {
            allRequired = Array(props.keys).sorted()
        } else {
            allRequired = schema.required
        }

        // サポートされていない制約を追跡
        // OpenAI は以下をサポートしない:
        // - minimum, maximum, exclusiveMinimum, exclusiveMaximum
        // - minLength, maxLength, pattern
        // - minItems, maxItems
        // - format

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

        if let minItems = schema.minItems {
            removedConstraints.append(RemovedConstraint(
                type: .minItems,
                fieldPath: fieldPath,
                value: .int(minItems)
            ))
        }

        if let maxItems = schema.maxItems {
            removedConstraints.append(RemovedConstraint(
                type: .maxItems,
                fieldPath: fieldPath,
                value: .int(maxItems)
            ))
        }

        if let format = schema.format {
            removedConstraints.append(RemovedConstraint(
                type: .format,
                fieldPath: fieldPath,
                value: .string(format)
            ))
        }

        let adaptedSchema = JSONSchema(
            type: schema.type,
            description: schema.description,
            properties: adaptedProperties,
            required: allRequired,
            items: adaptedItems,
            additionalProperties: schema.type == .object ? false : schema.additionalProperties,
            minItems: nil,            // OpenAI は minItems をサポートしない
            maxItems: nil,            // OpenAI は maxItems をサポートしない
            minimum: nil,             // OpenAI は minimum をサポートしない
            maximum: nil,             // OpenAI は maximum をサポートしない
            exclusiveMinimum: nil,    // OpenAI は exclusiveMinimum をサポートしない
            exclusiveMaximum: nil,    // OpenAI は exclusiveMaximum をサポートしない
            minLength: nil,           // OpenAI は minLength をサポートしない
            maxLength: nil,           // OpenAI は maxLength をサポートしない
            pattern: nil,             // OpenAI は pattern をサポートしない
            enum: schema.enum,
            format: nil               // OpenAI は format をサポートしない
        )

        return SchemaAdaptationResult(
            schema: adaptedSchema,
            removedConstraints: removedConstraints
        )
    }
}
