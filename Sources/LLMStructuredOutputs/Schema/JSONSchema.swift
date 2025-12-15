import Foundation

// MARK: - JSONSchema

/// JSON Schema の Swift 表現
///
/// LLM の Structured Output 機能で使用される JSON Schema を表現します。
/// 各プロバイダー（Anthropic, OpenAI, Gemini）の API で使用可能な形式でエンコードされます。
///
/// ## 概要
///
/// JSON Schema は構造化データの形式を定義するための標準規格です。
/// このライブラリでは、LLM からの出力を型安全に取得するために使用されます。
///
/// ## 使用例
///
/// ```swift
/// // 基本的なスキーマの作成
/// let nameSchema = JSONSchema.string(description: "名前")
///
/// // オブジェクトスキーマの作成
/// let userSchema = JSONSchema.object(
///     description: "ユーザー情報",
///     properties: [
///         "name": .string(description: "名前"),
///         "age": .integer(minimum: 0, maximum: 150)
///     ],
///     required: ["name", "age"]
/// )
///
/// // JSON データに変換
/// let jsonData = try userSchema.toJSONData()
/// ```
///
/// ## プロバイダー対応
///
/// 各 LLM プロバイダーは JSON Schema のサポート範囲が異なります。
/// このライブラリでは、プロバイダーごとにスキーマを自動的に適合させるため、
/// ユーザーが直接プロバイダー固有の変換を意識する必要はありません。
public struct JSONSchema: Sendable, Encodable, Equatable {
    /// スキーマの型
    public let type: JSONSchemaType

    /// スキーマの説明
    public let description: String?

    /// オブジェクト型のプロパティ定義
    public let properties: [String: JSONSchema]?

    /// 必須プロパティ名のリスト
    public let required: [String]?

    /// 配列型の要素スキーマ
    public let items: Box<JSONSchema>?

    /// 追加プロパティを許可するかどうか
    public let additionalProperties: Bool?

    // MARK: - 配列制約

    /// 最小要素数
    public let minItems: Int?

    /// 最大要素数
    public let maxItems: Int?

    // MARK: - 数値制約

    /// 最小値（この値を含む）
    public let minimum: Int?

    /// 最大値（この値を含む）
    public let maximum: Int?

    /// 最小値（この値を含まない）
    public let exclusiveMinimum: Int?

    /// 最大値（この値を含まない）
    public let exclusiveMaximum: Int?

    // MARK: - 文字列制約

    /// 最小文字数
    public let minLength: Int?

    /// 最大文字数
    public let maxLength: Int?

    /// 正規表現パターン
    public let pattern: String?

    // MARK: - 列挙・フォーマット

    /// 許可される値のリスト
    public let `enum`: [String]?

    /// 文字列フォーマット（例: "email", "uri", "date-time"）
    public let format: String?

    // MARK: - Initializer

    /// JSONSchema を初期化
    ///
    /// - Parameters:
    ///   - type: スキーマの型
    ///   - description: スキーマの説明
    ///   - properties: オブジェクト型のプロパティ定義
    ///   - required: 必須プロパティ名のリスト
    ///   - items: 配列型の要素スキーマ
    ///   - additionalProperties: 追加プロパティを許可するかどうか
    ///   - minItems: 最小要素数
    ///   - maxItems: 最大要素数
    ///   - minimum: 最小値（この値を含む）
    ///   - maximum: 最大値（この値を含む）
    ///   - exclusiveMinimum: 最小値（この値を含まない）
    ///   - exclusiveMaximum: 最大値（この値を含まない）
    ///   - minLength: 最小文字数
    ///   - maxLength: 最大文字数
    ///   - pattern: 正規表現パターン
    ///   - enum: 許可される値のリスト
    ///   - format: 文字列フォーマット
    public init(
        type: JSONSchemaType,
        description: String? = nil,
        properties: [String: JSONSchema]? = nil,
        required: [String]? = nil,
        items: JSONSchema? = nil,
        additionalProperties: Bool? = nil,
        minItems: Int? = nil,
        maxItems: Int? = nil,
        minimum: Int? = nil,
        maximum: Int? = nil,
        exclusiveMinimum: Int? = nil,
        exclusiveMaximum: Int? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        pattern: String? = nil,
        `enum`: [String]? = nil,
        format: String? = nil
    ) {
        self.type = type
        self.description = description
        self.properties = properties
        self.required = required
        self.items = items.map { Box($0) }
        self.additionalProperties = additionalProperties
        self.minItems = minItems
        self.maxItems = maxItems
        self.minimum = minimum
        self.maximum = maximum
        self.exclusiveMinimum = exclusiveMinimum
        self.exclusiveMaximum = exclusiveMaximum
        self.minLength = minLength
        self.maxLength = maxLength
        self.pattern = pattern
        self.enum = `enum`
        self.format = format
    }
}

// MARK: - Convenience Properties

extension JSONSchema {
    /// オブジェクト型かどうか
    public var isObject: Bool { type == .object }

    /// 配列型かどうか
    public var isArray: Bool { type == .array }

    /// プリミティブ型かどうか
    ///
    /// string, integer, number, boolean, null のいずれかの場合に `true` を返します。
    public var isPrimitive: Bool {
        switch type {
        case .string, .integer, .number, .boolean, .null:
            return true
        case .object, .array:
            return false
        }
    }
}
