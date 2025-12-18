import Foundation

// MARK: - JSONSchema Factory Methods

extension JSONSchema {
    /// 文字列型のスキーマを作成
    ///
    /// - Parameters:
    ///   - description: スキーマの説明
    ///   - minLength: 最小文字数
    ///   - maxLength: 最大文字数
    ///   - pattern: 正規表現パターン
    ///   - format: 文字列フォーマット（例: "email", "uri"）
    ///   - enumValues: 許可される値のリスト
    /// - Returns: 文字列型の JSONSchema
    ///
    /// ```swift
    /// let nameSchema = JSONSchema.string(description: "名前", minLength: 1)
    /// let emailSchema = JSONSchema.string(format: "email")
    /// ```
    public static func string(
        description: String? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        pattern: String? = nil,
        format: String? = nil,
        enum enumValues: [String]? = nil
    ) -> JSONSchema {
        JSONSchema(
            type: .string,
            description: description,
            minLength: minLength,
            maxLength: maxLength,
            pattern: pattern,
            enum: enumValues,
            format: format
        )
    }

    /// 整数型のスキーマを作成
    ///
    /// - Parameters:
    ///   - description: スキーマの説明
    ///   - minimum: 最小値（この値を含む）
    ///   - maximum: 最大値（この値を含む）
    ///   - exclusiveMinimum: 最小値（この値を含まない）
    ///   - exclusiveMaximum: 最大値（この値を含まない）
    /// - Returns: 整数型の JSONSchema
    ///
    /// ```swift
    /// let ageSchema = JSONSchema.integer(description: "年齢", minimum: 0, maximum: 150)
    /// ```
    public static func integer(
        description: String? = nil,
        minimum: Int? = nil,
        maximum: Int? = nil,
        exclusiveMinimum: Int? = nil,
        exclusiveMaximum: Int? = nil
    ) -> JSONSchema {
        JSONSchema(
            type: .integer,
            description: description,
            minimum: minimum,
            maximum: maximum,
            exclusiveMinimum: exclusiveMinimum,
            exclusiveMaximum: exclusiveMaximum
        )
    }

    /// 数値型のスキーマを作成
    ///
    /// - Parameters:
    ///   - description: スキーマの説明
    ///   - minimum: 最小値
    ///   - maximum: 最大値
    /// - Returns: 数値型の JSONSchema
    ///
    /// ```swift
    /// let priceSchema = JSONSchema.number(description: "価格", minimum: 0)
    /// ```
    public static func number(
        description: String? = nil,
        minimum: Int? = nil,
        maximum: Int? = nil
    ) -> JSONSchema {
        JSONSchema(
            type: .number,
            description: description,
            minimum: minimum,
            maximum: maximum
        )
    }

    /// 真偽値型のスキーマを作成
    ///
    /// - Parameter description: スキーマの説明
    /// - Returns: 真偽値型の JSONSchema
    ///
    /// ```swift
    /// let isActiveSchema = JSONSchema.boolean(description: "アクティブかどうか")
    /// ```
    public static func boolean(description: String? = nil) -> JSONSchema {
        JSONSchema(type: .boolean, description: description)
    }

    /// null 型のスキーマを作成
    ///
    /// - Parameter description: スキーマの説明
    /// - Returns: null 型の JSONSchema
    ///
    /// ```swift
    /// let nullSchema = JSONSchema.null(description: "null値")
    /// ```
    public static func null(description: String? = nil) -> JSONSchema {
        JSONSchema(type: .null, description: description)
    }

    /// 配列型のスキーマを作成
    ///
    /// - Parameters:
    ///   - description: スキーマの説明
    ///   - items: 配列要素のスキーマ
    ///   - minItems: 最小要素数
    ///   - maxItems: 最大要素数
    /// - Returns: 配列型の JSONSchema
    ///
    /// ```swift
    /// let tagsSchema = JSONSchema.array(
    ///     description: "タグリスト",
    ///     items: .string(),
    ///     minItems: 1,
    ///     maxItems: 10
    /// )
    /// ```
    public static func array(
        description: String? = nil,
        items: JSONSchema,
        minItems: Int? = nil,
        maxItems: Int? = nil
    ) -> JSONSchema {
        JSONSchema(
            type: .array,
            description: description,
            items: items,
            minItems: minItems,
            maxItems: maxItems
        )
    }

    /// オブジェクト型のスキーマを作成
    ///
    /// - Parameters:
    ///   - description: スキーマの説明
    ///   - properties: プロパティ名とスキーマのマッピング
    ///   - required: 必須プロパティ名のリスト
    ///   - additionalProperties: 追加プロパティを許可するかどうか
    /// - Returns: オブジェクト型の JSONSchema
    ///
    /// ```swift
    /// let userSchema = JSONSchema.object(
    ///     description: "ユーザー情報",
    ///     properties: [
    ///         "name": .string(description: "名前"),
    ///         "age": .integer(minimum: 0)
    ///     ],
    ///     required: ["name", "age"]
    /// )
    /// ```
    public static func object(
        description: String? = nil,
        properties: [String: JSONSchema],
        required: [String]? = nil,
        additionalProperties: Bool = false
    ) -> JSONSchema {
        JSONSchema(
            type: .object,
            description: description,
            properties: properties,
            required: required,
            additionalProperties: additionalProperties
        )
    }

    /// 列挙型のスキーマを作成
    ///
    /// - Parameters:
    ///   - values: 許可される値のリスト
    ///   - description: スキーマの説明
    /// - Returns: 列挙制約付き文字列型の JSONSchema
    ///
    /// ```swift
    /// let statusSchema = JSONSchema.enum(
    ///     ["active", "inactive", "pending"],
    ///     description: "ステータス"
    /// )
    /// ```
    public static func `enum`(
        _ values: [String],
        description: String? = nil
    ) -> JSONSchema {
        JSONSchema(
            type: .string,
            description: description,
            enum: values
        )
    }
}
