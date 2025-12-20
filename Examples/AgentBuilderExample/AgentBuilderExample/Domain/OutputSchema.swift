import Foundation
import LLMDynamicStructured

/// 出力スキーマ定義
public struct OutputSchema: Codable, Identifiable, Sendable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var description: String?
    public var fields: [Field]
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        fields: [Field] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.fields = fields
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func toDynamicStructured() -> DynamicStructured {
        DynamicStructured(
            name: name,
            description: description,
            fields: fields.map { $0.toNamedSchema() }
        )
    }
}

/// フィールド定義
public struct Field: Codable, Identifiable, Sendable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var type: FieldType
    public var description: String?
    public var isRequired: Bool
    public var constraints: FieldConstraints

    public init(
        id: UUID = UUID(),
        name: String,
        type: FieldType = .string,
        description: String? = nil,
        isRequired: Bool = true,
        constraints: FieldConstraints = FieldConstraints()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.description = description
        self.isRequired = isRequired
        self.constraints = constraints
    }

    func toNamedSchema() -> NamedSchema {
        let schema = type.toJSONSchema(description: description, constraints: constraints)
        var namedSchema = schema.named(name)
        if !isRequired { namedSchema = namedSchema.optional() }
        return namedSchema
    }
}

/// フィールド型
public enum FieldType: Codable, Sendable, Equatable, Hashable, CaseIterable {
    case string
    case integer
    case number
    case boolean
    case stringEnum([String])
    case stringArray
    case integerArray

    public static var allCases: [FieldType] {
        [.string, .integer, .number, .boolean, .stringEnum([]), .stringArray, .integerArray]
    }

    public var displayName: String {
        switch self {
        case .string: "文字列"
        case .integer: "整数"
        case .number: "数値"
        case .boolean: "真偽値"
        case .stringEnum: "列挙型"
        case .stringArray: "文字列配列"
        case .integerArray: "整数配列"
        }
    }

    public var icon: String {
        switch self {
        case .string: "textformat"
        case .integer: "number"
        case .number: "function"
        case .boolean: "checkmark.circle"
        case .stringEnum: "list.bullet"
        case .stringArray: "square.stack"
        case .integerArray: "square.stack.fill"
        }
    }

    func toJSONSchema(description: String?, constraints: FieldConstraints) -> JSONSchema {
        switch self {
        case .string:
            return .string(
                description: description,
                minLength: constraints.minLength,
                maxLength: constraints.maxLength,
                pattern: constraints.pattern,
                format: constraints.format
            )
        case .integer:
            return .integer(
                description: description,
                minimum: constraints.minimum.map { Int($0) },
                maximum: constraints.maximum.map { Int($0) }
            )
        case .number:
            return .number(
                description: description,
                minimum: constraints.minimum.map { Int($0) },
                maximum: constraints.maximum.map { Int($0) }
            )
        case .boolean:
            return .boolean(description: description)
        case .stringEnum(let values):
            return .enum(values, description: description)
        case .stringArray:
            return .array(
                description: description,
                items: .string(),
                minItems: constraints.minItems,
                maxItems: constraints.maxItems
            )
        case .integerArray:
            return .array(
                description: description,
                items: .integer(),
                minItems: constraints.minItems,
                maxItems: constraints.maxItems
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, enumValues
    }

    private enum TypeIdentifier: String, Codable {
        case string, integer, number, boolean, stringEnum, stringArray, integerArray
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeId = try container.decode(TypeIdentifier.self, forKey: .type)
        switch typeId {
        case .string: self = .string
        case .integer: self = .integer
        case .number: self = .number
        case .boolean: self = .boolean
        case .stringEnum:
            let values = try container.decode([String].self, forKey: .enumValues)
            self = .stringEnum(values)
        case .stringArray: self = .stringArray
        case .integerArray: self = .integerArray
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .string: try container.encode(TypeIdentifier.string, forKey: .type)
        case .integer: try container.encode(TypeIdentifier.integer, forKey: .type)
        case .number: try container.encode(TypeIdentifier.number, forKey: .type)
        case .boolean: try container.encode(TypeIdentifier.boolean, forKey: .type)
        case .stringEnum(let values):
            try container.encode(TypeIdentifier.stringEnum, forKey: .type)
            try container.encode(values, forKey: .enumValues)
        case .stringArray: try container.encode(TypeIdentifier.stringArray, forKey: .type)
        case .integerArray: try container.encode(TypeIdentifier.integerArray, forKey: .type)
        }
    }
}

/// 制約オプション
public struct FieldConstraints: Codable, Sendable, Equatable, Hashable {
    public var minLength: Int?
    public var maxLength: Int?
    public var pattern: String?
    public var format: String?
    public var minimum: Double?
    public var maximum: Double?
    public var minItems: Int?
    public var maxItems: Int?

    public init(
        minLength: Int? = nil,
        maxLength: Int? = nil,
        pattern: String? = nil,
        format: String? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        minItems: Int? = nil,
        maxItems: Int? = nil
    ) {
        self.minLength = minLength
        self.maxLength = maxLength
        self.pattern = pattern
        self.format = format
        self.minimum = minimum
        self.maximum = maximum
        self.minItems = minItems
        self.maxItems = maxItems
    }
}
