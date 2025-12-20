import Foundation
import LLMDynamicStructured

// MARK: - BuiltType

/// ビルドされた型定義（永続化可能）
public struct BuiltType: Codable, Identifiable, Sendable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var description: String?
    public var fields: [BuiltField]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        fields: [BuiltField] = [],
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

    /// DynamicStructured に変換
    public func toDynamicStructured() -> DynamicStructured {
        DynamicStructured(
            name: name,
            description: description,
            fields: fields.map { $0.toNamedSchema() }
        )
    }
}

// MARK: - BuiltField

/// フィールド定義
public struct BuiltField: Codable, Identifiable, Sendable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var fieldType: BuiltFieldType
    public var description: String?
    public var isRequired: Bool
    public var constraints: FieldConstraints

    public init(
        id: UUID = UUID(),
        name: String,
        fieldType: BuiltFieldType = .string,
        description: String? = nil,
        isRequired: Bool = true,
        constraints: FieldConstraints = FieldConstraints()
    ) {
        self.id = id
        self.name = name
        self.fieldType = fieldType
        self.description = description
        self.isRequired = isRequired
        self.constraints = constraints
    }

    /// NamedSchema に変換
    func toNamedSchema() -> NamedSchema {
        let schema = fieldType.toJSONSchema(description: description, constraints: constraints)
        var namedSchema = schema.named(name)
        if !isRequired {
            namedSchema = namedSchema.optional()
        }
        return namedSchema
    }
}

// MARK: - BuiltFieldType

/// フィールド型
public enum BuiltFieldType: Codable, Sendable, Equatable, Hashable, CaseIterable {
    case string
    case integer
    case number
    case boolean
    case stringEnum([String])
    case stringArray
    case integerArray

    public static var allCases: [BuiltFieldType] {
        [.string, .integer, .number, .boolean, .stringEnum([]), .stringArray, .integerArray]
    }

    public var displayName: String {
        switch self {
        case .string: return "文字列"
        case .integer: return "整数"
        case .number: return "数値"
        case .boolean: return "真偽値"
        case .stringEnum: return "列挙型"
        case .stringArray: return "文字列配列"
        case .integerArray: return "整数配列"
        }
    }

    public var iconName: String {
        switch self {
        case .string: return "textformat"
        case .integer: return "number"
        case .number: return "function"
        case .boolean: return "checkmark.circle"
        case .stringEnum: return "list.bullet"
        case .stringArray: return "square.stack"
        case .integerArray: return "square.stack.fill"
        }
    }

    /// JSONSchema に変換
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

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case enumValues
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
        case .string:
            try container.encode(TypeIdentifier.string, forKey: .type)
        case .integer:
            try container.encode(TypeIdentifier.integer, forKey: .type)
        case .number:
            try container.encode(TypeIdentifier.number, forKey: .type)
        case .boolean:
            try container.encode(TypeIdentifier.boolean, forKey: .type)
        case .stringEnum(let values):
            try container.encode(TypeIdentifier.stringEnum, forKey: .type)
            try container.encode(values, forKey: .enumValues)
        case .stringArray:
            try container.encode(TypeIdentifier.stringArray, forKey: .type)
        case .integerArray:
            try container.encode(TypeIdentifier.integerArray, forKey: .type)
        }
    }
}

// MARK: - FieldConstraints

/// 制約オプション
public struct FieldConstraints: Codable, Sendable, Equatable, Hashable {
    // String
    public var minLength: Int?
    public var maxLength: Int?
    public var pattern: String?
    public var format: String?

    // Number
    public var minimum: Double?
    public var maximum: Double?

    // Array
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
