import Foundation

// MARK: - JSONSchemaType

/// JSON Schema の型
///
/// JSON Schema 仕様で定義されている基本型を表します。
/// 各型は JSON データの構造やバリデーションに使用されます。
///
/// ## 使用例
///
/// ```swift
/// let schema = JSONSchema(type: .string, description: "名前")
/// let objectSchema = JSONSchema(type: .object, properties: [...])
/// ```
public enum JSONSchemaType: String, Sendable, Encodable, Equatable {
    /// オブジェクト型（キーと値のペア）
    case object

    /// 配列型（順序付きリスト）
    case array

    /// 文字列型
    case string

    /// 整数型
    case integer

    /// 数値型（整数または浮動小数点）
    case number

    /// 真偽値型
    case boolean

    /// null 型
    case null
}
