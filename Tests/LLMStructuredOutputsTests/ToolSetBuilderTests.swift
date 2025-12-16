import XCTest
@testable import LLMStructuredOutputs
@testable import LLMClient
@testable import LLMTool

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
        let tools = ToolSetBuilder.buildBlock(
            [TestTool1()]
        )

        XCTAssertEqual(tools.count, 1)
        XCTAssertEqual(tools[0].name, "test_tool1")
    }

    func testBuildBlockWithMultipleTools() {
        let tools = ToolSetBuilder.buildBlock(
            [TestTool1()],
            [TestTool2()],
            [NoArgTool()]
        )

        XCTAssertEqual(tools.count, 3)
        XCTAssertEqual(tools[0].name, "test_tool1")
        XCTAssertEqual(tools[1].name, "test_tool2")
        XCTAssertEqual(tools[2].name, "no_arg_tool")
    }

    func testBuildBlockWithNoTools() {
        let tools = ToolSetBuilder.buildBlock()

        XCTAssertTrue(tools.isEmpty)
    }

    // MARK: - Expression Building

    func testBuildExpressionWithTool() {
        let result = ToolSetBuilder.buildExpression(TestTool1())

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "test_tool1")
    }

    // MARK: - Optional Building

    func testBuildOptionalWithValue() {
        let tools: [any Tool]? = [TestTool1()]
        let result = ToolSetBuilder.buildOptional(tools)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "test_tool1")
    }

    func testBuildOptionalWithNil() {
        let tools: [any Tool]? = nil
        let result = ToolSetBuilder.buildOptional(tools)

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Either Building (if-else)

    func testBuildEitherFirst() {
        let tools: [any Tool] = [TestTool1()]
        let result = ToolSetBuilder.buildEither(first: tools)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "test_tool1")
    }

    func testBuildEitherSecond() {
        let tools: [any Tool] = [TestTool2()]
        let result = ToolSetBuilder.buildEither(second: tools)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "test_tool2")
    }

    // MARK: - Array Building (for-in)

    func testBuildArray() {
        let arrays: [[any Tool]] = [
            [TestTool1()],
            [TestTool2()]
        ]

        let result = ToolSetBuilder.buildArray(arrays)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].name, "test_tool1")
        XCTAssertEqual(result[1].name, "test_tool2")
    }

    func testBuildArrayWithEmptyArrays() {
        let arrays: [[any Tool]] = [
            [],
            [TestTool1()],
            []
        ]

        let result = ToolSetBuilder.buildArray(arrays)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "test_tool1")
    }

    // MARK: - Final Result Building

    func testBuildFinalResult() {
        let tools: [any Tool] = [TestTool1(), TestTool2()]
        let result = ToolSetBuilder.buildFinalResult(tools)

        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Integration Tests with ToolSet

    func testToolSetWithConditional() {
        let includeTool2 = true

        let toolSet = ToolSet {
            TestTool1()
            if includeTool2 {
                TestTool2()
            }
        }

        XCTAssertEqual(toolSet.count, 2)
    }

    func testToolSetWithConditionalExcluded() {
        let includeTool2 = false

        let toolSet = ToolSet {
            TestTool1()
            if includeTool2 {
                TestTool2()
            }
        }

        XCTAssertEqual(toolSet.count, 1)
        XCTAssertEqual(toolSet.toolNames.first, "test_tool1")
    }

    func testToolSetWithIfElse() {
        let useTool1 = true

        let toolSet = ToolSet {
            if useTool1 {
                TestTool1()
            } else {
                TestTool2()
            }
        }

        XCTAssertEqual(toolSet.count, 1)
        XCTAssertEqual(toolSet.toolNames.first, "test_tool1")
    }

    func testToolSetWithIfElseFalse() {
        let useTool1 = false

        let toolSet = ToolSet {
            if useTool1 {
                TestTool1()
            } else {
                TestTool2()
            }
        }

        XCTAssertEqual(toolSet.count, 1)
        XCTAssertEqual(toolSet.toolNames.first, "test_tool2")
    }

    func testToolSetWithAllTools() {
        let toolSet = ToolSet {
            TestTool1()
            TestTool2()
            NoArgTool()
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
            TestTool1()
            TestTool2()
        }

        let tool = toolSet.tool(named: "test_tool1")
        XCTAssertNotNil(tool)
        XCTAssertEqual(tool?.name, "test_tool1")
    }

    func testToolLookupByNameNotFound() {
        let toolSet = ToolSet {
            TestTool1()
        }

        let tool = toolSet.tool(named: "nonexistent")
        XCTAssertNil(tool)
    }

    // MARK: - Tool Definitions Tests

    func testDefinitionsGeneration() {
        let toolSet = ToolSet {
            TestTool1()
            TestTool2()
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
