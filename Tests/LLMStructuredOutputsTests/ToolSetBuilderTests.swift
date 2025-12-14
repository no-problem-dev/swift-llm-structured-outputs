import XCTest
@testable import LLMStructuredOutputs

// MARK: - Test Tools

@Tool("テスト用のツール1")
struct TestTool1 {
    @ToolArgument("引数1")
    var arg1: String

    func call() async throws -> String {
        return arg1
    }
}

@Tool("テスト用のツール2")
struct TestTool2 {
    @ToolArgument("数値引数")
    var number: Int

    func call() async throws -> String {
        return String(number)
    }
}

@Tool("引数なしのツール")
struct NoArgTool {
    func call() async throws -> String {
        return "done"
    }
}

// MARK: - Tests

final class ToolSetBuilderTests: XCTestCase {

    // MARK: - Basic Block Building

    func testBuildBlockWithSingleTool() {
        let toolTypes = ToolSetBuilder.buildBlock(
            [TestTool1.self]
        )

        XCTAssertEqual(toolTypes.count, 1)
        XCTAssertEqual(toolTypes[0].toolName, "test_tool1")
    }

    func testBuildBlockWithMultipleTools() {
        let toolTypes = ToolSetBuilder.buildBlock(
            [TestTool1.self],
            [TestTool2.self],
            [NoArgTool.self]
        )

        XCTAssertEqual(toolTypes.count, 3)
        XCTAssertEqual(toolTypes[0].toolName, "test_tool1")
        XCTAssertEqual(toolTypes[1].toolName, "test_tool2")
        XCTAssertEqual(toolTypes[2].toolName, "no_arg_tool")
    }

    func testBuildBlockWithNoTools() {
        let toolTypes = ToolSetBuilder.buildBlock()

        XCTAssertTrue(toolTypes.isEmpty)
    }

    // MARK: - Expression Building

    func testBuildExpressionWithToolType() {
        let result = ToolSetBuilder.buildExpression(TestTool1.self)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].toolName, "test_tool1")
    }

    // MARK: - Optional Building

    func testBuildOptionalWithValue() {
        let toolTypes: [any LLMToolRegistrable.Type]? = [TestTool1.self]
        let result = ToolSetBuilder.buildOptional(toolTypes)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].toolName, "test_tool1")
    }

    func testBuildOptionalWithNil() {
        let toolTypes: [any LLMToolRegistrable.Type]? = nil
        let result = ToolSetBuilder.buildOptional(toolTypes)

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Either Building (if-else)

    func testBuildEitherFirst() {
        let toolTypes: [any LLMToolRegistrable.Type] = [TestTool1.self]
        let result = ToolSetBuilder.buildEither(first: toolTypes)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].toolName, "test_tool1")
    }

    func testBuildEitherSecond() {
        let toolTypes: [any LLMToolRegistrable.Type] = [TestTool2.self]
        let result = ToolSetBuilder.buildEither(second: toolTypes)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].toolName, "test_tool2")
    }

    // MARK: - Array Building (for-in)

    func testBuildArray() {
        let arrays: [[any LLMToolRegistrable.Type]] = [
            [TestTool1.self],
            [TestTool2.self]
        ]

        let result = ToolSetBuilder.buildArray(arrays)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].toolName, "test_tool1")
        XCTAssertEqual(result[1].toolName, "test_tool2")
    }

    func testBuildArrayWithEmptyArrays() {
        let arrays: [[any LLMToolRegistrable.Type]] = [
            [],
            [TestTool1.self],
            []
        ]

        let result = ToolSetBuilder.buildArray(arrays)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].toolName, "test_tool1")
    }

    // MARK: - Final Result Building

    func testBuildFinalResult() {
        let toolTypes: [any LLMToolRegistrable.Type] = [TestTool1.self, TestTool2.self]
        let result = ToolSetBuilder.buildFinalResult(toolTypes)

        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Integration Tests with ToolSet

    func testToolSetWithConditional() {
        let includeTool2 = true

        let toolSet = ToolSet {
            TestTool1.self
            if includeTool2 {
                TestTool2.self
            }
        }

        XCTAssertEqual(toolSet.count, 2)
    }

    func testToolSetWithConditionalExcluded() {
        let includeTool2 = false

        let toolSet = ToolSet {
            TestTool1.self
            if includeTool2 {
                TestTool2.self
            }
        }

        XCTAssertEqual(toolSet.count, 1)
        XCTAssertEqual(toolSet.toolNames.first, "test_tool1")
    }

    func testToolSetWithIfElse() {
        let useTool1 = true

        let toolSet = ToolSet {
            if useTool1 {
                TestTool1.self
            } else {
                TestTool2.self
            }
        }

        XCTAssertEqual(toolSet.count, 1)
        XCTAssertEqual(toolSet.toolNames.first, "test_tool1")
    }

    func testToolSetWithIfElseFalse() {
        let useTool1 = false

        let toolSet = ToolSet {
            if useTool1 {
                TestTool1.self
            } else {
                TestTool2.self
            }
        }

        XCTAssertEqual(toolSet.count, 1)
        XCTAssertEqual(toolSet.toolNames.first, "test_tool2")
    }

    func testToolSetWithAllTools() {
        let toolSet = ToolSet {
            TestTool1.self
            TestTool2.self
            NoArgTool.self
        }

        XCTAssertEqual(toolSet.count, 3)
    }

    func testEmptyToolSet() {
        let toolSet = ToolSet { }
        XCTAssertTrue(toolSet.isEmpty)
        XCTAssertEqual(toolSet.count, 0)
    }

    // MARK: - Tool Lookup Tests

    func testToolLookupByName() {
        let toolSet = ToolSet {
            TestTool1.self
            TestTool2.self
        }

        let toolType = toolSet.toolType(named: "test_tool1")
        XCTAssertNotNil(toolType)
        XCTAssertEqual(toolType?.toolName, "test_tool1")
    }

    func testToolLookupByNameNotFound() {
        let toolSet = ToolSet {
            TestTool1.self
        }

        let toolType = toolSet.toolType(named: "nonexistent")
        XCTAssertNil(toolType)
    }

    // MARK: - Tool Definitions Tests

    func testDefinitionsGeneration() {
        let toolSet = ToolSet {
            TestTool1.self
            TestTool2.self
        }

        let definitions = toolSet.definitions
        XCTAssertEqual(definitions.count, 2)

        let def1 = definitions.first { $0.name == "test_tool1" }
        XCTAssertNotNil(def1)
        XCTAssertEqual(def1?.description, "テスト用のツール1")

        let def2 = definitions.first { $0.name == "test_tool2" }
        XCTAssertNotNil(def2)
        XCTAssertEqual(def2?.description, "テスト用のツール2")
    }
}
