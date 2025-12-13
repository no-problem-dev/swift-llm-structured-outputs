import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(StructuredMacros)
import StructuredMacros

// swiftlint:disable:next identifier_name
nonisolated(unsafe) let testMacros: [String: Macro.Type] = [
    "Structured": StructuredMacro.self,
    "StructuredField": StructuredFieldMacro.self,
    "StructuredEnum": StructuredEnumMacro.self,
    "StructuredCase": StructuredCaseMacro.self,
]
#endif

final class StructuredMacroTests: XCTestCase {

    // MARK: - Basic Tests

    func testBasicStructWithDescription() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured("ユーザー情報")
            struct User {
                var name: String
                var age: Int
            }
            """,
            expandedSource: """
            struct User {
                var name: String
                var age: Int

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,
                        description: "ユーザー情報",
                        properties: [
                            "name": JSONSchema(type: .string),
                            "age": JSONSchema(type: .integer)
                        ],
                        required: ["name", "age"],
                        additionalProperties: false
                    )
                }
            }

            extension User: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testStructWithoutDescription() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured
            struct SimpleData {
                var value: String
            }
            """,
            expandedSource: """
            struct SimpleData {
                var value: String

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,

                        properties: [
                            "value": JSONSchema(type: .string)
                        ],
                        required: ["value"],
                        additionalProperties: false
                    )
                }
            }

            extension SimpleData: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Type Mapping Tests

    func testAllPrimitiveTypes() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured
            struct AllTypes {
                var stringValue: String
                var intValue: Int
                var doubleValue: Double
                var floatValue: Float
                var boolValue: Bool
            }
            """,
            expandedSource: """
            struct AllTypes {
                var stringValue: String
                var intValue: Int
                var doubleValue: Double
                var floatValue: Float
                var boolValue: Bool

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,

                        properties: [
                            "string_value": JSONSchema(type: .string),
                            "int_value": JSONSchema(type: .integer),
                            "double_value": JSONSchema(type: .number),
                            "float_value": JSONSchema(type: .number),
                            "bool_value": JSONSchema(type: .boolean)
                        ],
                        required: ["string_value", "int_value", "double_value", "float_value", "bool_value"],
                        additionalProperties: false
                    )
                }
            }

            extension AllTypes: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Optional Tests

    func testOptionalProperties() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured
            struct WithOptionals {
                var required: String
                var optional: String?
            }
            """,
            expandedSource: """
            struct WithOptionals {
                var required: String
                var optional: String?

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,

                        properties: [
                            "required": JSONSchema(type: .string),
                            "optional": JSONSchema(type: .string)
                        ],
                        required: ["required"],
                        additionalProperties: false
                    )
                }
            }

            extension WithOptionals: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Array Tests

    func testArrayProperties() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured
            struct WithArrays {
                var tags: [String]
                var numbers: [Int]
            }
            """,
            expandedSource: """
            struct WithArrays {
                var tags: [String]
                var numbers: [Int]

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,

                        properties: [
                            "tags": JSONSchema(type: .array, items: JSONSchema(type: .string)),
                            "numbers": JSONSchema(type: .array, items: JSONSchema(type: .integer))
                        ],
                        required: ["tags", "numbers"],
                        additionalProperties: false
                    )
                }
            }

            extension WithArrays: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - @StructuredField Tests

    func testFieldWithDescription() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured
            struct Product {
                @StructuredField("商品名")
                var name: String

                @StructuredField("価格（税込）")
                var price: Int
            }
            """,
            expandedSource: """
            struct Product {
                var name: String
                var price: Int

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,

                        properties: [
                            "name": JSONSchema(type: .string, description: "商品名"),
                            "price": JSONSchema(type: .integer, description: "価格（税込）")
                        ],
                        required: ["name", "price"],
                        additionalProperties: false
                    )
                }
            }

            extension Product: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testFieldWithNumericConstraints() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured
            struct Rating {
                @StructuredField("評価", .minimum(1), .maximum(5))
                var score: Int
            }
            """,
            expandedSource: """
            struct Rating {
                var score: Int

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,

                        properties: [
                            "score": JSONSchema(type: .integer, description: "評価", minimum: 1, maximum: 5)
                        ],
                        required: ["score"],
                        additionalProperties: false
                    )
                }
            }

            extension Rating: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testFieldWithStringConstraints() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured
            struct TextInput {
                @StructuredField("ユーザー名", .minLength(3), .maxLength(20))
                var username: String
            }
            """,
            expandedSource: """
            struct TextInput {
                var username: String

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,

                        properties: [
                            "username": JSONSchema(type: .string, description: "ユーザー名", minLength: 3, maxLength: 20)
                        ],
                        required: ["username"],
                        additionalProperties: false
                    )
                }
            }

            extension TextInput: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testFieldWithArrayConstraints() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured
            struct TaggedItem {
                @StructuredField("タグ", .minItems(1), .maxItems(10))
                var tags: [String]
            }
            """,
            expandedSource: """
            struct TaggedItem {
                var tags: [String]

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,

                        properties: [
                            "tags": JSONSchema(type: .array, description: "タグ", items: JSONSchema(type: .string), minItems: 1, maxItems: 10)
                        ],
                        required: ["tags"],
                        additionalProperties: false
                    )
                }
            }

            extension TaggedItem: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testFieldWithEnumConstraint() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured
            struct StatusData {
                @StructuredField("ステータス", .enum(["active", "inactive", "pending"]))
                var status: String
            }
            """,
            expandedSource: """
            struct StatusData {
                var status: String

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,

                        properties: [
                            "status": JSONSchema(type: .string, description: "ステータス", enum: ["active", "inactive", "pending"])
                        ],
                        required: ["status"],
                        additionalProperties: false
                    )
                }
            }

            extension StatusData: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testFieldWithFormatConstraint() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured
            struct ContactInfo {
                @StructuredField("メールアドレス", .format(.email))
                var email: String
            }
            """,
            expandedSource: """
            struct ContactInfo {
                var email: String

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,

                        properties: [
                            "email": JSONSchema(type: .string, description: "メールアドレス", format: "email")
                        ],
                        required: ["email"],
                        additionalProperties: false
                    )
                }
            }

            extension ContactInfo: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testFieldWithPatternConstraint() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured
            struct PhoneData {
                @StructuredField("電話番号", .pattern("^[0-9]{10,11}$"))
                var phone: String
            }
            """,
            expandedSource: """
            struct PhoneData {
                var phone: String

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,

                        properties: [
                            "phone": JSONSchema(type: .string, description: "電話番号", pattern: "^[0-9]{10,11}$")
                        ],
                        required: ["phone"],
                        additionalProperties: false
                    )
                }
            }

            extension PhoneData: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Snake Case Conversion Tests

    func testSnakeCaseConversion() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured
            struct CamelCaseTest {
                var firstName: String
                var lastName: String
                var phoneNumber: String
                var userID: String
                var httpURL: String
            }
            """,
            expandedSource: """
            struct CamelCaseTest {
                var firstName: String
                var lastName: String
                var phoneNumber: String
                var userID: String
                var httpURL: String

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,

                        properties: [
                            "first_name": JSONSchema(type: .string),
                            "last_name": JSONSchema(type: .string),
                            "phone_number": JSONSchema(type: .string),
                            "user_id": JSONSchema(type: .string),
                            "http_url": JSONSchema(type: .string)
                        ],
                        required: ["first_name", "last_name", "phone_number", "user_id", "http_url"],
                        additionalProperties: false
                    )
                }
            }

            extension CamelCaseTest: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Computed Property Exclusion Tests

    func testComputedPropertiesExcluded() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured
            struct WithComputed {
                var stored: String

                var computed: String {
                    stored.uppercased()
                }
            }
            """,
            expandedSource: """
            struct WithComputed {
                var stored: String

                var computed: String {
                    stored.uppercased()
                }

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,

                        properties: [
                            "stored": JSONSchema(type: .string)
                        ],
                        required: ["stored"],
                        additionalProperties: false
                    )
                }
            }

            extension WithComputed: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Error Tests

    func testErrorOnNonStruct() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured
            class NotAStruct {
                var value: String = ""
            }
            """,
            expandedSource: """
            class NotAStruct {
                var value: String = ""
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Structured can only be applied to structs", line: 1, column: 1)
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Complex Scenario Tests

    func testComplexStructure() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured("書籍情報")
            struct BookInfo {
                @StructuredField("タイトル", .minLength(1), .maxLength(200))
                var title: String

                @StructuredField("著者名")
                var authors: [String]

                @StructuredField("出版年", .minimum(1900), .maximum(2100))
                var publishedYear: Int?

                @StructuredField("評価", .minimum(1), .maximum(5))
                var rating: Double?

                @StructuredField("ジャンル", .enum(["fiction", "non-fiction", "technical"]))
                var genre: String

                var isbn: String
            }
            """,
            expandedSource: """
            struct BookInfo {
                var title: String
                var authors: [String]
                var publishedYear: Int?
                var rating: Double?
                var genre: String

                var isbn: String

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,
                        description: "書籍情報",
                        properties: [
                            "title": JSONSchema(type: .string, description: "タイトル", minLength: 1, maxLength: 200),
                            "authors": JSONSchema(type: .array, description: "著者名", items: JSONSchema(type: .string)),
                            "published_year": JSONSchema(type: .integer, description: "出版年", minimum: 1900, maximum: 2100),
                            "rating": JSONSchema(type: .number, description: "評価", minimum: 1, maximum: 5),
                            "genre": JSONSchema(type: .string, description: "ジャンル", enum: ["fiction", "non-fiction", "technical"]),
                            "isbn": JSONSchema(type: .string)
                        ],
                        required: ["title", "authors", "genre", "isbn"],
                        additionalProperties: false
                    )
                }
            }

            extension BookInfo: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Nested Struct Tests

    func testNestedStructProperty() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured("ユーザー")
            struct User {
                var name: String
                var address: Address
            }
            """,
            expandedSource: """
            struct User {
                var name: String
                var address: Address

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,
                        description: "ユーザー",
                        properties: [
                            "name": JSONSchema(type: .string),
                            "address": Address.jsonSchema
                        ],
                        required: ["name", "address"],
                        additionalProperties: false
                    )
                }
            }

            extension User: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testNestedStructArray() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured("注文")
            struct Order {
                var orderId: String
                var items: [OrderItem]
            }
            """,
            expandedSource: """
            struct Order {
                var orderId: String
                var items: [OrderItem]

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,
                        description: "注文",
                        properties: [
                            "order_id": JSONSchema(type: .string),
                            "items": JSONSchema(type: .array, items: OrderItem.jsonSchema)
                        ],
                        required: ["order_id", "items"],
                        additionalProperties: false
                    )
                }
            }

            extension Order: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testNestedStructArrayWithConstraints() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured
            struct Cart {
                @StructuredField("商品リスト", .minItems(1), .maxItems(100))
                var products: [Product]
            }
            """,
            expandedSource: """
            struct Cart {
                var products: [Product]

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,

                        properties: [
                            "products": JSONSchema(type: .array, description: "商品リスト", items: Product.jsonSchema, minItems: 1, maxItems: 100)
                        ],
                        required: ["products"],
                        additionalProperties: false
                    )
                }
            }

            extension Cart: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testOptionalNestedStruct() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured
            struct Profile {
                var name: String
                var settings: UserSettings?
            }
            """,
            expandedSource: """
            struct Profile {
                var name: String
                var settings: UserSettings?

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,

                        properties: [
                            "name": JSONSchema(type: .string),
                            "settings": UserSettings.jsonSchema
                        ],
                        required: ["name"],
                        additionalProperties: false
                    )
                }
            }

            extension Profile: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - @StructuredEnum Tests

    func testBasicEnum() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @StructuredEnum("ステータス")
            enum Status: String {
                case active
                case inactive
                case pending
            }
            """,
            expandedSource: """
            enum Status: String {
                case active
                case inactive
                case pending

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .string,
                        description: "ステータス", enum: ["active", "inactive", "pending"]
                    )
                }

                public static var enumDescription: String {
                    "ステータス:\\n- active\\n- inactive\\n- pending"
                }
            }

            extension Status: StructuredProtocol, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testEnumWithoutDescription() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @StructuredEnum
            enum Priority: String {
                case low
                case medium
                case high
            }
            """,
            expandedSource: """
            enum Priority: String {
                case low
                case medium
                case high

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .string,
                        enum: ["low", "medium", "high"]
                    )
                }

                public static var enumDescription: String {
                    "- low\\n- medium\\n- high"
                }
            }

            extension Priority: StructuredProtocol, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testEnumWithCustomRawValues() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @StructuredEnum("カテゴリ")
            enum Category: String {
                case electronics = "electronics"
                case clothing = "apparel"
                case food = "food_and_beverage"
            }
            """,
            expandedSource: """
            enum Category: String {
                case electronics = "electronics"
                case clothing = "apparel"
                case food = "food_and_beverage"

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .string,
                        description: "カテゴリ", enum: ["electronics", "apparel", "food_and_beverage"]
                    )
                }

                public static var enumDescription: String {
                    "カテゴリ:\\n- electronics\\n- apparel\\n- food_and_beverage"
                }
            }

            extension Category: StructuredProtocol, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testEnumWithSingleLineDeclaration() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @StructuredEnum
            enum Color: String {
                case red, green, blue
            }
            """,
            expandedSource: """
            enum Color: String {
                case red, green, blue

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .string,
                        enum: ["red", "green", "blue"]
                    )
                }

                public static var enumDescription: String {
                    "- red\\n- green\\n- blue"
                }
            }

            extension Color: StructuredProtocol, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testEnumErrorOnNonEnum() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @StructuredEnum
            struct NotAnEnum {
                var value: String
            }
            """,
            expandedSource: """
            struct NotAnEnum {
                var value: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@StructuredEnum can only be applied to enums", line: 1, column: 1)
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testEnumErrorOnNonStringRawValue() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @StructuredEnum
            enum IntEnum: Int {
                case one = 1
                case two = 2
            }
            """,
            expandedSource: """
            enum IntEnum: Int {
                case one = 1
                case two = 2
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@StructuredEnum requires enum with String raw value", line: 1, column: 1)
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Enum Property in Struct Tests

    func testStructWithEnumProperty() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Structured("タスク")
            struct Task {
                var title: String
                var status: Status
            }
            """,
            expandedSource: """
            struct Task {
                var title: String
                var status: Status

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,
                        description: "タスク",
                        properties: [
                            "title": JSONSchema(type: .string),
                            "status": Status.jsonSchema
                        ],
                        required: ["title", "status"],
                        additionalProperties: false
                    )
                }
            }

            extension Task: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - @StructuredCase Tests

    func testEnumWithCaseDescriptions() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @StructuredEnum("タスクの優先度")
            enum Priority: String {
                @StructuredCase("緊急ではない、後回しにできるタスク")
                case low

                @StructuredCase("通常の優先度のタスク")
                case medium

                @StructuredCase("すぐに対応が必要な緊急タスク")
                case high
            }
            """,
            expandedSource: """
            enum Priority: String {
                case low
                case medium
                case high

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .string,
                        description: "タスクの優先度", enum: ["low", "medium", "high"]
                    )
                }

                public static var enumDescription: String {
                    "タスクの優先度:\\n- low: 緊急ではない、後回しにできるタスク\\n- medium: 通常の優先度のタスク\\n- high: すぐに対応が必要な緊急タスク"
                }
            }

            extension Priority: StructuredProtocol, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testEnumWithPartialCaseDescriptions() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @StructuredEnum("ステータス")
            enum Status: String {
                @StructuredCase("処理待ちの状態")
                case pending

                case active

                @StructuredCase("完了済み")
                case completed
            }
            """,
            expandedSource: """
            enum Status: String {
                case pending

                case active
                case completed

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .string,
                        description: "ステータス", enum: ["pending", "active", "completed"]
                    )
                }

                public static var enumDescription: String {
                    "ステータス:\\n- pending: 処理待ちの状態\\n- active\\n- completed: 完了済み"
                }
            }

            extension Status: StructuredProtocol, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testEnumCaseWithCustomRawValueAndDescription() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @StructuredEnum("言語")
            enum Language: String {
                @StructuredCase("日本語")
                case japanese = "ja"

                @StructuredCase("英語")
                case english = "en"

                @StructuredCase("中国語（簡体字）")
                case chinese = "zh-CN"
            }
            """,
            expandedSource: """
            enum Language: String {
                case japanese = "ja"
                case english = "en"
                case chinese = "zh-CN"

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .string,
                        description: "言語", enum: ["ja", "en", "zh-CN"]
                    )
                }

                public static var enumDescription: String {
                    "言語:\\n- ja: 日本語\\n- en: 英語\\n- zh-CN: 中国語（簡体字）"
                }
            }

            extension Language: StructuredProtocol, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testStructuredCaseErrorOnNonEnumCase() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            struct NotAnEnum {
                @StructuredCase("これはプロパティです")
                var value: String
            }
            """,
            expandedSource: """
            struct NotAnEnum {
                var value: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@StructuredCase can only be applied to enum cases", line: 2, column: 5)
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
