import XCTest
@testable import LLMStructuredOutputs
@testable import LLMClient
@testable import LLMTool
@testable import LLMAgent
@testable import LLMConversationalAgent

final class ConversationalAgentTests: XCTestCase {

    // MARK: - ConversationalAgentStep Tests

    func testConversationalAgentStepUserMessage() {
        let step: ConversationalAgentStep<SimpleOutput> = .userMessage("Hello")

        if case .userMessage(let msg) = step {
            XCTAssertEqual(msg, "Hello")
        } else {
            XCTFail("Expected .userMessage case")
        }
    }

    func testConversationalAgentStepThinking() {
        let response = LLMResponse(
            content: [.text("Let me think...")],
            model: "claude-3-5-sonnet",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: nil
        )
        let step: ConversationalAgentStep<SimpleOutput> = .thinking(response)

        if case .thinking(let r) = step {
            XCTAssertEqual(r.content.first?.text, "Let me think...")
        } else {
            XCTFail("Expected .thinking case")
        }
    }

    func testConversationalAgentStepToolCall() {
        let arguments = "{}".data(using: .utf8)!
        let call = ToolCall(id: "call_1", name: "search", arguments: arguments)
        let step: ConversationalAgentStep<SimpleOutput> = .toolCall(call)

        if case .toolCall(let c) = step {
            XCTAssertEqual(c.name, "search")
        } else {
            XCTFail("Expected .toolCall case")
        }
    }

    func testConversationalAgentStepToolResult() {
        let response = ToolResponse(
            callId: "call_1",
            name: "search",
            output: "Found 3 results"
        )
        let step: ConversationalAgentStep<SimpleOutput> = .toolResult(response)

        if case .toolResult(let r) = step {
            XCTAssertEqual(r.output, "Found 3 results")
        } else {
            XCTFail("Expected .toolResult case")
        }
    }

    func testConversationalAgentStepInterrupted() {
        let step: ConversationalAgentStep<SimpleOutput> = .interrupted("Focus on security")

        if case .interrupted(let msg) = step {
            XCTAssertEqual(msg, "Focus on security")
        } else {
            XCTFail("Expected .interrupted case")
        }
    }

    func testConversationalAgentStepTextResponse() {
        let step: ConversationalAgentStep<SimpleOutput> = .textResponse("Here is my analysis...")

        if case .textResponse(let text) = step {
            XCTAssertEqual(text, "Here is my analysis...")
        } else {
            XCTFail("Expected .textResponse case")
        }
    }

    func testConversationalAgentStepFinalResponse() {
        let output = SimpleOutput(result: "completed")
        let step: ConversationalAgentStep<SimpleOutput> = .finalResponse(output)

        if case .finalResponse(let o) = step {
            XCTAssertEqual(o.result, "completed")
        } else {
            XCTFail("Expected .finalResponse case")
        }
    }

    func testConversationalAgentStepIsSendable() {
        let step: ConversationalAgentStep<SimpleOutput> = .userMessage("test")

        func requireSendable<T: Sendable>(_ value: T) -> T { value }
        _ = requireSendable(step)
    }

    // MARK: - ConversationalAgentStep Convenience Properties Tests

    func testConversationalAgentStepIsUserRelated() {
        let userMessage: ConversationalAgentStep<SimpleOutput> = .userMessage("Hello")
        let interrupted: ConversationalAgentStep<SimpleOutput> = .interrupted("Focus")
        let thinking: ConversationalAgentStep<SimpleOutput> = .thinking(makeMockResponse())

        XCTAssertTrue(userMessage.isUserRelated)
        XCTAssertTrue(interrupted.isUserRelated)
        XCTAssertFalse(thinking.isUserRelated)
    }

    func testConversationalAgentStepIsToolRelated() {
        let toolCall: ConversationalAgentStep<SimpleOutput> = .toolCall(makeMockToolCall())
        let toolResult: ConversationalAgentStep<SimpleOutput> = .toolResult(makeMockToolResponse())
        let userMessage: ConversationalAgentStep<SimpleOutput> = .userMessage("Hello")

        XCTAssertTrue(toolCall.isToolRelated)
        XCTAssertTrue(toolResult.isToolRelated)
        XCTAssertFalse(userMessage.isToolRelated)
    }

    func testConversationalAgentStepIsFinalStep() {
        let textResponse: ConversationalAgentStep<SimpleOutput> = .textResponse("text")
        let finalResponse: ConversationalAgentStep<SimpleOutput> = .finalResponse(SimpleOutput(result: "done"))
        let thinking: ConversationalAgentStep<SimpleOutput> = .thinking(makeMockResponse())

        XCTAssertTrue(textResponse.isFinalStep)
        XCTAssertTrue(finalResponse.isFinalStep)
        XCTAssertFalse(thinking.isFinalStep)
    }

    // MARK: - ConversationalAgentStep CustomStringConvertible Tests

    func testConversationalAgentStepDescription() {
        let userMessage: ConversationalAgentStep<SimpleOutput> = .userMessage("Hello world")
        XCTAssertTrue(userMessage.description.contains("userMessage"))

        let toolCall: ConversationalAgentStep<SimpleOutput> = .toolCall(makeMockToolCall())
        XCTAssertTrue(toolCall.description.contains("toolCall"))
        XCTAssertTrue(toolCall.description.contains("search"))
    }

    // MARK: - ConversationalAgentEvent Tests

    func testConversationalAgentEventUserMessage() {
        let message = LLMMessage.user("Hello")
        let event = ConversationalAgentEvent.userMessage(message)

        if case .userMessage(let msg) = event {
            XCTAssertEqual(msg.role, .user)
        } else {
            XCTFail("Expected .userMessage event")
        }
    }

    func testConversationalAgentEventAssistantMessage() {
        let message = LLMMessage.assistant("Hi there!")
        let event = ConversationalAgentEvent.assistantMessage(message)

        if case .assistantMessage(let msg) = event {
            XCTAssertEqual(msg.role, .assistant)
        } else {
            XCTFail("Expected .assistantMessage event")
        }
    }

    func testConversationalAgentEventInterruptQueued() {
        let event = ConversationalAgentEvent.interruptQueued("Focus on security")

        if case .interruptQueued(let msg) = event {
            XCTAssertEqual(msg, "Focus on security")
        } else {
            XCTFail("Expected .interruptQueued event")
        }
    }

    func testConversationalAgentEventInterruptProcessed() {
        let event = ConversationalAgentEvent.interruptProcessed("Focus on security")

        if case .interruptProcessed(let msg) = event {
            XCTAssertEqual(msg, "Focus on security")
        } else {
            XCTFail("Expected .interruptProcessed event")
        }
    }

    func testConversationalAgentEventSessionLifecycle() {
        let started = ConversationalAgentEvent.sessionStarted
        let completed = ConversationalAgentEvent.sessionCompleted
        let cleared = ConversationalAgentEvent.cleared

        if case .sessionStarted = started {} else {
            XCTFail("Expected .sessionStarted event")
        }
        if case .sessionCompleted = completed {} else {
            XCTFail("Expected .sessionCompleted event")
        }
        if case .cleared = cleared {} else {
            XCTFail("Expected .cleared event")
        }
    }

    func testConversationalAgentEventError() {
        let error = ConversationalAgentError.sessionAlreadyRunning
        let event = ConversationalAgentEvent.error(error)

        if case .error(let e) = event {
            XCTAssertTrue(e.localizedDescription.contains("already running"))
        } else {
            XCTFail("Expected .error event")
        }
    }

    func testConversationalAgentEventIsSendable() {
        let event = ConversationalAgentEvent.sessionStarted

        func requireSendable<T: Sendable>(_ value: T) -> T { value }
        _ = requireSendable(event)
    }

    // MARK: - ConversationalAgentError Tests

    func testConversationalAgentErrorSessionAlreadyRunning() {
        let error = ConversationalAgentError.sessionAlreadyRunning

        XCTAssertTrue(error.localizedDescription.contains("already running"))
    }

    func testConversationalAgentErrorMaxStepsExceeded() {
        let error = ConversationalAgentError.maxStepsExceeded(steps: 10)

        XCTAssertTrue(error.localizedDescription.contains("10"))
        XCTAssertTrue(error.localizedDescription.contains("exceeded"))
    }

    func testConversationalAgentErrorToolExecutionFailed() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: nil)
        let error = ConversationalAgentError.toolExecutionFailed(name: "search", underlyingError: underlyingError)

        XCTAssertTrue(error.localizedDescription.contains("search"))
        XCTAssertTrue(error.localizedDescription.contains("failed"))
    }

    func testConversationalAgentErrorLLMError() {
        let llmError = LLMError.emptyResponse
        let error = ConversationalAgentError.llmError(llmError)

        XCTAssertTrue(error.localizedDescription.contains("LLM"))
    }

    func testConversationalAgentErrorOutputDecodingFailed() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: nil)
        let error = ConversationalAgentError.outputDecodingFailed(underlyingError)

        XCTAssertTrue(error.localizedDescription.contains("decode"))
    }

    func testConversationalAgentErrorInvalidState() {
        let error = ConversationalAgentError.invalidState("Test message")

        XCTAssertTrue(error.localizedDescription.contains("Test message"))
    }

    func testConversationalAgentErrorIsSendable() {
        let error = ConversationalAgentError.sessionAlreadyRunning

        func requireSendable<T: Sendable>(_ value: T) -> T { value }
        _ = requireSendable(error)
    }

    // MARK: - ConversationalAgentSession Basic Tests

    func testConversationalAgentSessionInitialization() async {
        let client = MockAgentCapableClient()
        let tools = ToolSet {}

        let session = ConversationalAgentSession(
            client: client,
            systemPrompt: Prompt {
                PromptComponent.role("You are helpful.")
            },
            tools: tools
        )

        let running = await session.running
        let turnCount = await session.turnCount
        let messages = await session.getMessages()

        XCTAssertFalse(running)
        XCTAssertEqual(turnCount, 0)
        XCTAssertTrue(messages.isEmpty)
    }

    func testConversationalAgentSessionClear() async {
        let client = MockAgentCapableClient()
        let tools = ToolSet {}

        let session = ConversationalAgentSession(
            client: client,
            tools: tools
        )

        await session.clear()

        let messages = await session.getMessages()
        XCTAssertTrue(messages.isEmpty)
    }

    func testConversationalAgentSessionInterruptQueue() async {
        let client = MockAgentCapableClient()
        let tools = ToolSet {}

        let session = ConversationalAgentSession(
            client: client,
            tools: tools
        )

        await session.interrupt("First interrupt")
        await session.interrupt("Second interrupt")

        await session.clearInterrupts()
    }

    func testConversationalAgentSessionEventStream() async {
        let client = MockAgentCapableClient()
        let tools = ToolSet {}

        let session = ConversationalAgentSession(
            client: client,
            tools: tools
        )

        let eventStream = session.eventStream
        XCTAssertNotNil(eventStream)
    }

    // MARK: - ConversationalAgentStepStream Protocol Conformance Tests

    func testConversationalAgentStepSequenceConformsToProtocol() {
        let stream = AsyncThrowingStream<ConversationalAgentStep<SimpleOutput>, Error> { continuation in
            continuation.yield(.userMessage("test"))
            continuation.finish()
        }

        let sequence = ConversationalAgentStepSequence(stream: stream)

        func requireStepStream<S: ConversationalAgentStepStream>(_ stream: S) where S.Output == SimpleOutput {
            // Protocol conformance check
        }

        requireStepStream(sequence)
    }

    func testConversationalAgentStepSequenceIteration() async throws {
        let stream = AsyncThrowingStream<ConversationalAgentStep<SimpleOutput>, Error> { continuation in
            continuation.yield(.userMessage("Hello"))
            continuation.yield(.textResponse("World"))
            continuation.finish()
        }

        let sequence = ConversationalAgentStepSequence(stream: stream)

        var steps: [ConversationalAgentStep<SimpleOutput>] = []
        for try await step in sequence {
            steps.append(step)
        }

        XCTAssertEqual(steps.count, 2)
        if case .userMessage(let msg) = steps[0] {
            XCTAssertEqual(msg, "Hello")
        } else {
            XCTFail("Expected .userMessage")
        }
        if case .textResponse(let text) = steps[1] {
            XCTAssertEqual(text, "World")
        } else {
            XCTFail("Expected .textResponse")
        }
    }

    func testConversationalAgentStepSequenceIsSendable() {
        let stream = AsyncThrowingStream<ConversationalAgentStep<SimpleOutput>, Error> { continuation in
            continuation.finish()
        }

        let sequence = ConversationalAgentStepSequence(stream: stream)

        func requireSendable<T: Sendable>(_ value: T) -> T { value }
        _ = requireSendable(sequence)
    }

    // MARK: - Helper Methods

    private func makeMockResponse() -> LLMResponse {
        LLMResponse(
            content: [.text("thinking...")],
            model: "test",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: nil
        )
    }

    private func makeMockToolCall() -> ToolCall {
        ToolCall(
            id: "call_1",
            name: "search",
            arguments: "{}".data(using: .utf8)!
        )
    }

    private func makeMockToolResponse() -> ToolResponse {
        ToolResponse(
            callId: "call_1",
            name: "search",
            output: "results"
        )
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

/// テスト用のモック AgentCapableClient
private actor MockAgentCapableClient: AgentCapableClient {
    typealias Model = MockModel

    var responses: [LLMResponse] = []
    private var responseIndex = 0

    func planToolCalls(
        messages: [LLMMessage],
        model: MockModel,
        tools: ToolSet,
        toolChoice: ToolChoice?,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> ToolCallResponse {
        ToolCallResponse(
            toolCalls: [],
            text: nil,
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: .endTurn,
            model: "mock"
        )
    }

    func executeAgentStep(
        messages: [LLMMessage],
        model: MockModel,
        systemPrompt: Prompt?,
        tools: ToolSet,
        toolChoice: ToolChoice?,
        responseSchema: JSONSchema?
    ) async throws -> LLMResponse {
        if responseIndex < responses.count {
            let response = responses[responseIndex]
            responseIndex += 1
            return response
        }

        return LLMResponse(
            content: [.text("{\"result\":\"default\"}")],
            model: "mock",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: .endTurn
        )
    }

    func reset() {
        responseIndex = 0
    }
}

private struct MockModel: Sendable, Equatable {
    let name: String

    static let test = MockModel(name: "test")
}
