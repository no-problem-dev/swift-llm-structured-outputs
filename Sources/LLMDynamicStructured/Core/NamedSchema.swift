import Foundation
import LLMClient

// MARK: - NamedSchema

/// 名前付きスキーマ
///
/// `JSONSchema` に名前と必須情報を付加した型です。
/// `DynamicStructured` のフィールド定義として使用されます。
///
/// ## 使用例
///
/// ```swift
/// let field = JSONSchema.string(description: "ユーザー名")
///     .named("name")
///     .required()
/// ```
public struct NamedSchema: Sendable {
    /// フィールド名
    public let name: String

    /// JSON Schema 定義
    public let schema: JSONSchema

    /// 必須フィールドかどうか
    public let isRequired: Bool

    /// 初期化
    ///
    /// - Parameters:
    ///   - name: フィールド名
    ///   - schema: JSON Schema 定義
    ///   - isRequired: 必須フィールドかどうか（デフォルト: true）
    public init(name: String, schema: JSONSchema, isRequired: Bool = true) {
        self.name = name
        self.schema = schema
        self.isRequired = isRequired
    }
}

// MARK: - Modifiers

extension NamedSchema {
    /// 必須フィールドとしてマーク
    ///
    /// - Returns: 必須フィールドとしてマークされた NamedSchema
    public func required() -> NamedSchema {
        NamedSchema(name: name, schema: schema, isRequired: true)
    }

    /// オプショナルフィールドとしてマーク
    ///
    /// - Returns: オプショナルフィールドとしてマークされた NamedSchema
    public func optional() -> NamedSchema {
        NamedSchema(name: name, schema: schema, isRequired: false)
    }
}

// MARK: - StructuredBuilder Support

/// `StructuredBuilder` で使用可能な型のプロトコル
public protocol NamedSchemaConvertible: Sendable {
    /// NamedSchema に変換
    func asNamedSchema() -> NamedSchema
}

extension NamedSchema: NamedSchemaConvertible {
    public func asNamedSchema() -> NamedSchema {
        self
    }
}
