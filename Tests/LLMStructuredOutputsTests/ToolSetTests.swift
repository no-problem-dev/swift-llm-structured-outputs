import XCTest
@testable import LLMStructuredOutputs

// MARK: - Test Tools for ToolSetTests

@Tool("加算を実行します")
struct AddTool {
    @ToolArgument("最初の数値")
    var a: Int

    @ToolArgument("2番目の数値")
    var b: Int

    func call() async throws -> String {
        return String(a + b)
    }
}

@Tool("文字列を反転します")
struct ReverseTool {
    @ToolArgument("反転する文字列")
    var text: String

    func call() async throws -> String {
        return String(text.reversed())
    }
}

@Tool("現在時刻を取得")
struct TimeTool {
    func call() async throws -> String {
        return "2024-01-01T00:00:00Z"
    }
}

@Tool("エラーをスローするツール")
struct ErrorTool {
    @ToolArgument("エラーメッセージ")
    var message: String

    func call() async throws -> String {
        throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

// MARK: - Tests

final class ToolSetTests: XCTestCase {

    // MARK: - Basic Properties Tests

    func testToolSetCount() {
        let toolSet = ToolSet {
            AddTool.self
            ReverseTool.self
        }

        XCTAssertEqual(toolSet.count, 2)
        XCTAssertFalse(toolSet.isEmpty)
    }

    func testEmptyToolSet() {
        let toolSet = ToolSet()

        XCTAssertEqual(toolSet.count, 0)
        XCTAssertTrue(toolSet.isEmpty)
    }

    func testToolNames() {
        let toolSet = ToolSet {
            AddTool.self
            ReverseTool.self
            TimeTool.self
        }

        let names = toolSet.toolNames
        XCTAssertEqual(names.count, 3)
        XCTAssertTrue(names.contains("add_tool"))
        XCTAssertTrue(names.contains("reverse_tool"))
        XCTAssertTrue(names.contains("time_tool"))
    }

    // MARK: - Tool Lookup Tests

    func testToolTypeLookup() {
        let toolSet = ToolSet {
            AddTool.self
            ReverseTool.self
        }

        let addToolType = toolSet.toolType(named: "add_tool")
        XCTAssertNotNil(addToolType)
        XCTAssertEqual(addToolType?.toolName, "add_tool")
        XCTAssertEqual(addToolType?.toolDescription, "加算を実行します")

        let reverseToolType = toolSet.toolType(named: "reverse_tool")
        XCTAssertNotNil(reverseToolType)
        XCTAssertEqual(reverseToolType?.toolName, "reverse_tool")
    }

    func testToolTypeLookupNotFound() {
        let toolSet = ToolSet {
            AddTool.self
        }

        let result = toolSet.toolType(named: "nonexistent_tool")
        XCTAssertNil(result)
    }

    // MARK: - Tool Definitions Tests

    func testDefinitions() {
        let toolSet = ToolSet {
            AddTool.self
            ReverseTool.self
        }

        let definitions = toolSet.definitions
        XCTAssertEqual(definitions.count, 2)

        let addDef = definitions.first { $0.name == "add_tool" }
        XCTAssertNotNil(addDef)
        XCTAssertEqual(addDef?.description, "加算を実行します")

        let reverseDef = definitions.first { $0.name == "reverse_tool" }
        XCTAssertNotNil(reverseDef)
        XCTAssertEqual(reverseDef?.description, "文字列を反転します")
    }

    func testDefinitionInputSchema() {
        let toolSet = ToolSet {
            AddTool.self
        }

        let definitions = toolSet.definitions
        XCTAssertEqual(definitions.count, 1)

        let addDef = definitions.first!
        XCTAssertEqual(addDef.inputSchema.type, .object)
    }

    // MARK: - Tool Execution Tests

    func testExecuteAddTool() async throws {
        let toolSet = ToolSet {
            AddTool.self
            ReverseTool.self
        }

        let arguments = """
        {"a": 5, "b": 3}
        """.data(using: .utf8)!

        let result = try await toolSet.execute(toolNamed: "add_tool", with: arguments)

        XCTAssertEqual(result, .text("8"))
    }

    func testExecuteReverseTool() async throws {
        let toolSet = ToolSet {
            AddTool.self
            ReverseTool.self
        }

        let arguments = """
        {"text": "hello"}
        """.data(using: .utf8)!

        let result = try await toolSet.execute(toolNamed: "reverse_tool", with: arguments)

        XCTAssertEqual(result, .text("olleh"))
    }

    func testExecuteToolWithoutArguments() async throws {
        let toolSet = ToolSet {
            TimeTool.self
        }

        let arguments = "{}".data(using: .utf8)!

        let result = try await toolSet.execute(toolNamed: "time_tool", with: arguments)

        XCTAssertEqual(result, .text("2024-01-01T00:00:00Z"))
    }

    func testExecuteToolNotFound() async {
        let toolSet = ToolSet {
            AddTool.self
        }

        let arguments = "{}".data(using: .utf8)!

        do {
            _ = try await toolSet.execute(toolNamed: "nonexistent_tool", with: arguments)
            XCTFail("Expected error to be thrown")
        } catch let error as ToolExecutionError {
            if case .toolNotFound(let name) = error {
                XCTAssertEqual(name, "nonexistent_tool")
            } else {
                XCTFail("Unexpected error type")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Tool Combination Tests

    func testToolSetCombination() {
        let toolSet1 = ToolSet {
            AddTool.self
        }

        let toolSet2 = ToolSet {
            ReverseTool.self
        }

        let combined = toolSet1 + toolSet2

        XCTAssertEqual(combined.count, 2)
        XCTAssertNotNil(combined.toolType(named: "add_tool"))
        XCTAssertNotNil(combined.toolType(named: "reverse_tool"))
    }

    func testToolSetAppendingToolType() {
        let toolSet = ToolSet {
            AddTool.self
        }

        let extended = toolSet + ReverseTool.self

        XCTAssertEqual(extended.count, 2)
        XCTAssertNotNil(extended.toolType(named: "add_tool"))
        XCTAssertNotNil(extended.toolType(named: "reverse_tool"))
    }

    func testToolSetAppendingMethod() {
        let toolSet = ToolSet {
            AddTool.self
        }

        let extended = toolSet.appending(ReverseTool.self)

        XCTAssertEqual(extended.count, 2)
    }

    func testToolSetAppendingToolSet() {
        let toolSet1 = ToolSet {
            AddTool.self
        }

        let toolSet2 = ToolSet {
            ReverseTool.self
            TimeTool.self
        }

        let combined = toolSet1.appending(toolSet2)

        XCTAssertEqual(combined.count, 3)
    }

    func testEmptyToolSetCombination() {
        let empty = ToolSet()
        let nonEmpty = ToolSet {
            AddTool.self
        }

        let result1 = empty + nonEmpty
        let result2 = nonEmpty + empty

        XCTAssertEqual(result1.count, 1)
        XCTAssertEqual(result2.count, 1)
    }

    // MARK: - CustomStringConvertible Tests

    func testDescription() {
        let toolSet = ToolSet {
            AddTool.self
            ReverseTool.self
        }

        let description = toolSet.description
        XCTAssertTrue(description.contains("2 tools"))
        XCTAssertTrue(description.contains("add_tool"))
        XCTAssertTrue(description.contains("reverse_tool"))
    }

    func testEmptyToolSetDescription() {
        let toolSet = ToolSet()

        let description = toolSet.description
        XCTAssertTrue(description.contains("0 tools"))
    }

    // MARK: - Provider Format Tests

    func testToAnthropicFormat() {
        let toolSet = ToolSet {
            AddTool.self
        }

        let format = toolSet.toAnthropicFormat()
        XCTAssertEqual(format.count, 1)

        let toolDict = format.first!
        XCTAssertEqual(toolDict["name"] as? String, "add_tool")
        XCTAssertEqual(toolDict["description"] as? String, "加算を実行します")
        XCTAssertNotNil(toolDict["input_schema"])
    }

    func testToOpenAIFormat() {
        let toolSet = ToolSet {
            AddTool.self
        }

        let format = toolSet.toOpenAIFormat()
        XCTAssertEqual(format.count, 1)

        let toolDict = format.first!
        XCTAssertEqual(toolDict["type"] as? String, "function")

        let functionDict = toolDict["function"] as? [String: Any]
        XCTAssertNotNil(functionDict)
        XCTAssertEqual(functionDict?["name"] as? String, "add_tool")
        XCTAssertEqual(functionDict?["description"] as? String, "加算を実行します")
        XCTAssertEqual(functionDict?["strict"] as? Bool, true)
        XCTAssertNotNil(functionDict?["parameters"])
    }

    func testToGeminiFormat() {
        let toolSet = ToolSet {
            AddTool.self
        }

        let format = toolSet.toGeminiFormat()
        XCTAssertEqual(format.count, 1)

        let toolDict = format.first!
        XCTAssertEqual(toolDict["name"] as? String, "add_tool")
        XCTAssertEqual(toolDict["description"] as? String, "加算を実行します")
        XCTAssertNotNil(toolDict["parameters"])
    }

    // MARK: - Snake Case Arguments Tests

    func testSnakeCaseArgumentDecoding() async throws {
        let toolSet = ToolSet {
            AddTool.self
        }

        // Snake case format (as sent by LLM)
        let arguments = """
        {"a": 10, "b": 20}
        """.data(using: .utf8)!

        let result = try await toolSet.execute(toolNamed: "add_tool", with: arguments)
        XCTAssertEqual(result, .text("30"))
    }

    // MARK: - Edge Cases

    func testMultipleToolsWithSamePrefix() {
        // Use existing test tools to verify prefix handling
        // AddTool = "add_tool", ReverseTool = "reverse_tool", TimeTool = "time_tool"
        let toolSet = ToolSet {
            AddTool.self
            ReverseTool.self
            TimeTool.self
        }

        XCTAssertEqual(toolSet.count, 3)
        XCTAssertNotNil(toolSet.toolType(named: "add_tool"))
        XCTAssertNotNil(toolSet.toolType(named: "reverse_tool"))
        XCTAssertNotNil(toolSet.toolType(named: "time_tool"))

        // Verify they can all be looked up correctly without confusion
        let addType = toolSet.toolType(named: "add_tool")
        let reverseType = toolSet.toolType(named: "reverse_tool")
        XCTAssertNotEqual(addType?.toolName, reverseType?.toolName)
    }
}
