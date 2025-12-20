import Foundation
import LLMClient

// MARK: - DynamicStructured

/// ランタイムで構築可能な構造化出力定義
///
/// `@Structured` マクロを使わずに、プログラマティックに
/// 構造化出力の型を定義できます。
///
/// ## 使用例
///
/// ```swift
/// let userInfo = DynamicStructured("UserInfo", description: "ユーザー情報") {
///     JSONSchema.string(description: "ユーザー名", minLength: 1)
///         .named("name")
///
///     JSONSchema.integer(description: "年齢", minimum: 0, maximum: 150)
///         .named("age")
///         .optional()
///
///     JSONSchema.enum(["admin", "user", "guest"], description: "権限")
///         .named("role")
/// }
///
/// let result = try await client.generate(
///     prompt: "田中太郎さん（35歳、管理者）の情報を抽出",
///     model: .sonnet,
///     output: userInfo
/// )
/// ```
public struct DynamicStructured: Sendable {
    /// 構造体の名前
    public let name: String

    /// 構造体の説明
    public let description: String?

    /// フィールド定義のリスト
    public let fields: [NamedSchema]

    // MARK: - Initializers

    /// Result Builder を使用して初期化
    ///
    /// - Parameters:
    ///   - name: 構造体の名前
    ///   - description: 構造体の説明
    ///   - builder: フィールド定義を構築するクロージャ
    public init(
        _ name: String,
        description: String? = nil,
        @StructuredBuilder _ builder: () -> [NamedSchema]
    ) {
        self.name = name
        self.description = description
        self.fields = builder()
    }

    /// 直接フィールドを指定して初期化
    ///
    /// - Parameters:
    ///   - name: 構造体の名前
    ///   - description: 構造体の説明
    ///   - fields: フィールド定義のリスト
    public init(
        name: String,
        description: String? = nil,
        fields: [NamedSchema]
    ) {
        self.name = name
        self.description = description
        self.fields = fields
    }

    // MARK: - JSONSchema Conversion

    /// JSON Schema に変換
    ///
    /// フィールド定義から完全な JSON Schema オブジェクトを構築します。
    ///
    /// - Returns: オブジェクト型の JSON Schema
    public func toJSONSchema() -> JSONSchema {
        var properties: [String: JSONSchema] = [:]
        var required: [String] = []

        for field in fields {
            properties[field.name] = field.schema
            if field.isRequired {
                required.append(field.name)
            }
        }

        return JSONSchema.object(
            description: description,
            properties: properties,
            required: required.isEmpty ? nil : required,
            additionalProperties: false
        )
    }
}

// MARK: - Equatable

extension DynamicStructured: Equatable {
    public static func == (lhs: DynamicStructured, rhs: DynamicStructured) -> Bool {
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.fields.count == rhs.fields.count &&
        zip(lhs.fields, rhs.fields).allSatisfy { lhsField, rhsField in
            lhsField.name == rhsField.name &&
            lhsField.isRequired == rhsField.isRequired &&
            lhsField.schema == rhsField.schema
        }
    }
}

// MARK: - CustomDebugStringConvertible

extension DynamicStructured: CustomDebugStringConvertible {
    public var debugDescription: String {
        let schemaString = (try? toJSONSchema().toJSONString(prettyPrinted: true)) ?? "{}"
        return "DynamicStructured(\(name)): \(schemaString)"
    }
}
