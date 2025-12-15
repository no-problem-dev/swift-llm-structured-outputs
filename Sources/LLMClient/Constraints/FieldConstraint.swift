/// フィールドに適用可能な制約
///
/// JSON Schema の keywords に準拠した制約を定義します。
/// `@StructuredField` マクロと組み合わせて使用します。
///
/// ```swift
/// @Structured("商品情報")
/// struct Product {
///     @StructuredField("商品名", .minLength(1), .maxLength(100))
///     var name: String
///
///     @StructuredField("価格", .minimum(0))
///     var price: Int
///
///     @StructuredField("タグ", .minItems(1), .maxItems(10))
///     var tags: [String]
///
///     @StructuredField("カテゴリ", .enum(["electronics", "clothing", "food"]))
///     var category: String
/// }
/// ```
public enum FieldConstraint: Sendable, Equatable {
    // MARK: - Array Constraints

    /// 配列の最小要素数
    case minItems(Int)

    /// 配列の最大要素数
    case maxItems(Int)

    // MARK: - Numeric Constraints

    /// 数値の最小値（その値を含む）
    case minimum(Int)

    /// 数値の最大値（その値を含む）
    case maximum(Int)

    /// 数値の最小値（その値を含まない）
    case exclusiveMinimum(Int)

    /// 数値の最大値（その値を含まない）
    case exclusiveMaximum(Int)

    // MARK: - String Constraints

    /// 文字列の最小長
    case minLength(Int)

    /// 文字列の最大長
    case maxLength(Int)

    /// 文字列の正規表現パターン
    case pattern(String)

    // MARK: - Enum Constraint

    /// 許可される値のリスト
    case `enum`([String])

    // MARK: - Format Constraints

    /// 文字列のフォーマット（JSON Schema format）
    case format(StringFormat)

    /// JSON Schema で定義されている文字列フォーマット
    public enum StringFormat: String, Sendable, Equatable {
        /// メールアドレス形式
        case email

        /// URI形式
        case uri

        /// UUID形式
        case uuid

        /// 日付形式 (YYYY-MM-DD)
        case date

        /// 時刻形式 (HH:MM:SS)
        case time

        /// 日時形式 (ISO 8601)
        case dateTime = "date-time"

        /// IPv4アドレス形式
        case ipv4

        /// IPv6アドレス形式
        case ipv6

        /// ホスト名形式
        case hostname

        /// 期間形式 (ISO 8601 duration)
        case duration
    }
}

// MARK: - Convenience Extensions

extension FieldConstraint {
    /// 配列の要素数範囲を指定
    ///
    /// ```swift
    /// @StructuredField("タグ", .items(1...5))
    /// var tags: [String]
    /// ```
    public static func items(_ range: ClosedRange<Int>) -> [FieldConstraint] {
        [.minItems(range.lowerBound), .maxItems(range.upperBound)]
    }

    /// 数値の範囲を指定
    ///
    /// ```swift
    /// @StructuredField("評価", .range(1...5))
    /// var rating: Int
    /// ```
    public static func range(_ range: ClosedRange<Int>) -> [FieldConstraint] {
        [.minimum(range.lowerBound), .maximum(range.upperBound)]
    }

    /// 文字列の長さ範囲を指定
    ///
    /// ```swift
    /// @StructuredField("ユーザー名", .length(3...20))
    /// var username: String
    /// ```
    public static func length(_ range: ClosedRange<Int>) -> [FieldConstraint] {
        [.minLength(range.lowerBound), .maxLength(range.upperBound)]
    }
}
