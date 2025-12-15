import XCTest
@testable import LLMStructuredOutputs

final class AgentTests: XCTestCase {

    // MARK: - AgentConfiguration Tests

    func testAgentConfigurationDefault() {
        let config = AgentConfiguration.default

        XCTAssertEqual(config.maxSteps, 10)
        XCTAssertTrue(config.autoExecuteTools)
        XCTAssertEqual(config.maxDuplicateToolCalls, 2)
    }

    func testAgentConfigurationCustom() {
        let config = AgentConfiguration(
            maxSteps: 5,
            autoExecuteTools: false,
            maxDuplicateToolCalls: 3
        )

        XCTAssertEqual(config.maxSteps, 5)
        XCTAssertFalse(config.autoExecuteTools)
        XCTAssertEqual(config.maxDuplicateToolCalls, 3)
    }

    func testAgentConfigurationIsSendable() {
        let config = AgentConfiguration.default

        func requireSendable<T: Sendable>(_ value: T) -> T { value }
        _ = requireSendable(config)
    }

    // MARK: - ToolCall Tests

    func testToolCallInit() {
        let arguments = "{\"location\":\"Tokyo\"}".data(using: .utf8)!
        let call = ToolCall(id: "call_123", name: "get_weather", arguments: arguments)

        XCTAssertEqual(call.id, "call_123")
        XCTAssertEqual(call.name, "get_weather")
        XCTAssertEqual(call.arguments, arguments)
    }

    func testToolCallDecodeArguments() throws {
        struct Args: Decodable, Equatable {
            let location: String
        }

        let arguments = "{\"location\":\"Tokyo\"}".data(using: .utf8)!
        let call = ToolCall(id: "call_123", name: "get_weather", arguments: arguments)

        let args = try call.decodeArguments(as: Args.self)
        XCTAssertEqual(args.location, "Tokyo")
    }

    func testToolCallDecodeArgumentsFailure() {
        struct Args: Decodable {
            let invalidField: Int
        }

        let arguments = "{\"location\":\"Tokyo\"}".data(using: .utf8)!
        let call = ToolCall(id: "call_123", name: "get_weather", arguments: arguments)

        XCTAssertThrowsError(try call.decodeArguments(as: Args.self))
    }

    func testToolCallIsSendable() {
        let arguments = "{}".data(using: .utf8)!
        let call = ToolCall(id: "id", name: "name", arguments: arguments)

        func requireSendable<T: Sendable>(_ value: T) -> T { value }
        _ = requireSendable(call)
    }

    // MARK: - ToolResponse Tests

    func testToolResponseInit() {
        let response = ToolResponse(
            callId: "call_123",
            name: "get_weather",
            output: "晴れ、25°C",
            isError: false
        )

        XCTAssertEqual(response.callId, "call_123")
        XCTAssertEqual(response.name, "get_weather")
        XCTAssertEqual(response.output, "晴れ、25°C")
        XCTAssertFalse(response.isError)
    }

    func testToolResponseError() {
        let response = ToolResponse(
            callId: "call_123",
            name: "get_weather",
            output: "API error",
            isError: true
        )

        XCTAssertTrue(response.isError)
    }

    func testToolResponseDefaultIsError() {
        let response = ToolResponse(
            callId: "call_123",
            name: "get_weather",
            output: "晴れ"
        )

        XCTAssertFalse(response.isError)
    }

    func testToolResponseIsSendable() {
        let response = ToolResponse(
            callId: "id",
            name: "name",
            output: "content"
        )

        func requireSendable<T: Sendable>(_ value: T) -> T { value }
        _ = requireSendable(response)
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
        let arguments = "{}".data(using: .utf8)!
        let call = ToolCall(id: "call_1", name: "tool", arguments: arguments)
        let step: AgentStep<SimpleOutput> = .toolCall(call)

        if case .toolCall(let c) = step {
            XCTAssertEqual(c.name, "tool")
        } else {
            XCTFail("Expected .toolCall case")
        }
    }

    func testAgentStepToolResult() {
        let response = ToolResponse(
            callId: "call_1",
            name: "tool",
            output: "result"
        )
        let step: AgentStep<SimpleOutput> = .toolResult(response)

        if case .toolResult(let r) = step {
            XCTAssertEqual(r.output, "result")
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
            ToolResponse(callId: "call_1", name: "tool1", output: "result1"),
            ToolResponse(callId: "call_2", name: "tool2", output: "result2", isError: true)
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

    // MARK: - AgentContext Configuration Tests

    func testAgentContextConfiguration() async {
        let tools = ToolSet {}
        let config = AgentConfiguration(maxSteps: 5, maxDuplicateToolCalls: 3)
        let context = AgentContext(
            initialPrompt: "test",
            tools: tools,
            configuration: config
        )

        // getConfiguration() で設定を取得
        let retrievedConfig = await context.getConfiguration()
        XCTAssertEqual(retrievedConfig.maxSteps, 5)
        XCTAssertEqual(retrievedConfig.maxDuplicateToolCalls, 3)
    }

    // MARK: - TerminationDecision Tests

    func testTerminationDecisionContinueWithTools() {
        let arguments = "{}".data(using: .utf8)!
        let call = ToolCall(id: "call_1", name: "tool", arguments: arguments)
        let decision = TerminationDecision.continueWithTools([call])

        if case .continueWithTools(let calls) = decision {
            XCTAssertEqual(calls.count, 1)
            XCTAssertEqual(calls.first?.name, "tool")
        } else {
            XCTFail("Expected .continueWithTools")
        }
    }

    func testTerminationDecisionContinueWithThinking() {
        let decision = TerminationDecision.continueWithThinking

        if case .continueWithThinking = decision {
            // Success
        } else {
            XCTFail("Expected .continueWithThinking")
        }
    }

    func testTerminationDecisionTerminateWithOutput() {
        let decision = TerminationDecision.terminateWithOutput("{\"result\": \"done\"}")

        if case .terminateWithOutput(let text) = decision {
            XCTAssertTrue(text.contains("done"))
        } else {
            XCTFail("Expected .terminateWithOutput")
        }
    }

    func testTerminationDecisionTerminateImmediately() {
        let decision = TerminationDecision.terminateImmediately(.maxStepsReached(10))

        if case .terminateImmediately(let reason) = decision {
            XCTAssertEqual(reason, .maxStepsReached(10))
        } else {
            XCTFail("Expected .terminateImmediately")
        }
    }

    // MARK: - TerminationReason Tests

    func testTerminationReasonEquality() {
        XCTAssertEqual(TerminationReason.completed, TerminationReason.completed)
        XCTAssertEqual(TerminationReason.maxStepsReached(5), TerminationReason.maxStepsReached(5))
        XCTAssertNotEqual(TerminationReason.maxStepsReached(5), TerminationReason.maxStepsReached(10))
        XCTAssertEqual(
            TerminationReason.duplicateToolCallDetected(toolName: "search", count: 3),
            TerminationReason.duplicateToolCallDetected(toolName: "search", count: 3)
        )
        XCTAssertEqual(TerminationReason.emptyResponse, TerminationReason.emptyResponse)
    }

    // MARK: - StandardTerminationPolicy Tests

    func testStandardTerminationPolicyToolUse() async {
        let policy = StandardTerminationPolicy()
        let context = MockAgentLoopContext()

        let response = LLMResponse(
            content: [.toolUse(id: "call_1", name: "search", input: "{}".data(using: .utf8)!)],
            model: "test",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: .toolUse
        )

        let decision = await policy.shouldTerminate(response: response, context: context)

        if case .continueWithTools(let calls) = decision {
            XCTAssertEqual(calls.count, 1)
            XCTAssertEqual(calls.first?.name, "search")
        } else {
            XCTFail("Expected .continueWithTools, got \(decision)")
        }
    }

    func testStandardTerminationPolicyEndTurn() async {
        let policy = StandardTerminationPolicy()
        let context = MockAgentLoopContext()

        let response = LLMResponse(
            content: [.text("{\"result\": \"final answer\"}")],
            model: "test",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: .endTurn
        )

        let decision = await policy.shouldTerminate(response: response, context: context)

        if case .terminateWithOutput(let text) = decision {
            XCTAssertTrue(text.contains("final answer"))
        } else {
            XCTFail("Expected .terminateWithOutput, got \(decision)")
        }
    }

    func testStandardTerminationPolicyEndTurnEmpty() async {
        let policy = StandardTerminationPolicy()
        let context = MockAgentLoopContext()

        let response = LLMResponse(
            content: [],
            model: "test",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: .endTurn
        )

        let decision = await policy.shouldTerminate(response: response, context: context)

        if case .terminateImmediately(let reason) = decision {
            XCTAssertEqual(reason, .completed)
        } else {
            XCTFail("Expected .terminateImmediately(.completed), got \(decision)")
        }
    }

    func testStandardTerminationPolicyMaxTokens() async {
        let policy = StandardTerminationPolicy()
        let context = MockAgentLoopContext()

        let response = LLMResponse(
            content: [.text("partial output")],
            model: "test",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: .maxTokens
        )

        let decision = await policy.shouldTerminate(response: response, context: context)

        if case .terminateWithOutput(let text) = decision {
            XCTAssertEqual(text, "partial output")
        } else {
            XCTFail("Expected .terminateWithOutput, got \(decision)")
        }
    }

    func testStandardTerminationPolicyAtStepLimit() async {
        let policy = StandardTerminationPolicy()
        let context = MockAgentLoopContext(currentStep: 10, maxSteps: 10)

        let response = LLMResponse(
            content: [.text("some text")],
            model: "test",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: .endTurn
        )

        let decision = await policy.shouldTerminate(response: response, context: context)

        if case .terminateImmediately(let reason) = decision {
            XCTAssertEqual(reason, .maxStepsReached(10))
        } else {
            XCTFail("Expected .terminateImmediately(.maxStepsReached), got \(decision)")
        }
    }

    // MARK: - DuplicateDetectionPolicy Tests

    func testDuplicateDetectionPolicyNoDuplicates() async {
        let policy = DuplicateDetectionPolicy(maxDuplicates: 2)
        let context = MockAgentLoopContext()

        let response = LLMResponse(
            content: [.toolUse(id: "call_1", name: "search", input: "{\"q\":\"test\"}".data(using: .utf8)!)],
            model: "test",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: .toolUse
        )

        let decision = await policy.shouldTerminate(response: response, context: context)

        if case .continueWithTools(let calls) = decision {
            XCTAssertEqual(calls.count, 1)
        } else {
            XCTFail("Expected .continueWithTools, got \(decision)")
        }
    }

    func testDuplicateDetectionPolicyDetectsDuplicates() async {
        let policy = DuplicateDetectionPolicy(maxDuplicates: 2)
        let inputData = "{\"q\":\"test\"}".data(using: .utf8)!
        let context = MockAgentLoopContext(duplicateCount: 2)

        let response = LLMResponse(
            content: [.toolUse(id: "call_3", name: "search", input: inputData)],
            model: "test",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: .toolUse
        )

        let decision = await policy.shouldTerminate(response: response, context: context)

        if case .terminateImmediately(let reason) = decision {
            if case .duplicateToolCallDetected(let toolName, let count) = reason {
                XCTAssertEqual(toolName, "search")
                XCTAssertEqual(count, 3)  // 2 existing + 1 current
            } else {
                XCTFail("Expected .duplicateToolCallDetected, got \(reason)")
            }
        } else {
            XCTFail("Expected .terminateImmediately, got \(decision)")
        }
    }

    // MARK: - AgentLoopStateManager Tests

    func testAgentLoopStateManagerInitialization() async {
        let manager = AgentLoopStateManager(maxSteps: 5)

        let currentStep = await manager.currentStep
        let maxSteps = await manager.maxSteps
        let isAtLimit = await manager.isAtStepLimit

        XCTAssertEqual(currentStep, 0)
        XCTAssertEqual(maxSteps, 5)
        XCTAssertFalse(isAtLimit)
    }

    func testAgentLoopStateManagerIncrementStep() async throws {
        let manager = AgentLoopStateManager(maxSteps: 3)

        let step1 = try await manager.incrementStep()
        XCTAssertEqual(step1, 1)

        let step2 = try await manager.incrementStep()
        XCTAssertEqual(step2, 2)

        let step3 = try await manager.incrementStep()
        XCTAssertEqual(step3, 3)

        // 最大ステップを超えるとエラー
        do {
            _ = try await manager.incrementStep()
            XCTFail("Should throw AgentError.maxStepsExceeded")
        } catch let error as AgentError {
            if case .maxStepsExceeded(let steps) = error {
                XCTAssertEqual(steps, 3)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testAgentLoopStateManagerRecordToolCall() async {
        let manager = AgentLoopStateManager(maxSteps: 10)
        let arguments = "{\"q\":\"test\"}".data(using: .utf8)!
        let call = ToolCall(id: "call_1", name: "search", arguments: arguments)

        await manager.recordToolCall(call)

        let count = await manager.countToolCalls(named: "search")
        XCTAssertEqual(count, 1)

        // 同じ呼び出しをもう一度
        await manager.recordToolCall(call)

        let count2 = await manager.countToolCalls(named: "search")
        XCTAssertEqual(count2, 2)

        // 重複カウント
        let duplicateCount = await manager.countDuplicateToolCalls(
            name: "search",
            inputHash: arguments.hashValue
        )
        XCTAssertEqual(duplicateCount, 2)
    }

    func testAgentLoopStateManagerSnapshot() async throws {
        let manager = AgentLoopStateManager(maxSteps: 5)
        let arguments = "{\"q\":\"test\"}".data(using: .utf8)!
        let call = ToolCall(id: "call_1", name: "search", arguments: arguments)

        _ = try await manager.incrementStep()
        await manager.recordToolCall(call)

        let snapshot = await manager.snapshot()

        XCTAssertEqual(snapshot.currentStep, 1)
        XCTAssertEqual(snapshot.maxSteps, 5)
        XCTAssertEqual(snapshot.remainingSteps, 4)
        XCTAssertFalse(snapshot.isAtLimit)
        XCTAssertEqual(snapshot.toolCallHistory.count, 1)
    }

    func testAgentLoopStateManagerCanContinue() async throws {
        let manager = AgentLoopStateManager(maxSteps: 2)

        var canContinue = await manager.canContinue()
        XCTAssertTrue(canContinue)

        _ = try await manager.incrementStep()
        canContinue = await manager.canContinue()
        XCTAssertTrue(canContinue)

        _ = try await manager.incrementStep()
        canContinue = await manager.canContinue()
        XCTAssertFalse(canContinue)
    }

    func testAgentLoopStateManagerReset() async throws {
        let manager = AgentLoopStateManager(maxSteps: 10)
        let arguments = "{\"q\":\"test\"}".data(using: .utf8)!
        let call = ToolCall(id: "call_1", name: "search", arguments: arguments)

        _ = try await manager.incrementStep()
        await manager.recordToolCall(call)
        await manager.markCompleted()

        // リセット前
        var step = await manager.currentStep
        var completed = await manager.isCompleted
        XCTAssertEqual(step, 1)
        XCTAssertTrue(completed)

        // リセット
        await manager.reset()

        step = await manager.currentStep
        completed = await manager.isCompleted
        let count = await manager.countToolCalls(named: "search")

        XCTAssertEqual(step, 0)
        XCTAssertFalse(completed)
        XCTAssertEqual(count, 0)
    }

    // MARK: - TerminationPolicyFactory Tests

    func testTerminationPolicyFactoryMakeDefault() async {
        let policy = TerminationPolicyFactory.makeDefault(maxDuplicates: 3)
        let context = MockAgentLoopContext()

        // ツール呼び出しで継続することを確認
        let response = LLMResponse(
            content: [.toolUse(id: "call_1", name: "tool", input: "{}".data(using: .utf8)!)],
            model: "test",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: .toolUse
        )

        let decision = await policy.shouldTerminate(response: response, context: context)

        if case .continueWithTools = decision {
            // Success - default policy allows tool calls
        } else {
            XCTFail("Expected .continueWithTools, got \(decision)")
        }
    }

    func testTerminationPolicyFactoryMakeStandard() async {
        let policy = TerminationPolicyFactory.makeStandard()
        let context = MockAgentLoopContext()

        let response = LLMResponse(
            content: [.text("final answer")],
            model: "test",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: .endTurn
        )

        let decision = await policy.shouldTerminate(response: response, context: context)

        if case .terminateWithOutput = decision {
            // Success
        } else {
            XCTFail("Expected .terminateWithOutput, got \(decision)")
        }
    }

    // MARK: - LLMResponse Extension Tests

    func testLLMResponseExtractToolCalls() {
        let response = LLMResponse(
            content: [
                .text("Let me search"),
                .toolUse(id: "call_1", name: "search", input: "{\"q\":\"test\"}".data(using: .utf8)!),
                .toolUse(id: "call_2", name: "calculate", input: "{\"x\":1}".data(using: .utf8)!)
            ],
            model: "test",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: .toolUse
        )

        let calls = response.extractToolCalls()

        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(calls[0].name, "search")
        XCTAssertEqual(calls[1].name, "calculate")
    }

    func testLLMResponseExtractTextContent() {
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

        let text = response.extractTextContent()

        XCTAssertEqual(text, "Hello World")
    }

    func testLLMResponseExtractTextContentEmpty() {
        let response = LLMResponse(
            content: [.toolUse(id: "call_1", name: "tool", input: Data())],
            model: "test",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: nil
        )

        let text = response.extractTextContent()

        XCTAssertNil(text)
    }

    // MARK: - ToolCallRecord Tests

    func testToolCallRecordFromToolCall() {
        let arguments = "{\"q\":\"test\"}".data(using: .utf8)!
        let call = ToolCall(id: "call_1", name: "search", arguments: arguments)

        let record = ToolCallRecord(from: call)

        XCTAssertEqual(record.name, "search")
        XCTAssertEqual(record.inputHash, arguments.hashValue)
    }

    func testToolCallRecordHashable() {
        let record1 = ToolCallRecord(name: "search", inputHash: 123)
        let record2 = ToolCallRecord(name: "search", inputHash: 123)
        let record3 = ToolCallRecord(name: "search", inputHash: 456)

        XCTAssertEqual(record1, record2)
        XCTAssertNotEqual(record1, record3)

        var set = Set<ToolCallRecord>()
        set.insert(record1)
        set.insert(record2)
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - AgentConfiguration maxToolCallsPerTool Tests

    func testAgentConfigurationDefaultHasMaxToolCallsPerTool() {
        let config = AgentConfiguration.default
        XCTAssertEqual(config.maxToolCallsPerTool, 5)
    }

    func testAgentConfigurationCustomMaxToolCallsPerTool() {
        let config = AgentConfiguration(maxToolCallsPerTool: 10)
        XCTAssertEqual(config.maxToolCallsPerTool, 10)
    }

    func testAgentConfigurationNilMaxToolCallsPerTool() {
        let config = AgentConfiguration(maxToolCallsPerTool: nil)
        XCTAssertNil(config.maxToolCallsPerTool)
    }

    // MARK: - DuplicateDetectionPolicy maxToolCallsPerTool Tests

    func testDuplicateDetectionPolicyDetectsMaxToolCalls() async {
        // 既に 5 回呼ばれている状態をシミュレート
        let context = MockAgentLoopContextWithTotalCalls(totalCallCount: 5)

        let policy = DuplicateDetectionPolicy(
            maxDuplicates: 10,  // 重複は許容
            maxToolCallsPerTool: 5  // 総呼び出し回数で制限
        )

        let response = LLMResponse(
            content: [.toolUse(id: "call_1", name: "search", input: "{}".data(using: .utf8)!)],
            model: "test",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: .toolUse
        )

        let decision = await policy.shouldTerminate(response: response, context: context)

        if case .terminateImmediately(let reason) = decision {
            if case .maxToolCallsPerToolReached(let toolName, _) = reason {
                XCTAssertEqual(toolName, "search")
            } else {
                XCTFail("Expected .maxToolCallsPerToolReached, got \(reason)")
            }
        } else {
            XCTFail("Expected .terminateImmediately, got \(decision)")
        }
    }

    func testDuplicateDetectionPolicyAllowsWithinLimit() async {
        // まだ 3 回しか呼ばれていない状態
        let context = MockAgentLoopContextWithTotalCalls(totalCallCount: 3)

        let policy = DuplicateDetectionPolicy(
            maxDuplicates: 10,
            maxToolCallsPerTool: 5
        )

        let response = LLMResponse(
            content: [.toolUse(id: "call_1", name: "search", input: "{}".data(using: .utf8)!)],
            model: "test",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: .toolUse
        )

        let decision = await policy.shouldTerminate(response: response, context: context)

        if case .continueWithTools = decision {
            // Success - within limit
        } else {
            XCTFail("Expected .continueWithTools, got \(decision)")
        }
    }

    func testDuplicateDetectionPolicyNoLimitWhenNil() async {
        // 大量に呼ばれていても nil なら制限なし
        let context = MockAgentLoopContextWithTotalCalls(totalCallCount: 100)

        let policy = DuplicateDetectionPolicy(
            maxDuplicates: 10,
            maxToolCallsPerTool: nil  // 制限なし
        )

        let response = LLMResponse(
            content: [.toolUse(id: "call_1", name: "search", input: "{}".data(using: .utf8)!)],
            model: "test",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: .toolUse
        )

        let decision = await policy.shouldTerminate(response: response, context: context)

        if case .continueWithTools = decision {
            // Success - no limit
        } else {
            XCTFail("Expected .continueWithTools, got \(decision)")
        }
    }

    // MARK: - TerminationReason maxToolCallsPerToolReached Tests

    func testTerminationReasonMaxToolCallsPerToolReached() {
        let reason1 = TerminationReason.maxToolCallsPerToolReached(toolName: "search", count: 5)
        let reason2 = TerminationReason.maxToolCallsPerToolReached(toolName: "search", count: 5)
        let reason3 = TerminationReason.maxToolCallsPerToolReached(toolName: "fetch", count: 5)

        XCTAssertEqual(reason1, reason2)
        XCTAssertNotEqual(reason1, reason3)
    }

    // MARK: - TerminationPolicyFactory make(from:) Tests

    func testTerminationPolicyFactoryMakeFromConfiguration() async {
        let config = AgentConfiguration(
            maxSteps: 20,
            maxDuplicateToolCalls: 3,
            maxToolCallsPerTool: 8
        )

        let policy = TerminationPolicyFactory.make(from: config)
        let context = MockAgentLoopContextWithTotalCalls(totalCallCount: 8)

        let response = LLMResponse(
            content: [.toolUse(id: "call_1", name: "search", input: "{}".data(using: .utf8)!)],
            model: "test",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20),
            stopReason: .toolUse
        )

        let decision = await policy.shouldTerminate(response: response, context: context)

        // maxToolCallsPerTool = 8 で既に 8 回呼ばれているので終了
        if case .terminateImmediately(let reason) = decision {
            if case .maxToolCallsPerToolReached = reason {
                // Success
            } else {
                XCTFail("Expected .maxToolCallsPerToolReached, got \(reason)")
            }
        } else {
            XCTFail("Expected .terminateImmediately, got \(decision)")
        }
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

/// テスト用のモック AgentLoopContext
private actor MockAgentLoopContext: AgentLoopContext {
    let currentStep: Int
    let maxSteps: Int
    private let duplicateCount: Int

    init(currentStep: Int = 0, maxSteps: Int = 10, duplicateCount: Int = 0) {
        self.currentStep = currentStep
        self.maxSteps = maxSteps
        self.duplicateCount = duplicateCount
    }

    var isAtStepLimit: Bool {
        currentStep >= maxSteps
    }

    func countToolCalls(named name: String) -> Int {
        duplicateCount
    }

    func countDuplicateToolCalls(name: String, inputHash: Int) -> Int {
        duplicateCount
    }
}

/// 総呼び出し回数テスト用のモック AgentLoopContext
private actor MockAgentLoopContextWithTotalCalls: AgentLoopContext {
    let currentStep: Int
    let maxSteps: Int
    private let totalCallCount: Int
    private let duplicateCount: Int

    init(currentStep: Int = 0, maxSteps: Int = 10, totalCallCount: Int = 0, duplicateCount: Int = 0) {
        self.currentStep = currentStep
        self.maxSteps = maxSteps
        self.totalCallCount = totalCallCount
        self.duplicateCount = duplicateCount
    }

    var isAtStepLimit: Bool {
        currentStep >= maxSteps
    }

    func countToolCalls(named name: String) -> Int {
        totalCallCount
    }

    func countDuplicateToolCalls(name: String, inputHash: Int) -> Int {
        duplicateCount
    }
}
