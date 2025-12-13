import Foundation

/// JSON Schema の Swift 表現
///
/// LLMのStructured Output機能で使用されるJSON Schemaを表現します。
/// Anthropic/OpenAI両方のAPIで使用可能な形式でエンコードされます。
public struct JSONSchema: Sendable, Encodable, Equatable {
    public let type: SchemaType
    public let description: String?
    public let properties: [String: JSONSchema]?
    public let required: [String]?
    public let items: Box<JSONSchema>?
    public let additionalProperties: Bool?

    // 配列制約
    public let minItems: Int?
    public let maxItems: Int?

    // 数値制約
    public let minimum: Int?
    public let maximum: Int?
    public let exclusiveMinimum: Int?
    public let exclusiveMaximum: Int?

    // 文字列制約
    public let minLength: Int?
    public let maxLength: Int?
    public let pattern: String?

    // 列挙・フォーマット
    public let `enum`: [String]?
    public let format: String?

    /// JSON Schemaの型
    public enum SchemaType: String, Sendable, Encodable, Equatable {
        case object
        case array
        case string
        case integer
        case number
        case boolean
        case null
    }

    /// 再帰的な構造をサポートするためのBox型
    public final class Box<T: Sendable & Encodable & Equatable>: @unchecked Sendable, Encodable, Equatable {
        public let value: T

        public init(_ value: T) {
            self.value = value
        }

        public func encode(to encoder: Encoder) throws {
            try value.encode(to: encoder)
        }

        public static func == (lhs: Box<T>, rhs: Box<T>) -> Bool {
            lhs.value == rhs.value
        }
    }

    // MARK: - Initializers

    public init(
        type: SchemaType,
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

    // MARK: - Convenience Factory Methods

    /// 文字列型のスキーマを作成
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
    public static func boolean(description: String? = nil) -> JSONSchema {
        JSONSchema(type: .boolean, description: description)
    }

    /// null型のスキーマを作成
    public static func null(description: String? = nil) -> JSONSchema {
        JSONSchema(type: .null, description: description)
    }

    /// 配列型のスキーマを作成
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

    // MARK: - Encodable

    private enum CodingKeys: String, CodingKey {
        case type
        case description
        case properties
        case required
        case items
        case additionalProperties
        case minItems
        case maxItems
        case minimum
        case maximum
        case exclusiveMinimum
        case exclusiveMaximum
        case minLength
        case maxLength
        case pattern
        case `enum`
        case format
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(type, forKey: .type)

        if let description {
            try container.encode(description, forKey: .description)
        }
        if let properties {
            try container.encode(properties, forKey: .properties)
        }
        if let required {
            try container.encode(required, forKey: .required)
        }
        if let items {
            try container.encode(items, forKey: .items)
        }
        if let additionalProperties {
            try container.encode(additionalProperties, forKey: .additionalProperties)
        }
        if let minItems {
            try container.encode(minItems, forKey: .minItems)
        }
        if let maxItems {
            try container.encode(maxItems, forKey: .maxItems)
        }
        if let minimum {
            try container.encode(minimum, forKey: .minimum)
        }
        if let maximum {
            try container.encode(maximum, forKey: .maximum)
        }
        if let exclusiveMinimum {
            try container.encode(exclusiveMinimum, forKey: .exclusiveMinimum)
        }
        if let exclusiveMaximum {
            try container.encode(exclusiveMaximum, forKey: .exclusiveMaximum)
        }
        if let minLength {
            try container.encode(minLength, forKey: .minLength)
        }
        if let maxLength {
            try container.encode(maxLength, forKey: .maxLength)
        }
        if let pattern {
            try container.encode(pattern, forKey: .pattern)
        }
        if let `enum` {
            try container.encode(`enum`, forKey: .enum)
        }
        if let format {
            try container.encode(format, forKey: .format)
        }
    }
}

// MARK: - JSON String Conversion

extension JSONSchema {
    /// JSON文字列としてエンコード
    public func toJSONString(prettyPrinted: Bool = false) throws -> String {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        } else {
            encoder.outputFormatting = .sortedKeys
        }
        let data = try encoder.encode(self)
        guard let string = String(data: data, encoding: .utf8) else {
            throw JSONSchemaError.encodingFailed
        }
        return string
    }

    /// JSONデータとしてエンコード
    public func toJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self)
    }
}

/// JSONSchemaに関連するエラー
public enum JSONSchemaError: Error, Sendable {
    case encodingFailed
}
