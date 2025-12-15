import Foundation

// MARK: - AgentLoopRunner

/// エージェントループの実行を管理する Actor
internal actor AgentLoopRunner<Client: AgentCapableClient, Output: StructuredProtocol>
    where Client.Model: Sendable
{
    private let client: Client
    private let model: Client.Model
    private let context: AgentContext
    private let terminationPolicy: any AgentTerminationPolicy
    private let stateManager: AgentLoopStateManager

    private var pendingEvents: [PendingEvent] = []
    private var phase: LoopPhase = .toolUse
    private let maxDecodeRetries: Int = 2
    private var isCancelled: Bool = false

    init(client: Client, model: Client.Model, context: AgentContext) {
        self.client = client
        self.model = model
        self.context = context

        let config = context.configurationSync
        self.stateManager = AgentLoopStateManager(configuration: config)
        self.terminationPolicy = TerminationPolicyFactory.make(from: config)
    }

    // MARK: - Public Interface

    func nextStep() async throws -> AgentStep<Output>? {
        if isCancelled {
            return nil
        }

        if let event = consumePendingEvent() {
            return event
        }

        if phase == .completed {
            return nil
        }

        if await stateManager.isAtStepLimit {
            throw AgentError.maxStepsExceeded(steps: stateManager.maxSteps)
        }

        try await stateManager.incrementStep()

        let response = try await sendRequest()
        await context.addAssistantResponse(response)

        let decision = await terminationPolicy.shouldTerminate(
            response: response,
            context: stateManager
        )

        return try await handleDecision(decision, response: response)
    }

    func currentPhase() -> AgentExecutionPhase {
        phase.toPublic
    }

    func cancel() {
        isCancelled = true
        phase = .completed
    }

    // MARK: - Decision Handling

    private func handleDecision(
        _ decision: TerminationDecision,
        response: LLMResponse
    ) async throws -> AgentStep<Output>? {
        switch decision {
        case .continueWithTools(let calls):
            return try await processToolCalls(calls)

        case .continueWithThinking:
            return .thinking(response)

        case .terminateWithOutput(let text):
            return try await decodeFinalOutput(text, response: response)

        case .terminateImmediately(let reason):
            return handleImmediateTermination(reason)
        }
    }

    private func processToolCalls(_ calls: [ToolCallInfo]) async throws -> AgentStep<Output>? {
        let config = await context.getConfiguration()

        if config.autoExecuteTools {
            var results: [ToolResultInfo] = []

            for call in calls {
                await stateManager.recordToolCall(call)
                pendingEvents.append(.toolCall(call))

                let result = await executeToolSafely(call)
                results.append(result)
                pendingEvents.append(.toolResult(result))
            }

            await context.addToolResults(results)
            return consumePendingEvent()
        } else {
            phase = .completed
            await context.markCompleted()
            return nil
        }
    }

    private func decodeFinalOutput(_ text: String, response: LLMResponse) async throws -> AgentStep<Output>? {
        switch phase {
        case .toolUse:
            let tools = await context.getTools()
            if !tools.isEmpty {
                phase = .finalOutput(retryCount: 0)
                await context.addFinalOutputRequest()
                return .thinking(response)
            }
            return try decodeAndComplete(text)

        case .finalOutput(let retryCount):
            do {
                return try decodeAndComplete(text)
            } catch {
                let newRetryCount = retryCount + 1
                if newRetryCount >= maxDecodeRetries {
                    throw AgentError.outputDecodingFailed(error)
                }
                phase = .finalOutput(retryCount: newRetryCount)
                await context.addFinalOutputRequest()
                return .thinking(response)
            }

        case .completed:
            return nil
        }
    }

    private func decodeAndComplete(_ text: String) throws -> AgentStep<Output> {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let output = try decoder.decode(Output.self, from: Data(text.utf8))
        phase = .completed
        Task { await context.markCompleted() }
        return .finalResponse(output)
    }

    private func handleImmediateTermination(_ reason: TerminationReason) -> AgentStep<Output>? {
        phase = .completed
        Task { await context.markCompleted() }

        switch reason {
        case .completed, .emptyResponse, .maxStepsReached, .unexpectedStopReason:
            return nil

        case .duplicateToolCallDetected(let toolName, let count):
            #if DEBUG
            print("[AgentLoop] Duplicate tool call detected: \(toolName) called \(count) times with same input")
            #endif
            return nil

        case .maxToolCallsPerToolReached(let toolName, let count):
            #if DEBUG
            print("[AgentLoop] Tool call limit reached: \(toolName) called \(count) times total")
            #endif
            return nil
        }
    }

    // MARK: - Helper Methods

    private func consumePendingEvent() -> AgentStep<Output>? {
        guard !pendingEvents.isEmpty else { return nil }

        let event = pendingEvents.removeFirst()
        switch event {
        case .toolCall(let info):
            return .toolCall(info)
        case .toolResult(let info):
            return .toolResult(info)
        }
    }

    private func sendRequest() async throws -> LLMResponse {
        let messages = await context.getMessages()
        let systemPrompt = await context.getSystemPrompt()

        switch phase {
        case .toolUse:
            let tools = await context.getTools()
            let shouldRequestStructuredOutput = tools.isEmpty
            let responseSchema: JSONSchema? = shouldRequestStructuredOutput ? Output.jsonSchema : nil

            do {
                return try await client.executeAgentStep(
                    messages: messages,
                    model: model,
                    systemPrompt: systemPrompt,
                    tools: tools,
                    toolChoice: tools.isEmpty ? nil : .auto,
                    responseSchema: responseSchema
                )
            } catch let error as LLMError {
                throw AgentError.llmError(error)
            }

        case .finalOutput:
            do {
                return try await client.executeAgentStep(
                    messages: messages,
                    model: model,
                    systemPrompt: systemPrompt,
                    tools: ToolSet {},
                    toolChoice: nil,
                    responseSchema: Output.jsonSchema
                )
            } catch let error as LLMError {
                throw AgentError.llmError(error)
            }

        case .completed:
            throw AgentError.invalidState("sendRequest called in completed phase")
        }
    }

    private func executeToolSafely(_ call: ToolCallInfo) async -> ToolResultInfo {
        do {
            let result = try await context.executeTool(named: call.name, with: call.input)
            return ToolResultInfo(
                toolCallId: call.id,
                name: call.name,
                content: result.stringValue,
                isError: result.isError
            )
        } catch {
            return ToolResultInfo(
                toolCallId: call.id,
                name: call.name,
                content: "Error: \(error.localizedDescription)",
                isError: true
            )
        }
    }
}
