import Foundation
import LLMClient

// MARK: - StructuredBuilder

/// `DynamicStructured` のフィールドを宣言的に構築するための Result Builder
///
/// `JSONSchema` とその拡張メソッド `.named()` を組み合わせて、
/// 構造化出力の定義をパズルのように組み立てることができます。
///
/// ## 使用例
///
/// ```swift
/// let userInfo = DynamicStructured("UserInfo") {
///     // 必須の文字列フィールド
///     JSONSchema.string(description: "ユーザー名")
///         .named("name")
///
///     // オプショナルな整数フィールド
///     JSONSchema.integer(description: "年齢", minimum: 0)
///         .named("age")
///         .optional()
///
///     // 条件付きフィールド
///     if includeEmail {
///         JSONSchema.string(description: "メール", format: "email")
///             .named("email")
///     }
///
///     // 配列から動的に生成
///     for tag in requiredTags {
///         JSONSchema.string(description: tag.description)
///             .named(tag.name)
///     }
/// }
/// ```
@resultBuilder
public struct StructuredBuilder {
    /// 複数のフィールドを結合
    public static func buildBlock(_ components: NamedSchemaConvertible...) -> [NamedSchema] {
        components.map { $0.asNamedSchema() }
    }

    /// 複数の配列を結合
    public static func buildBlock(_ components: [NamedSchema]...) -> [NamedSchema] {
        components.flatMap { $0 }
    }

    /// 単一の式を配列に変換
    public static func buildExpression(_ expression: NamedSchemaConvertible) -> [NamedSchema] {
        [expression.asNamedSchema()]
    }

    /// オプショナルな要素を処理
    public static func buildOptional(_ component: [NamedSchema]?) -> [NamedSchema] {
        component ?? []
    }

    /// if-else の最初の分岐
    public static func buildEither(first component: [NamedSchema]) -> [NamedSchema] {
        component
    }

    /// if-else の2番目の分岐
    public static func buildEither(second component: [NamedSchema]) -> [NamedSchema] {
        component
    }

    /// for ループからの配列を結合
    public static func buildArray(_ components: [[NamedSchema]]) -> [NamedSchema] {
        components.flatMap { $0 }
    }

    /// 最終結果を返す
    public static func buildFinalResult(_ component: [NamedSchema]) -> [NamedSchema] {
        component
    }
}
