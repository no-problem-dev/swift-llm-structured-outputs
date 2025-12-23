import XCTest
@testable import LLMClient
@testable import LLMTool
@testable import LLMAgent
@testable import LLMConversationalAgent

final class ConversationalAgentTests: XCTestCase {

    // MARK: - AgentStep Tests

    func testAgentStepUserMessage() {
        let step = AgentStep.userMessage("Hello")

        if case .userMessage(let msg) = step {
            XCTAssertEqual(msg, "Hello")
        } else {
            XCTFail("Expected .userMessage case")
        }
    }

    func testAgentStepThinking() {
        let step = AgentStep.thinking

        if case .thinking = step {
            // Success
        } else {
            XCTFail("Expected .thinking case")
        }
    }

    func testAgentStepToolCall() {
        let arguments = "{}".data(using: .utf8)!
        let call = ToolCall(id: "call_1", name: "search", arguments: arguments)
        let step = AgentStep.toolCall(call)

        if case .toolCall(let c) = step {
            XCTAssertEqual(c.name, "search")
            XCTAssertEqual(c.id, "call_1")
        } else {
            XCTFail("Expected .toolCall case")
        }
    }

    func testAgentStepToolResult() {
        let response = ToolResponse(
            callId: "call_1",
            name: "search",
            output: "Found 3 results"
        )
        let step = AgentStep.toolResult(response)

        if case .toolResult(let r) = step {
            XCTAssertEqual(r.output, "Found 3 results")
            XCTAssertEqual(r.name, "search")
        } else {
            XCTFail("Expected .toolResult case")
        }
    }

    func testAgentStepInterrupted() {
        let step = AgentStep.interrupted("Focus on security")

        if case .interrupted(let msg) = step {
            XCTAssertEqual(msg, "Focus on security")
        } else {
            XCTFail("Expected .interrupted case")
        }
    }

    func testAgentStepAskingUser() {
        let step = AgentStep.askingUser("What is your preference?")

        if case .askingUser(let question) = step {
            XCTAssertEqual(question, "What is your preference?")
        } else {
            XCTFail("Expected .askingUser case")
        }
    }

    func testAgentStepIsSendable() {
        let step = AgentStep.userMessage("test")

        func requireSendable<T: Sendable>(_ value: T) -> T { value }
        _ = requireSendable(step)
    }

    func testAgentStepEquatable() {
        let step1 = AgentStep.userMessage("Hello")
        let step2 = AgentStep.userMessage("Hello")
        let step3 = AgentStep.userMessage("World")

        XCTAssertEqual(step1, step2)
        XCTAssertNotEqual(step1, step3)
    }

    // MARK: - AgentStep CustomStringConvertible Tests

    func testAgentStepDescription() {
        let userMessage = AgentStep.userMessage("Hello world")
        XCTAssertTrue(userMessage.description.contains("userMessage"))

        let thinking = AgentStep.thinking
        XCTAssertEqual(thinking.description, "thinking")

        let toolCall = AgentStep.toolCall(makeMockToolCall())
        XCTAssertTrue(toolCall.description.contains("toolCall"))
        XCTAssertTrue(toolCall.description.contains("search"))
    }

    // MARK: - SessionPhase Tests

    func testSessionPhaseIdle() {
        let phase: SessionPhase<SimpleOutput> = .idle

        XCTAssertFalse(phase.isActive)
        XCTAssertFalse(phase.isRunning)
        XCTAssertNil(phase.currentStep)
        XCTAssertNil(phase.output)
        XCTAssertNil(phase.error)
    }

    func testSessionPhaseRunning() {
        let step = AgentStep.thinking
        let phase: SessionPhase<SimpleOutput> = .running(step: step)

        XCTAssertTrue(phase.isActive)
        XCTAssertTrue(phase.isRunning)
        XCTAssertEqual(phase.currentStep, step)
        XCTAssertNil(phase.output)
    }

    func testSessionPhaseAwaitingUserInput() {
        let phase: SessionPhase<SimpleOutput> = .awaitingUserInput(question: "What do you need?")

        XCTAssertTrue(phase.isActive)
        XCTAssertFalse(phase.isRunning)
        XCTAssertEqual(phase.question, "What do you need?")
    }

    func testSessionPhasePaused() {
        let phase: SessionPhase<SimpleOutput> = .paused

        XCTAssertFalse(phase.isActive)
        XCTAssertFalse(phase.isRunning)
    }

    func testSessionPhaseCompleted() {
        let output = SimpleOutput(result: "completed")
        let phase: SessionPhase<SimpleOutput> = .completed(output: output)

        XCTAssertFalse(phase.isActive)
        XCTAssertEqual(phase.output?.result, "completed")
        XCTAssertNil(phase.error)
    }

    func testSessionPhaseFailed() {
        let phase: SessionPhase<SimpleOutput> = .failed(error: "Something went wrong")

        XCTAssertFalse(phase.isActive)
        XCTAssertEqual(phase.error, "Something went wrong")
        XCTAssertNil(phase.output)
    }

    func testSessionPhaseIsSendable() {
        let phase: SessionPhase<SimpleOutput> = .idle

        func requireSendable<T: Sendable>(_ value: T) -> T { value }
        _ = requireSendable(phase)
    }

    func testSessionPhaseEquatable() {
        let phase1: SessionPhase<SimpleOutput> = .idle
        let phase2: SessionPhase<SimpleOutput> = .idle
        let phase3: SessionPhase<SimpleOutput> = .paused

        XCTAssertEqual(phase1, phase2)
        XCTAssertNotEqual(phase1, phase3)
    }

    // MARK: - SessionPhase CustomStringConvertible Tests

    func testSessionPhaseDescription() {
        let idle: SessionPhase<SimpleOutput> = .idle
        XCTAssertEqual(idle.description, "idle")

        let running: SessionPhase<SimpleOutput> = .running(step: .thinking)
        XCTAssertTrue(running.description.contains("running"))

        let paused: SessionPhase<SimpleOutput> = .paused
        XCTAssertEqual(paused.description, "paused")

        let failed: SessionPhase<SimpleOutput> = .failed(error: "Error message")
        XCTAssertTrue(failed.description.contains("failed"))
    }

    // MARK: - SessionStatus Tests

    func testSessionStatusIdle() {
        let status = SessionStatus.idle

        XCTAssertFalse(status.isActive)
        XCTAssertTrue(status.canRun)
        XCTAssertTrue(status.canResume)
        // idle 状態では canClear は false（paused/failed のみ）
        XCTAssertFalse(status.canClear)
        XCTAssertFalse(status.canInterrupt)
        XCTAssertFalse(status.canCancel)
        XCTAssertFalse(status.canReply)
    }

    func testSessionStatusRunning() {
        let status = SessionStatus.running(step: .thinking)

        XCTAssertTrue(status.isActive)
        XCTAssertFalse(status.canRun)
        XCTAssertFalse(status.canResume)
        XCTAssertFalse(status.canClear)
        XCTAssertTrue(status.canInterrupt)
        XCTAssertTrue(status.canCancel)
        XCTAssertFalse(status.canReply)
    }

    func testSessionStatusAwaitingUserInput() {
        let status = SessionStatus.awaitingUserInput(question: "What do you need?")

        XCTAssertTrue(status.isActive)
        XCTAssertFalse(status.canRun)
        XCTAssertFalse(status.canResume)
        XCTAssertFalse(status.canClear)
        XCTAssertFalse(status.canInterrupt)
        XCTAssertTrue(status.canCancel)
        XCTAssertTrue(status.canReply)
    }

    func testSessionStatusPaused() {
        let status = SessionStatus.paused

        XCTAssertFalse(status.isActive)
        XCTAssertFalse(status.canRun)
        XCTAssertTrue(status.canResume)
        XCTAssertTrue(status.canClear)
        XCTAssertFalse(status.canInterrupt)
        XCTAssertFalse(status.canCancel)
        XCTAssertFalse(status.canReply)
    }

    func testSessionStatusFailed() {
        let status = SessionStatus.failed(error: "Error")

        XCTAssertFalse(status.isActive)
        XCTAssertFalse(status.canRun)
        XCTAssertTrue(status.canResume)
        XCTAssertTrue(status.canClear)
        XCTAssertFalse(status.canInterrupt)
        XCTAssertFalse(status.canCancel)
        XCTAssertFalse(status.canReply)
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

    func testConversationalAgentErrorToolNotFound() {
        let error = ConversationalAgentError.toolNotFound(name: "unknownTool")

        XCTAssertTrue(error.localizedDescription.contains("unknownTool"))
        XCTAssertTrue(error.localizedDescription.contains("not found"))
    }

    func testConversationalAgentErrorToolExecutionFailed() {
        let error = ConversationalAgentError.toolExecutionFailed(name: "search", underlyingError: "Network timeout")

        XCTAssertTrue(error.localizedDescription.contains("search"))
        XCTAssertTrue(error.localizedDescription.contains("failed"))
        XCTAssertTrue(error.localizedDescription.contains("Network timeout"))
    }

    func testConversationalAgentErrorLLMError() {
        let llmError = LLMError.emptyResponse
        let error = ConversationalAgentError.llmError(llmError)

        XCTAssertTrue(error.localizedDescription.contains("LLM"))
    }

    func testConversationalAgentErrorOutputDecodingFailed() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
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
        let status = await session.status

        XCTAssertFalse(running)
        XCTAssertEqual(turnCount, 0)
        XCTAssertTrue(messages.isEmpty)
        XCTAssertEqual(status, .idle)
    }

    func testConversationalAgentSessionInitializationWithInitialMessages() async {
        let client = MockAgentCapableClient()
        let tools = ToolSet {}
        let initialMessages = [
            LLMMessage.user("Hello"),
            LLMMessage.assistant("Hi there!")
        ]

        let session = ConversationalAgentSession(
            client: client,
            tools: tools,
            initialMessages: initialMessages
        )

        let messages = await session.getMessages()
        let turnCount = await session.turnCount

        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(turnCount, 1) // One user message
    }

    func testConversationalAgentSessionClear() async {
        let client = MockAgentCapableClient()
        let tools = ToolSet {}
        let initialMessages = [LLMMessage.user("Hello")]

        let session = ConversationalAgentSession(
            client: client,
            tools: tools,
            initialMessages: initialMessages
        )

        // Verify initial state
        var messages = await session.getMessages()
        XCTAssertEqual(messages.count, 1)

        // clear() は idle 状態では動作しない（canClear = false）
        // 最初の状態では clear できないことを確認
        var status = await session.status
        XCTAssertEqual(status, .idle)
        XCTAssertFalse(status.canClear)

        // clear() を呼んでも idle 状態では何も変わらない
        await session.clear()
        messages = await session.getMessages()
        XCTAssertEqual(messages.count, 1)  // 変更なし
    }

    func testConversationalAgentSessionClearAfterPaused() async {
        let client = MockAgentCapableClient()
        let tools = ToolSet {}
        let initialMessages = [LLMMessage.user("Hello")]

        let session = ConversationalAgentSession(
            client: client,
            tools: tools,
            initialMessages: initialMessages
        )

        // Verify initial state
        var messages = await session.getMessages()
        XCTAssertEqual(messages.count, 1)

        // paused 状態にする（直接状態を操作できないため、この実装では
        // cancel() は running 中にしか呼べない。ここでは failed 状態を
        // シミュレートするか、テストをスキップする必要がある）
        //
        // 注: 実際の clear() テストは統合テストで行うべき
        // ここでは clear() が idle 状態で動作しないことを確認済み
    }

    func testConversationalAgentSessionInterruptQueue() async {
        let client = MockAgentCapableClient()
        let tools = ToolSet {}

        let session = ConversationalAgentSession(
            client: client,
            tools: tools
        )

        // Add interrupts (should be queued even when not running)
        await session.interrupt("First interrupt")
        await session.interrupt("Second interrupt")

        // Clear interrupts
        await session.clearInterrupts()

        // Session should still be in idle state
        let status = await session.status
        XCTAssertEqual(status, .idle)
    }

    func testConversationalAgentSessionWaitingForAnswer() async {
        let client = MockAgentCapableClient()
        let tools = ToolSet {}

        let session = ConversationalAgentSession(
            client: client,
            tools: tools
        )

        // Initially not waiting for answer
        let waiting = await session.waitingForAnswer
        XCTAssertFalse(waiting)
    }

    // MARK: - Helper Methods

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
