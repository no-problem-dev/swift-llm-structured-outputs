import Foundation
import LLMClient
import LLMTool
import LLMAgent

// MARK: - LoopPhase

/// 会話エージェントループのフェーズ
private enum LoopPhase: Sendable {
    /// ツール使用フェーズ
    ///
    /// LLM はツールを呼び出すか、テキスト応答を返すことができます。
    case toolUse

    /// 最終出力フェーズ
    ///
    /// ツール呼び出しが完了し、構造化出力を要求するフェーズです。
    /// リトライ回数を追跡します。
    case finalOutput(retryCount: Int)
}

// MARK: - FinalOutputConstants

/// 最終出力フェーズの定数
private enum FinalOutputConstants {
    /// 最終出力デコードの最大リトライ回数
    static let maxDecodeRetries: Int = 2

    /// 最終出力要求メッセージ
    ///
    /// 構造化出力を要求するためのユーザーメッセージです。
    static let requestMessage = "Please provide your final response in the required JSON format."
}

// MARK: - ConversationalAgentSession

/// `ConversationalAgentSessionProtocol` の標準実装
///
/// Actor として実装され、スレッドセーフな会話型エージェントセッションを提供します。
public actor ConversationalAgentSession<Client: AgentCapableClient>: ConversationalAgentSessionProtocol
    where Client.Model: Sendable
{
    // MARK: - Properties

    private let client: Client
    private var messages: [LLMMessage] = []
    private let systemPrompt: Prompt?
    private let tools: ToolSet
    private let configuration: AgentConfiguration
    private var interruptQueue: [String] = []
    private var _isRunning: Bool = false
    private let eventContinuation: AsyncStream<ConversationalAgentEvent>.Continuation

    public nonisolated let eventStream: AsyncStream<ConversationalAgentEvent>

    // MARK: - Initialization

    public init(
        client: Client,
        systemPrompt: Prompt? = nil,
        tools: ToolSet,
        configuration: AgentConfiguration = .default
    ) {
        self.client = client
        self.systemPrompt = systemPrompt
        self.tools = tools
        self.configuration = configuration

        let (stream, continuation) = AsyncStream<ConversationalAgentEvent>.makeStream()
        self.eventStream = stream
        self.eventContinuation = continuation
    }

    deinit {
        eventContinuation.finish()
    }

    // MARK: - Protocol Conformance: Properties

    public var running: Bool {
        _isRunning
    }

    public var turnCount: Int {
        messages.filter { $0.role == .user }.count
    }

    // MARK: - Protocol Conformance: Interrupt API

    public func interrupt(_ message: String) {
        interruptQueue.append(message)
        eventContinuation.yield(.interruptQueued(message))
    }

    public func clearInterrupts() {
        interruptQueue.removeAll()
    }

    // MARK: - Protocol Conformance: Session Management

    public func getMessages() -> [LLMMessage] {
        messages
    }

    public func clear() {
        messages.removeAll()
        interruptQueue.removeAll()
        eventContinuation.yield(.cleared)
    }

    // MARK: - Protocol Conformance: Core API

    public func run<Output: StructuredProtocol>(
        _ userMessage: String,
        model: Client.Model,
        outputType: Output.Type = Output.self
    ) -> AsyncThrowingStream<ConversationalAgentStep<Output>, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.executeLoop(
                    userMessage: userMessage,
                    model: model,
                    outputType: Output.self,
                    continuation: continuation
                )
            }
        }
    }

    // MARK: - Internal Loop

    private func executeLoop<Output: StructuredProtocol>(
        userMessage: String,
        model: Client.Model,
        outputType: Output.Type,
        continuation: AsyncThrowingStream<ConversationalAgentStep<Output>, Error>.Continuation
    ) async {
        guard !_isRunning else {
            let error = ConversationalAgentError.sessionAlreadyRunning
            eventContinuation.yield(.error(error))
            continuation.finish(throwing: error)
            return
        }

        _isRunning = true
        eventContinuation.yield(.sessionStarted)
        defer {
            _isRunning = false
            eventContinuation.yield(.sessionCompleted)
        }

        let userMsg = LLMMessage.user(userMessage)
        messages.append(userMsg)
        eventContinuation.yield(.userMessage(userMsg))
        continuation.yield(.userMessage(userMessage))

        var step = 0
        let maxSteps = configuration.maxSteps
        var phase: LoopPhase = .toolUse

        do {
            while step < maxSteps {
                step += 1

                // 割り込みチェックポイント（toolUse フェーズのみ）
                if case .toolUse = phase, !interruptQueue.isEmpty {
                    for interruptMsg in interruptQueue {
                        let msg = LLMMessage.user(interruptMsg)
                        messages.append(msg)
                        eventContinuation.yield(.userMessage(msg))
                        eventContinuation.yield(.interruptProcessed(interruptMsg))
                        continuation.yield(.interrupted(interruptMsg))
                    }
                    interruptQueue.removeAll()
                }

                // フェーズに応じて LLM 呼び出し
                let response: LLMResponse
                do {
                    switch phase {
                    case .toolUse:
                        // ツール使用フェーズ: ツール有効、構造化出力なし
                        response = try await client.executeAgentStep(
                            messages: messages,
                            model: model,
                            systemPrompt: systemPrompt,
                            tools: tools,
                            toolChoice: tools.isEmpty ? nil : .auto,
                            responseSchema: nil
                        )

                    case .finalOutput:
                        // 最終出力フェーズ: ツール無効、構造化出力要求
                        response = try await client.executeAgentStep(
                            messages: messages,
                            model: model,
                            systemPrompt: systemPrompt,
                            tools: ToolSet {},
                            toolChoice: nil,
                            responseSchema: Output.jsonSchema
                        )
                    }
                } catch let error as LLMError {
                    throw ConversationalAgentError.llmError(error)
                }

                addAssistantResponse(response)
                continuation.yield(.thinking(response))

                // フェーズに応じた処理
                switch phase {
                case .toolUse:
                    let toolCalls = extractToolCalls(from: response)

                    if toolCalls.isEmpty {
                        // ツール呼び出しがない → 最終出力フェーズへ移行
                        if !tools.isEmpty {
                            // ツールがある場合は finalOutput フェーズへ移行
                            phase = .finalOutput(retryCount: 0)
                            addFinalOutputRequest()
                            // ループ継続（次のイテレーションで finalOutput フェーズの処理）
                            continue
                        } else {
                            // ツールがない場合は直接デコードを試行
                            if let output = try? decodeOutput(response, as: Output.self) {
                                let assistantMsg = LLMMessage(role: .assistant, content: String(describing: output))
                                eventContinuation.yield(.assistantMessage(assistantMsg))
                                continuation.yield(.finalResponse(output))
                                continuation.finish()
                                return
                            } else {
                                let text = extractTextContent(from: response)
                                continuation.yield(.textResponse(text))
                                continuation.finish()
                                return
                            }
                        }
                    }

                    // ツール呼び出しがある場合
                    if configuration.autoExecuteTools {
                        var toolResults: [ToolResponse] = []

                        for call in toolCalls {
                            continuation.yield(.toolCall(call))

                            let result = await executeToolSafely(call)
                            toolResults.append(result)
                            continuation.yield(.toolResult(result))
                        }

                        addToolResults(toolResults)
                    } else {
                        continuation.finish()
                        return
                    }

                case .finalOutput(let retryCount):
                    // 構造化出力のデコードを試行
                    do {
                        let output = try decodeOutput(response, as: Output.self)
                        let assistantMsg = LLMMessage(role: .assistant, content: String(describing: output))
                        eventContinuation.yield(.assistantMessage(assistantMsg))
                        continuation.yield(.finalResponse(output))
                        continuation.finish()
                        return
                    } catch {
                        // デコード失敗 → リトライ
                        let newRetryCount = retryCount + 1
                        if newRetryCount >= FinalOutputConstants.maxDecodeRetries {
                            throw ConversationalAgentError.outputDecodingFailed(error)
                        }
                        phase = .finalOutput(retryCount: newRetryCount)
                        addFinalOutputRequest()
                        // ループ継続（リトライ）
                        continue
                    }
                }
            }

            let error = ConversationalAgentError.maxStepsExceeded(steps: maxSteps)
            eventContinuation.yield(.error(error))
            continuation.finish(throwing: error)

        } catch let error as ConversationalAgentError {
            eventContinuation.yield(.error(error))
            continuation.finish(throwing: error)
        } catch {
            let wrappedError = ConversationalAgentError.invalidState(error.localizedDescription)
            eventContinuation.yield(.error(wrappedError))
            continuation.finish(throwing: wrappedError)
        }
    }

    // MARK: - Private Helpers

    private func addAssistantResponse(_ response: LLMResponse) {
        var contents: [LLMMessage.MessageContent] = []

        for block in response.content {
            switch block {
            case .text(let text):
                if !text.isEmpty {
                    contents.append(.text(text))
                }
            case .toolUse(let id, let name, let input):
                contents.append(.toolUse(id: id, name: name, input: input))
            }
        }

        if !contents.isEmpty {
            messages.append(LLMMessage(role: .assistant, contents: contents))
        }
    }

    private func addToolResults(_ results: [ToolResponse]) {
        guard !results.isEmpty else { return }

        let contents = results.map { result in
            LLMMessage.MessageContent.toolResult(
                toolCallId: result.callId,
                name: result.name,
                content: result.output,
                isError: result.isError
            )
        }
        messages.append(LLMMessage(role: .user, contents: contents))
    }

    private func extractToolCalls(from response: LLMResponse) -> [ToolCall] {
        response.content.compactMap { block in
            guard case .toolUse(let id, let name, let input) = block else {
                return nil
            }
            return ToolCall(id: id, name: name, arguments: input)
        }
    }

    private func executeToolSafely(_ call: ToolCall) async -> ToolResponse {
        do {
            let result = try await tools.execute(toolNamed: call.name, with: call.arguments)
            return ToolResponse(
                callId: call.id,
                name: call.name,
                output: result.stringValue,
                isError: result.isError
            )
        } catch {
            return ToolResponse(
                callId: call.id,
                name: call.name,
                output: "Error: \(error.localizedDescription)",
                isError: true
            )
        }
    }

    private func decodeOutput<Output: StructuredProtocol>(
        _ response: LLMResponse,
        as type: Output.Type
    ) throws -> Output {
        let text = extractTextContent(from: response)
        guard !text.isEmpty else {
            throw ConversationalAgentError.outputDecodingFailed(
                NSError(domain: "ConversationalAgentSession", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Response contains no text"
                ])
            )
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Output.self, from: Data(text.utf8))
    }

    private func extractTextContent(from response: LLMResponse) -> String {
        response.content.compactMap { block -> String? in
            if case .text(let value) = block { return value }
            return nil
        }.joined()
    }

    // MARK: - Final Output Helpers

    /// 最終出力要求メッセージを追加
    private func addFinalOutputRequest() {
        let message = LLMMessage.user(FinalOutputConstants.requestMessage)
        messages.append(message)
    }
}
