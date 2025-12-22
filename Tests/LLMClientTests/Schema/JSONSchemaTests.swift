import XCTest
@testable import LLMClient

final class JSONSchemaTests: XCTestCase {

    // MARK: - Basic Type Tests

    func testStringSchema() throws {
        let schema = JSONSchema.string()
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "string")
    }

    func testIntegerSchema() throws {
        let schema = JSONSchema.integer()
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "integer")
    }

    func testNumberSchema() throws {
        let schema = JSONSchema.number()
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "number")
    }

    func testBooleanSchema() throws {
        let schema = JSONSchema.boolean()
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "boolean")
    }

    func testNullSchema() throws {
        let schema = JSONSchema.null()
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "null")
    }

    // MARK: - String Constraints Tests

    func testStringWithMinLength() throws {
        let schema = JSONSchema.string(minLength: 5)
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "string")
        XCTAssertEqual(json["minLength"] as? Int, 5)
    }

    func testStringWithMaxLength() throws {
        let schema = JSONSchema.string(maxLength: 100)
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "string")
        XCTAssertEqual(json["maxLength"] as? Int, 100)
    }

    func testStringWithPattern() throws {
        let schema = JSONSchema.string(pattern: "^[a-z]+$")
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "string")
        XCTAssertEqual(json["pattern"] as? String, "^[a-z]+$")
    }

    func testStringWithFormat() throws {
        let schema = JSONSchema.string(format: "email")
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "string")
        XCTAssertEqual(json["format"] as? String, "email")
    }

    func testStringWithEnum() throws {
        let schema = JSONSchema.string(enum: ["active", "inactive", "pending"])
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "string")
        XCTAssertEqual(json["enum"] as? [String], ["active", "inactive", "pending"])
    }

    func testStringWithAllConstraints() throws {
        let schema = JSONSchema.string(
            description: "ユーザー名",
            minLength: 3,
            maxLength: 20,
            pattern: "^[a-zA-Z0-9_]+$"
        )
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "string")
        XCTAssertEqual(json["description"] as? String, "ユーザー名")
        XCTAssertEqual(json["minLength"] as? Int, 3)
        XCTAssertEqual(json["maxLength"] as? Int, 20)
        XCTAssertEqual(json["pattern"] as? String, "^[a-zA-Z0-9_]+$")
    }

    // MARK: - Integer Constraints Tests

    func testIntegerWithMinimum() throws {
        let schema = JSONSchema.integer(minimum: 0)
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "integer")
        XCTAssertEqual(json["minimum"] as? Int, 0)
    }

    func testIntegerWithMaximum() throws {
        let schema = JSONSchema.integer(maximum: 100)
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "integer")
        XCTAssertEqual(json["maximum"] as? Int, 100)
    }

    func testIntegerWithExclusiveMinimum() throws {
        let schema = JSONSchema.integer(exclusiveMinimum: 0)
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "integer")
        XCTAssertEqual(json["exclusiveMinimum"] as? Int, 0)
    }

    func testIntegerWithExclusiveMaximum() throws {
        let schema = JSONSchema.integer(exclusiveMaximum: 100)
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "integer")
        XCTAssertEqual(json["exclusiveMaximum"] as? Int, 100)
    }

    func testIntegerWithRange() throws {
        let schema = JSONSchema.integer(
            description: "評価スコア",
            minimum: 1,
            maximum: 5
        )
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "integer")
        XCTAssertEqual(json["description"] as? String, "評価スコア")
        XCTAssertEqual(json["minimum"] as? Int, 1)
        XCTAssertEqual(json["maximum"] as? Int, 5)
    }

    // MARK: - Array Tests

    func testArrayWithItems() throws {
        let schema = JSONSchema.array(items: .string())
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "array")
        let items = json["items"] as? [String: Any]
        XCTAssertEqual(items?["type"] as? String, "string")
    }

    func testArrayWithMinItems() throws {
        let schema = JSONSchema.array(items: .integer(), minItems: 1)
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "array")
        XCTAssertEqual(json["minItems"] as? Int, 1)
    }

    func testArrayWithMaxItems() throws {
        let schema = JSONSchema.array(items: .string(), maxItems: 10)
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "array")
        XCTAssertEqual(json["maxItems"] as? Int, 10)
    }

    func testArrayWithAllConstraints() throws {
        let schema = JSONSchema.array(
            description: "タグリスト",
            items: .string(minLength: 1, maxLength: 50),
            minItems: 1,
            maxItems: 10
        )
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "array")
        XCTAssertEqual(json["description"] as? String, "タグリスト")
        XCTAssertEqual(json["minItems"] as? Int, 1)
        XCTAssertEqual(json["maxItems"] as? Int, 10)

        let items = json["items"] as? [String: Any]
        XCTAssertEqual(items?["type"] as? String, "string")
        XCTAssertEqual(items?["minLength"] as? Int, 1)
        XCTAssertEqual(items?["maxLength"] as? Int, 50)
    }

    // MARK: - Object Tests

    func testObjectWithProperties() throws {
        let schema = JSONSchema.object(
            properties: [
                "name": .string(),
                "age": .integer()
            ]
        )
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "object")

        let properties = json["properties"] as? [String: Any]
        let nameSchema = properties?["name"] as? [String: Any]
        let ageSchema = properties?["age"] as? [String: Any]

        XCTAssertEqual(nameSchema?["type"] as? String, "string")
        XCTAssertEqual(ageSchema?["type"] as? String, "integer")
    }

    func testObjectWithRequired() throws {
        let schema = JSONSchema.object(
            properties: [
                "name": .string(),
                "email": .string()
            ],
            required: ["name", "email"]
        )
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "object")
        XCTAssertEqual(json["required"] as? [String], ["name", "email"])
    }

    func testObjectWithAdditionalPropertiesFalse() throws {
        let schema = JSONSchema.object(
            properties: ["name": .string()],
            additionalProperties: false
        )
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "object")
        XCTAssertEqual(json["additionalProperties"] as? Bool, false)
    }

    func testCompleteObjectSchema() throws {
        let schema = JSONSchema.object(
            description: "ユーザー情報",
            properties: [
                "name": .string(description: "氏名", minLength: 1, maxLength: 100),
                "age": .integer(description: "年齢", minimum: 0, maximum: 150),
                "email": .string(description: "メールアドレス", format: "email"),
                "tags": .array(description: "タグ", items: .string(), maxItems: 5)
            ],
            required: ["name", "email"],
            additionalProperties: false
        )
        let json = try encode(schema)

        XCTAssertEqual(json["type"] as? String, "object")
        XCTAssertEqual(json["description"] as? String, "ユーザー情報")
        XCTAssertEqual(json["required"] as? [String], ["name", "email"])
        XCTAssertEqual(json["additionalProperties"] as? Bool, false)

        let properties = json["properties"] as? [String: Any]
        XCTAssertNotNil(properties?["name"])
        XCTAssertNotNil(properties?["age"])
        XCTAssertNotNil(properties?["email"])
        XCTAssertNotNil(properties?["tags"])
    }

    // MARK: - Nested Object Tests

    func testNestedObjectSchema() throws {
        let addressSchema = JSONSchema.object(
            properties: [
                "city": .string(),
                "zip": .string()
            ],
            required: ["city"]
        )

        let userSchema = JSONSchema.object(
            properties: [
                "name": .string(),
                "address": addressSchema
            ],
            required: ["name"]
        )

        let json = try encode(userSchema)

        XCTAssertEqual(json["type"] as? String, "object")

        let properties = json["properties"] as? [String: Any]
        let addressJson = properties?["address"] as? [String: Any]

        XCTAssertEqual(addressJson?["type"] as? String, "object")
        XCTAssertEqual(addressJson?["required"] as? [String], ["city"])
    }

    // MARK: - Equality Tests

    func testSchemaEquality() {
        let schema1 = JSONSchema.string(description: "test", minLength: 1)
        let schema2 = JSONSchema.string(description: "test", minLength: 1)
        let schema3 = JSONSchema.string(description: "test", minLength: 2)

        XCTAssertEqual(schema1, schema2)
        XCTAssertNotEqual(schema1, schema3)
    }

    func testArraySchemaEquality() {
        let schema1 = JSONSchema.array(items: .string(), minItems: 1)
        let schema2 = JSONSchema.array(items: .string(), minItems: 1)
        let schema3 = JSONSchema.array(items: .integer(), minItems: 1)

        XCTAssertEqual(schema1, schema2)
        XCTAssertNotEqual(schema1, schema3)
    }

    // MARK: - Helpers

    private func encode(_ schema: JSONSchema) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(schema)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
}
