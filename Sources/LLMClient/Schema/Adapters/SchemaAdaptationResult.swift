import Foundation

// MARK: - SchemaAdaptationResult

/// スキーマ適合の結果
///
/// プロバイダー固有のスキーマ適合処理の結果を保持します。
/// 適合後のスキーマと、プロバイダーでサポートされていないため除去された制約の情報を含みます。
///
/// ## 使用例
///
/// ```swift
/// let adapter = OpenAISchemaAdapter()
/// let result = adapter.adaptWithConstraints(schema)
/// let adaptedSchema = result.schema
///
/// // 除去された制約を Prompt に変換（RemovedConstraint+Prompt.swift）
/// if let constraintPrompt = result.toConstraintPrompt() {
///     let finalSystemPrompt = systemPrompt + constraintPrompt
/// }
/// ```
package struct SchemaAdaptationResult: Sendable {
    /// 適合後のスキーマ
    public let schema: JSONSchema

    /// 除去された制約のリスト
    public let removedConstraints: [RemovedConstraint]

    /// 初期化
    package init(schema: JSONSchema, removedConstraints: [RemovedConstraint] = []) {
        self.schema = schema
        self.removedConstraints = removedConstraints
    }

    /// 除去された制約があるかどうか
    package var hasRemovedConstraints: Bool {
        !removedConstraints.isEmpty
    }
}

// MARK: - RemovedConstraint

/// 除去された制約の情報
///
/// プロバイダーでサポートされていないため除去された JSON Schema 制約を表します。
/// この情報はプロンプトに変換して LLM に指示として渡すことができます。
package struct RemovedConstraint: Sendable, Equatable {
    /// 制約の種類
    public let type: ConstraintType

    /// 制約が適用されていたフィールドのパス（例: "user.age", "items[].count"）
    public let fieldPath: String

    /// 制約の値
    public let value: ConstraintValue

    /// 初期化
    package init(type: ConstraintType, fieldPath: String, value: ConstraintValue) {
        self.type = type
        self.fieldPath = fieldPath
        self.value = value
    }
}

// MARK: - ConstraintType

/// 制約の種類
package enum ConstraintType: String, Sendable, Equatable {
    // 数値制約
    case minimum
    case maximum
    case exclusiveMinimum
    case exclusiveMaximum

    // 配列制約
    case minItems
    case maxItems

    // 文字列制約
    case minLength
    case maxLength
    case pattern

    // フォーマット
    case format

    /// 人間が読める説明
    package var description: String {
        switch self {
        case .minimum: return "minimum value"
        case .maximum: return "maximum value"
        case .exclusiveMinimum: return "exclusive minimum value"
        case .exclusiveMaximum: return "exclusive maximum value"
        case .minItems: return "minimum number of items"
        case .maxItems: return "maximum number of items"
        case .minLength: return "minimum length"
        case .maxLength: return "maximum length"
        case .pattern: return "pattern"
        case .format: return "format"
        }
    }
}

// MARK: - ConstraintValue

/// 制約の値
package enum ConstraintValue: Sendable, Equatable {
    case int(Int)
    case string(String)

    /// 文字列表現
    package var stringValue: String {
        switch self {
        case .int(let value): return String(value)
        case .string(let value): return value
        }
    }
}

