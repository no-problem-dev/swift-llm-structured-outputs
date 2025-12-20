import Foundation
import LLMClient

// MARK: - JSONSchema Named Extensions

extension JSONSchema {
    /// 名前を付けて NamedSchema に変換
    ///
    /// `DynamicStructured` のフィールドとして使用するために、
    /// JSON Schema に名前を付与します。
    ///
    /// - Parameter name: フィールド名
    /// - Returns: 名前付きスキーマ（デフォルトで必須）
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// let field = JSONSchema.string(description: "ユーザー名")
    ///     .named("name")
    ///
    /// let optionalField = JSONSchema.integer(minimum: 0)
    ///     .named("age")
    ///     .optional()
    /// ```
    public func named(_ name: String) -> NamedSchema {
        NamedSchema(name: name, schema: self, isRequired: true)
    }
}
