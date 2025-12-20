import Testing
@testable import LLMDynamicStructured
import LLMClient

// MARK: - DynamicStructured Tests

@Suite("DynamicStructured Tests")
struct DynamicStructuredTests {

    @Test("Basic structure creation")
    func basicStructureCreation() {
        let userInfo = DynamicStructured("UserInfo", description: "ユーザー情報") {
            JSONSchema.string(description: "ユーザー名")
                .named("name")

            JSONSchema.integer(description: "年齢", minimum: 0)
                .named("age")
        }

        #expect(userInfo.name == "UserInfo")
        #expect(userInfo.description == "ユーザー情報")
        #expect(userInfo.fields.count == 2)
    }

    @Test("Field properties")
    func fieldProperties() {
        let structure = DynamicStructured("Test") {
            JSONSchema.string(description: "Required field")
                .named("required")

            JSONSchema.string(description: "Optional field")
                .named("optional")
                .optional()
        }

        let requiredField = structure.fields.first { $0.name == "required" }
        let optionalField = structure.fields.first { $0.name == "optional" }

        #expect(requiredField?.isRequired == true)
        #expect(optionalField?.isRequired == false)
    }

    @Test("JSON Schema generation")
    func jsonSchemaGeneration() throws {
        let structure = DynamicStructured("Product") {
            JSONSchema.string(description: "商品名", minLength: 1)
                .named("name")

            JSONSchema.integer(description: "価格", minimum: 0)
                .named("price")

            JSONSchema.enum(["electronics", "clothing", "food"], description: "カテゴリ")
                .named("category")
                .optional()
        }

        let schema = structure.toJSONSchema()

        #expect(schema.type == .object)
        #expect(schema.properties?.count == 3)
        #expect(schema.required?.contains("name") == true)
        #expect(schema.required?.contains("price") == true)
        #expect(schema.required?.contains("category") == false)
        #expect(schema.additionalProperties == false)
    }

    @Test("Nested structure")
    func nestedStructure() {
        let address = DynamicStructured("Address") {
            JSONSchema.string(description: "都市")
                .named("city")

            JSONSchema.string(description: "郵便番号", pattern: "^\\d{3}-\\d{4}$")
                .named("zipCode")
        }

        let user = DynamicStructured("User") {
            JSONSchema.string(description: "名前")
                .named("name")

            JSONSchema.object(
                description: "住所",
                properties: address.toJSONSchema().properties ?? [:],
                required: address.toJSONSchema().required
            )
            .named("address")
        }

        let schema = user.toJSONSchema()
        let addressProperty = schema.properties?["address"]

        #expect(addressProperty?.type == .object)
        #expect(addressProperty?.properties?.count == 2)
    }

    @Test("Array field")
    func arrayField() {
        let structure = DynamicStructured("TaggedItem") {
            JSONSchema.string(description: "名前")
                .named("name")

            JSONSchema.array(
                description: "タグリスト",
                items: .string(),
                minItems: 1,
                maxItems: 10
            )
            .named("tags")
        }

        let schema = structure.toJSONSchema()
        let tagsProperty = schema.properties?["tags"]

        #expect(tagsProperty?.type == .array)
        #expect(tagsProperty?.minItems == 1)
        #expect(tagsProperty?.maxItems == 10)
    }
}

// MARK: - DynamicStructuredResult Tests

@Suite("DynamicStructuredResult Tests")
struct DynamicStructuredResultTests {

    @Test("Basic value access")
    func basicValueAccess() throws {
        let json = """
        {
            "name": "田中太郎",
            "age": 35,
            "isActive": true
        }
        """

        let result = try DynamicStructuredResult(from: json)

        #expect(result.string("name") == "田中太郎")
        #expect(result.int("age") == 35)
        #expect(result.bool("isActive") == true)
    }

    @Test("Array access")
    func arrayAccess() throws {
        let json = """
        {
            "tags": ["swift", "ios", "macos"],
            "scores": [95, 88, 92]
        }
        """

        let result = try DynamicStructuredResult(from: json)

        #expect(result.stringArray("tags") == ["swift", "ios", "macos"])
        #expect(result.intArray("scores") == [95, 88, 92])
    }

    @Test("Nested object access")
    func nestedObjectAccess() throws {
        let json = """
        {
            "user": {
                "name": "山田花子",
                "address": {
                    "city": "東京",
                    "zipCode": "100-0001"
                }
            }
        }
        """

        let result = try DynamicStructuredResult(from: json)
        let user = result.nested("user")
        let address = user?.nested("address")

        #expect(user?.string("name") == "山田花子")
        #expect(address?.string("city") == "東京")
        #expect(address?.string("zipCode") == "100-0001")
    }

    @Test("Missing key returns nil")
    func missingKeyReturnsNil() throws {
        let json = """
        {
            "name": "Test"
        }
        """

        let result = try DynamicStructuredResult(from: json)

        #expect(result.string("missing") == nil)
        #expect(result.int("missing") == nil)
        #expect(result.nested("missing") == nil)
    }

    @Test("Keys and hasKey")
    func keysAndHasKey() throws {
        let json = """
        {
            "a": 1,
            "b": 2,
            "c": 3
        }
        """

        let result = try DynamicStructuredResult(from: json)

        #expect(result.keys.count == 3)
        #expect(result.hasKey("a") == true)
        #expect(result.hasKey("d") == false)
    }

    @Test("Invalid JSON throws error")
    func invalidJSONThrowsError() {
        let invalidJSON = "not valid json"

        #expect(throws: DynamicStructuredResultError.self) {
            try DynamicStructuredResult(from: invalidJSON)
        }
    }

    @Test("Double to Int conversion")
    func doubleToIntConversion() throws {
        // JSON numbers are often parsed as Double
        let json = """
        {
            "count": 42.0
        }
        """

        let result = try DynamicStructuredResult(from: json)

        #expect(result.int("count") == 42)
    }
}

// MARK: - StructuredBuilder Tests

@Suite("StructuredBuilder Tests")
struct StructuredBuilderTests {

    @Test("Conditional field inclusion")
    func conditionalFieldInclusion() {
        let includeEmail = true

        let structure = DynamicStructured("Contact") {
            JSONSchema.string(description: "名前")
                .named("name")

            if includeEmail {
                JSONSchema.string(description: "メール", format: "email")
                    .named("email")
            }
        }

        #expect(structure.fields.count == 2)
        #expect(structure.fields.contains { $0.name == "email" })
    }

    @Test("Conditional field exclusion")
    func conditionalFieldExclusion() {
        let includeEmail = false

        let structure = DynamicStructured("Contact") {
            JSONSchema.string(description: "名前")
                .named("name")

            if includeEmail {
                JSONSchema.string(description: "メール", format: "email")
                    .named("email")
            }
        }

        #expect(structure.fields.count == 1)
        #expect(!structure.fields.contains { $0.name == "email" })
    }
}

// MARK: - NamedSchema Tests

@Suite("NamedSchema Tests")
struct NamedSchemaTests {

    @Test("Named schema creation")
    func namedSchemaCreation() {
        let schema = JSONSchema.string(description: "Test")
            .named("testField")

        #expect(schema.name == "testField")
        #expect(schema.isRequired == true)
    }

    @Test("Optional modifier")
    func optionalModifier() {
        let schema = JSONSchema.string(description: "Test")
            .named("testField")
            .optional()

        #expect(schema.isRequired == false)
    }

    @Test("Required modifier")
    func requiredModifier() {
        let schema = JSONSchema.string(description: "Test")
            .named("testField")
            .optional()
            .required()

        #expect(schema.isRequired == true)
    }
}
