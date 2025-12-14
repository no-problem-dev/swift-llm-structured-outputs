import XCTest
@testable import LLMStructuredOutputs

final class AgentTests: XCTestCase {

    // MARK: - AgentConfiguration Tests

    func testAgentConfigurationDefault() {
        let config = AgentConfiguration.default

        XCTAssertEqual(config.maxSteps, 10)
        XCTAssertTrue(config.autoExecuteTools)
    }

    func testAgentConfigurationCustom() {
        let config = AgentConfiguration(maxSteps: 5, autoExecuteTools: false)

        XCTAssertEqual(config.maxSteps, 5)
        XCTAssertFalse(config.autoExecuteTools)
    }

    func testAgentConfigurationIsSendable() {
        let config = AgentConfiguration.default

        func requireSendable<T: Sendable>(_ value: T) -> T { value }
        _ = requireSendable(config)
    }

    // MARK: - ToolCallInfo Tests

    func testToolCallInfoInit() {
        let input = "{\"location\":\"Tokyo\"}".data(using: .utf8)!
        let info = ToolCallInfo(id: "call_123", name: "get_weather", input: input)

        XCTAssertEqual(info.id, "call_123")
        XCTAssertEqual(info.name, "get_weather")
        XCTAssertEqual(info.input, input)
    }

    func testToolCallInfoDecodeInput() throws {
        struct Args: Decodable, Equatable {
            let location: String
        }

        let input = "{\"location\":\"Tokyo\"}".data(using: .utf8)!
        let info = ToolCallInfo(id: "call_123", name: "get_weather", input: input)

        let args = try info.decodeInput(as: Args.self)
        XCTAssertEqual(args.location, "Tokyo")
    }

    func testToolCallInfoDecodeInputFailure() {
        struct Args: Decodable {
            let invalidField: Int
        }

        let input = "{\"location\":\"Tokyo\"}".data(using: .utf8)!
        let info = ToolCallInfo(id: "call_123", name: "get_weather", input: input)

        XCTAssertThrowsError(try info.decodeInput(as: Args.self))
    }

    func testToolCallInfoIsSendable() {
        let input = "{}".data(using: .utf8)!
        let info = ToolCallInfo(id: "id", name: "name", input: input)

        func requireSendable<T: Sendable>(_ value: T) -> T { value }
        _ = requireSendable(info)
    }

    // MARK: - ToolResultInfo Tests

    func testToolResultInfoInit() {
        let info = ToolResultInfo(
            toolCallId: "call_123",
            name: "get_weather",
            content: "晴れ、25°C",
            isError: false
        )

        XCTAssertEqual(info.toolCallId, "call_123")
        XCTAssertEqual(info.name, "get_weather")
        XCTAssertEqual(info.content, "晴れ、25°C")
        XCTAssertFalse(info.isError)
    }

    func testToolResultInfoError() {
        let info = ToolResultInfo(
            toolCallId: "call_123",
            name: "get_weather",
            content: "API error",
            isError: true
        )

        XCTAssertTrue(info.isError)
    }

    func testToolResultInfoDefaultIsError() {
        let info = ToolResultInfo(
            toolCallId: "call_123",
            name: "get_weather",
            content: "晴れ"
        )

        XCTAssertFalse(info.isError)
    }

    func testToolResultInfoIsSendable() {
        let info = ToolResultInfo(
            toolCallId: "id",
            name: "name",
            content: "content"
        )

        func requireSendable<T: Sendable>(_ value: T) -> T { value }
        _ = requireSendable(info)
    }

    // MARK: - AgentStep Tests

    func testAgentStepThinking() {
        let response = LLMResponse(
            content: [.text("Let me think...")],
            model: "claude-3-5-sonnet",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: nil
        )
        let step: AgentStep<SimpleOutput> = .thinking(response)

        if case .thinking(let r) = step {
            XCTAssertEqual(r.content.first?.text, "Let me think...")
        } else {
            XCTFail("Expected .thinking case")
        }
    }

    func testAgentStepToolCall() {
        let input = "{}".data(using: .utf8)!
        let info = ToolCallInfo(id: "call_1", name: "tool", input: input)
        let step: AgentStep<SimpleOutput> = .toolCall(info)

        if case .toolCall(let i) = step {
            XCTAssertEqual(i.name, "tool")
        } else {
            XCTFail("Expected .toolCall case")
        }
    }

    func testAgentStepToolResult() {
        let info = ToolResultInfo(
            toolCallId: "call_1",
            name: "tool",
            content: "result"
        )
        let step: AgentStep<SimpleOutput> = .toolResult(info)

        if case .toolResult(let i) = step {
            XCTAssertEqual(i.content, "result")
        } else {
            XCTFail("Expected .toolResult case")
        }
    }

    func testAgentStepFinalResponse() {
        let output = SimpleOutput(result: "done")
        let step: AgentStep<SimpleOutput> = .finalResponse(output)

        if case .finalResponse(let o) = step {
            XCTAssertEqual(o.result, "done")
        } else {
            XCTFail("Expected .finalResponse case")
        }
    }

    func testAgentStepIsSendable() {
        let step: AgentStep<SimpleOutput> = .finalResponse(SimpleOutput(result: "test"))

        func requireSendable<T: Sendable>(_ value: T) -> T { value }
        _ = requireSendable(step)
    }

    // MARK: - AgentError Tests

    func testAgentErrorMaxStepsExceeded() {
        let error = AgentError.maxStepsExceeded(steps: 10)

        XCTAssertTrue(error.localizedDescription.contains("10"))
        XCTAssertTrue(error.localizedDescription.contains("exceeded"))
    }

    func testAgentErrorToolNotFound() {
        let error = AgentError.toolNotFound(name: "unknown_tool")

        XCTAssertTrue(error.localizedDescription.contains("unknown_tool"))
        XCTAssertTrue(error.localizedDescription.contains("not found"))
    }

    func testAgentErrorToolExecutionFailed() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: nil)
        let error = AgentError.toolExecutionFailed(name: "my_tool", underlyingError: underlyingError)

        XCTAssertTrue(error.localizedDescription.contains("my_tool"))
        XCTAssertTrue(error.localizedDescription.contains("failed"))
    }

    func testAgentErrorInvalidState() {
        let error = AgentError.invalidState("Test message")

        XCTAssertTrue(error.localizedDescription.contains("Test message"))
    }

    func testAgentErrorOutputDecodingFailed() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: nil)
        let error = AgentError.outputDecodingFailed(underlyingError)

        XCTAssertTrue(error.localizedDescription.contains("decode"))
    }

    func testAgentErrorLLMError() {
        let llmError = LLMError.emptyResponse
        let error = AgentError.llmError(llmError)

        XCTAssertTrue(error.localizedDescription.contains("LLM"))
    }

    func testAgentErrorIsSendable() {
        let error = AgentError.maxStepsExceeded(steps: 5)

        func requireSendable<T: Sendable>(_ value: T) -> T { value }
        _ = requireSendable(error)
    }

    // MARK: - AgentContext Tests

    func testAgentContextInitWithPrompt() async {
        let tools = ToolSet {}
        let context = AgentContext(
            initialPrompt: "Hello",
            systemPrompt: "You are helpful",
            tools: tools
        )

        let messages = await context.getMessages()
        let systemPrompt = await context.getSystemPrompt()
        let step = await context.getCurrentStep()
        let completed = await context.getIsCompleted()

        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.role, .user)
        XCTAssertEqual(systemPrompt, "You are helpful")
        XCTAssertEqual(step, 0)
        XCTAssertFalse(completed)
    }

    func testAgentContextInitWithMessages() async {
        let tools = ToolSet {}
        let messages = [
            LLMMessage.user("Hello"),
            LLMMessage.assistant("Hi there!")
        ]
        let context = AgentContext(
            systemPrompt: nil,
            tools: tools,
            initialMessages: messages
        )

        let storedMessages = await context.getMessages()
        XCTAssertEqual(storedMessages.count, 2)
    }

    func testAgentContextIncrementStep() async throws {
        let tools = ToolSet {}
        let context = AgentContext(
            initialPrompt: "test",
            tools: tools,
            configuration: AgentConfiguration(maxSteps: 3)
        )

        try await context.incrementStep()
        var step = await context.getCurrentStep()
        XCTAssertEqual(step, 1)

        try await context.incrementStep()
        step = await context.getCurrentStep()
        XCTAssertEqual(step, 2)

        try await context.incrementStep()
        step = await context.getCurrentStep()
        XCTAssertEqual(step, 3)

        // 最大ステップを超えるとエラー
        do {
            try await context.incrementStep()
            XCTFail("Should throw maxStepsExceeded")
        } catch let error as AgentError {
            if case .maxStepsExceeded(let steps) = error {
                XCTAssertEqual(steps, 3)
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    func testAgentContextCanContinue() async throws {
        let tools = ToolSet {}
        let context = AgentContext(
            initialPrompt: "test",
            tools: tools,
            configuration: AgentConfiguration(maxSteps: 2)
        )

        var canContinue = await context.canContinue()
        XCTAssertTrue(canContinue)

        try await context.incrementStep()
        canContinue = await context.canContinue()
        XCTAssertTrue(canContinue)

        try await context.incrementStep()
        canContinue = await context.canContinue()
        XCTAssertFalse(canContinue)
    }

    func testAgentContextMarkCompleted() async {
        let tools = ToolSet {}
        let context = AgentContext(
            initialPrompt: "test",
            tools: tools
        )

        var completed = await context.getIsCompleted()
        XCTAssertFalse(completed)

        await context.markCompleted()

        completed = await context.getIsCompleted()
        XCTAssertTrue(completed)

        let canContinue = await context.canContinue()
        XCTAssertFalse(canContinue)
    }

    func testAgentContextAddToolResults() async {
        let tools = ToolSet {}
        let context = AgentContext(
            initialPrompt: "test",
            tools: tools
        )

        let results = [
            ToolResultInfo(toolCallId: "call_1", name: "tool1", content: "result1"),
            ToolResultInfo(toolCallId: "call_2", name: "tool2", content: "result2", isError: true)
        ]

        await context.addToolResults(results)

        let messages = await context.getMessages()
        XCTAssertEqual(messages.count, 2)  // 初期メッセージ + ツール結果

        let lastMessage = messages.last!
        XCTAssertEqual(lastMessage.role, .user)

        // ツール結果が正しく追加されたことを確認
        let toolResults = lastMessage.toolResults
        XCTAssertEqual(toolResults.count, 2)
    }

    func testAgentContextExtractToolCalls() async {
        let tools = ToolSet {}
        let context = AgentContext(
            initialPrompt: "test",
            tools: tools
        )

        let response = LLMResponse(
            content: [
                .text("I'll check the weather"),
                .toolUse(id: "call_1", name: "get_weather", input: "{\"location\":\"Tokyo\"}".data(using: .utf8)!)
            ],
            model: "test",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: .toolUse
        )

        let calls = await context.extractToolCalls(from: response)
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first?.id, "call_1")
        XCTAssertEqual(calls.first?.name, "get_weather")
    }

    func testAgentContextHasToolCalls() async {
        let tools = ToolSet {}
        let context = AgentContext(
            initialPrompt: "test",
            tools: tools
        )

        let responseWithTool = LLMResponse(
            content: [.toolUse(id: "call_1", name: "tool", input: Data())],
            model: "test",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: .toolUse
        )

        let responseWithoutTool = LLMResponse(
            content: [.text("Hello")],
            model: "test",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: .endTurn
        )

        let hasCalls = await context.hasToolCalls(in: responseWithTool)
        let noCalls = await context.hasToolCalls(in: responseWithoutTool)

        XCTAssertTrue(hasCalls)
        XCTAssertFalse(noCalls)
    }

    func testAgentContextExtractText() async {
        let tools = ToolSet {}
        let context = AgentContext(
            initialPrompt: "test",
            tools: tools
        )

        let response = LLMResponse(
            content: [
                .text("Hello "),
                .toolUse(id: "call_1", name: "tool", input: Data()),
                .text("World")
            ],
            model: "test",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: nil
        )

        let text = await context.extractText(from: response)
        XCTAssertEqual(text, "Hello World")
    }

    // MARK: - LLMResponse.StopReason Extension Tests

    func testStopReasonIsToolUse() {
        XCTAssertTrue(LLMResponse.StopReason.toolUse.isToolUse)
        XCTAssertFalse(LLMResponse.StopReason.endTurn.isToolUse)
        XCTAssertFalse(LLMResponse.StopReason.maxTokens.isToolUse)
    }
}

// MARK: - Test Helpers

private struct SimpleOutput: StructuredProtocol, Equatable {
    let result: String

    static var jsonSchema: JSONSchema {
        .object(
            description: "Simple output",
            properties: [
                "result": .string(description: "Result string")
            ],
            required: ["result"]
        )
    }
}
