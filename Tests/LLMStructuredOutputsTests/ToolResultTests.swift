import XCTest
@testable import LLMStructuredOutputs
@testable import LLMClient
@testable import LLMTool

final class ToolResultTests: XCTestCase {

    // MARK: - ToolResult Cases

    func testTextResult() {
        let result = ToolResult.text("Hello, World!")

        XCTAssertEqual(result.stringValue, "Hello, World!")
        XCTAssertFalse(result.isError)
    }

    func testJsonResult() {
        let data = "{\"key\":\"value\"}".data(using: .utf8)!
        let result = ToolResult.json(data)

        XCTAssertEqual(result.stringValue, "{\"key\":\"value\"}")
        XCTAssertFalse(result.isError)
    }

    func testErrorResult() {
        let result = ToolResult.error("Something went wrong")

        XCTAssertEqual(result.stringValue, "Error: Something went wrong")
        XCTAssertTrue(result.isError)
    }

    // MARK: - ToolResult.encoded Tests

    func testEncodedWithSimpleStruct() throws {
        struct TestData: Codable {
            let name: String
            let value: Int
        }

        let data = TestData(name: "test", value: 42)
        let result = try ToolResult.encoded(data)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.stringValue.contains("\"name\":\"test\""))
        XCTAssertTrue(result.stringValue.contains("\"value\":42"))
    }

    func testEncodedWithArray() throws {
        let array = ["a", "b", "c"]
        let result = try ToolResult.encoded(array)

        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.stringValue, "[\"a\",\"b\",\"c\"]")
    }

    func testEncodedWithDictionary() throws {
        let dict = ["key1": "value1", "key2": "value2"]
        let result = try ToolResult.encoded(dict)

        XCTAssertFalse(result.isError)
        // sortedKeys を使用しているので順番が保証される
        XCTAssertTrue(result.stringValue.contains("\"key1\":\"value1\""))
        XCTAssertTrue(result.stringValue.contains("\"key2\":\"value2\""))
    }

    // MARK: - ToolResult Equatable Tests

    func testEquatableText() {
        let result1 = ToolResult.text("same")
        let result2 = ToolResult.text("same")
        let result3 = ToolResult.text("different")

        XCTAssertEqual(result1, result2)
        XCTAssertNotEqual(result1, result3)
    }

    func testEquatableJson() {
        let data = "test".data(using: .utf8)!
        let result1 = ToolResult.json(data)
        let result2 = ToolResult.json(data)
        let result3 = ToolResult.json("other".data(using: .utf8)!)

        XCTAssertEqual(result1, result2)
        XCTAssertNotEqual(result1, result3)
    }

    func testEquatableError() {
        let result1 = ToolResult.error("error")
        let result2 = ToolResult.error("error")
        let result3 = ToolResult.error("different")

        XCTAssertEqual(result1, result2)
        XCTAssertNotEqual(result1, result3)
    }

    func testEquatableDifferentCases() {
        let textResult = ToolResult.text("test")
        let errorResult = ToolResult.error("test")

        XCTAssertNotEqual(textResult, errorResult)
    }

    // MARK: - ToolResultConvertible - String

    func testStringToToolResult() throws {
        let string = "Hello"
        let result = try string.toToolResult()

        XCTAssertEqual(result, .text("Hello"))
    }

    // MARK: - ToolResultConvertible - Int

    func testIntToToolResult() throws {
        let number = 42
        let result = try number.toToolResult()

        XCTAssertEqual(result, .text("42"))
    }

    func testNegativeIntToToolResult() throws {
        let number = -123
        let result = try number.toToolResult()

        XCTAssertEqual(result, .text("-123"))
    }

    // MARK: - ToolResultConvertible - Double

    func testDoubleToToolResult() throws {
        let number = 3.14
        let result = try number.toToolResult()

        XCTAssertEqual(result, .text("3.14"))
    }

    // MARK: - ToolResultConvertible - Bool

    func testBoolTrueToToolResult() throws {
        let value = true
        let result = try value.toToolResult()

        XCTAssertEqual(result, .text("true"))
    }

    func testBoolFalseToToolResult() throws {
        let value = false
        let result = try value.toToolResult()

        XCTAssertEqual(result, .text("false"))
    }

    // MARK: - ToolResultConvertible - Array

    func testStringArrayToToolResult() throws {
        let array = ["a", "b", "c"]
        let result = try array.toToolResult()

        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.stringValue, "[\"a\",\"b\",\"c\"]")
    }

    func testIntArrayToToolResult() throws {
        let array = [1, 2, 3]
        let result = try array.toToolResult()

        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.stringValue, "[1,2,3]")
    }

    func testEmptyArrayToToolResult() throws {
        let array: [String] = []
        let result = try array.toToolResult()

        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.stringValue, "[]")
    }

    // MARK: - ToolResultConvertible - Dictionary

    func testDictionaryToToolResult() throws {
        let dict = ["key": "value"]
        let result = try dict.toToolResult()

        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.stringValue, "{\"key\":\"value\"}")
    }

    func testEmptyDictionaryToToolResult() throws {
        let dict: [String: String] = [:]
        let result = try dict.toToolResult()

        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.stringValue, "{}")
    }

    // MARK: - ToolResultConvertible - ToolResult

    func testToolResultToToolResult() throws {
        let original = ToolResult.text("test")
        let result = try original.toToolResult()

        XCTAssertEqual(result, original)
    }

    func testErrorToolResultToToolResult() throws {
        let original = ToolResult.error("error message")
        let result = try original.toToolResult()

        XCTAssertEqual(result, original)
    }

    // MARK: - JSONToolResult

    func testJSONToolResult() throws {
        struct TestStruct: Codable, Sendable {
            let name: String
            let count: Int
        }

        let data = TestStruct(name: "test", count: 5)
        let wrapper = JSONToolResult(data)
        let result = try wrapper.toToolResult()

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.stringValue.contains("\"name\":\"test\""))
        XCTAssertTrue(result.stringValue.contains("\"count\":5"))
    }

    // MARK: - Edge Cases

    func testEmptyStringResult() {
        let result = ToolResult.text("")

        XCTAssertEqual(result.stringValue, "")
        XCTAssertFalse(result.isError)
    }

    func testUnicodeStringResult() {
        let result = ToolResult.text("こんにちは世界 🌍")

        XCTAssertEqual(result.stringValue, "こんにちは世界 🌍")
        XCTAssertFalse(result.isError)
    }

    func testEmptyJsonData() {
        let result = ToolResult.json(Data())

        XCTAssertEqual(result.stringValue, "")
        XCTAssertFalse(result.isError)
    }

    func testInvalidUtf8JsonData() {
        // 無効なUTF-8データ
        let invalidData = Data([0xFF, 0xFE])
        let result = ToolResult.json(invalidData)

        // 無効なUTF-8は空文字列になる
        XCTAssertEqual(result.stringValue, "")
        XCTAssertFalse(result.isError)
    }
}
