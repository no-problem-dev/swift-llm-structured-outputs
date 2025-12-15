import Foundation

// MARK: - JSONSchema Encodable Implementation

extension JSONSchema {
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
    /// JSON 文字列としてエンコード
    ///
    /// - Parameter prettyPrinted: 整形済み出力にするかどうか
    /// - Returns: JSON 文字列
    /// - Throws: `JSONSchemaError.encodingFailed` エンコードに失敗した場合
    ///
    /// ```swift
    /// let schema = JSONSchema.string(description: "名前")
    /// let jsonString = try schema.toJSONString(prettyPrinted: true)
    /// // {
    /// //   "description": "名前",
    /// //   "type": "string"
    /// // }
    /// ```
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

    /// JSON データとしてエンコード
    ///
    /// - Returns: JSON データ
    /// - Throws: エンコードエラー
    ///
    /// ```swift
    /// let schema = JSONSchema.object(properties: ["name": .string()])
    /// let data = try schema.toJSONData()
    /// ```
    public func toJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self)
    }
}

// MARK: - CustomDebugStringConvertible

extension JSONSchema: CustomDebugStringConvertible {
    public var debugDescription: String {
        (try? toJSONString(prettyPrinted: true)) ?? "JSONSchema(\(type))"
    }
}
