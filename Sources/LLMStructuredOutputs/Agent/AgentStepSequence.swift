import Foundation

// MARK: - AgentStepSequence

/// エージェントループを AsyncSequence として提供
///
/// LLM クライアントと連携して、ツール呼び出しを含むエージェントループを
/// AsyncSequence として実行します。
///
/// ## 使用例
///
/// ```swift
/// let sequence = AgentStepSequence<AnthropicClient, WeatherResponse>(
///     client: client,
///     model: .sonnet,
///     context: context
/// )
///
/// for try await step in sequence {
///     switch step {
///     case .thinking(let response):
///         print("思考: \(response.textContent ?? "")")
///     case .toolCall(let info):
///         print("ツール呼び出し: \(info.name)")
///     case .toolResult(let info):
///         print("結果: \(info.content)")
///     case .finalResponse(let output):
///         print("最終出力: \(output)")
///     }
/// }
/// ```
public struct AgentStepSequence<Client: AgentCapableClient, Output: StructuredProtocol>: AsyncSequence, Sendable
    where Client.Model: Sendable
{
    public typealias Element = AgentStep<Output>

    /// LLM クライアント
    private let client: Client

    /// 使用するモデル
    private let model: Client.Model

    /// エージェントコンテキスト
    private let context: AgentContext

    /// 初期化
    ///
    /// - Parameters:
    ///   - client: LLM クライアント
    ///   - model: 使用するモデル
    ///   - context: エージェントコンテキスト
    public init(client: Client, model: Client.Model, context: AgentContext) {
        self.client = client
        self.model = model
        self.context = context
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(client: client, model: model, context: context)
    }
}

// MARK: - AgentStepSequence.AsyncIterator

extension AgentStepSequence {
    public struct AsyncIterator: AsyncIteratorProtocol {
        private let runner: AgentLoopRunner<Client, Output>

        init(client: Client, model: Client.Model, context: AgentContext) {
            self.runner = AgentLoopRunner(client: client, model: model, context: context)
        }

        public mutating func next() async throws -> Element? {
            try await runner.nextStep()
        }
    }
}

// MARK: - AgentLoopRunner

/// エージェントループの実行を管理する Actor
///
/// 終了ポリシーに基づいてループの継続/終了を判定し、
/// ツール呼び出しの実行と結果の管理を行います。
private actor AgentLoopRunner<Client: AgentCapableClient, Output: StructuredProtocol>
    where Client.Model: Sendable
{
    // MARK: - Types

    /// ループの実行フェーズ
    ///
    /// エージェントループは以下のフェーズを順に遷移します：
    /// - ツール使用フェーズ: LLMがツールを自由に呼び出せる状態
    /// - 最終出力フェーズ: 構造化JSONの生成を要求する状態
    /// - 完了: ループが終了した状態
    private enum LoopPhase: Sendable, Equatable {
        /// ツール使用フェーズ
        /// LLMがツールを呼び出し可能。responseSchemaは送信しない。
        case toolUse

        /// 最終出力フェーズ
        /// ツールを無効化し、responseSchemaを送信して構造化出力を要求。
        /// associated value: デコード再試行回数
        case finalOutput(retryCount: Int)

        /// ループ完了
        case completed
    }

    /// 保留中のイベント
    private enum PendingEvent {
        case toolCall(ToolCallInfo)
        case toolResult(ToolResultInfo)
    }

    // MARK: - Properties

    /// LLM クライアント
    private let client: Client

    /// 使用するモデル
    private let model: Client.Model

    /// エージェントコンテキスト
    private let context: AgentContext

    /// 終了ポリシー
    private let terminationPolicy: any AgentTerminationPolicy

    /// ループ状態マネージャー
    private let stateManager: AgentLoopStateManager

    /// 保留中のイベント（ツール呼び出し/結果を順次返すため）
    private var pendingEvents: [PendingEvent] = []

    /// 現在のループフェーズ
    private var phase: LoopPhase = .toolUse

    /// 最大デコード再試行回数
    private let maxDecodeRetries: Int = 2

    // MARK: - Initialization

    init(client: Client, model: Client.Model, context: AgentContext) {
        self.client = client
        self.model = model
        self.context = context

        // 設定から状態マネージャーを初期化
        let config = context.configurationSync
        self.stateManager = AgentLoopStateManager(configuration: config)

        // 設定から終了ポリシーを作成（重複検出 + 総呼び出し回数制限付き）
        self.terminationPolicy = TerminationPolicyFactory.make(from: config)
    }

    // MARK: - Main Loop

    /// 次のステップを取得
    func nextStep() async throws -> AgentStep<Output>? {
        // 1. 保留中のイベントを返す
        if let event = consumePendingEvent() {
            return event
        }

        // 2. フェーズに基づく完了チェック
        if phase == .completed {
            return nil
        }

        // 3. ステップ制限チェック
        if await stateManager.isAtStepLimit {
            throw AgentError.maxStepsExceeded(steps: stateManager.maxSteps)
        }

        // 4. ステップをインクリメント
        try await stateManager.incrementStep()

        // 5. LLM にリクエストを送信
        let response = try await sendRequest()

        // 6. レスポンスをコンテキストに追加
        await context.addAssistantResponse(response)

        // 7. 終了ポリシーで判定
        let decision = await terminationPolicy.shouldTerminate(
            response: response,
            context: stateManager
        )

        // 8. 判定に基づいて処理
        return try await handleDecision(decision, response: response)
    }

    // MARK: - Decision Handling

    /// 終了判定に基づいて処理を行う
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

    /// ツール呼び出しを処理
    private func processToolCalls(_ calls: [ToolCallInfo]) async throws -> AgentStep<Output>? {
        // 設定を取得
        let config = await context.getConfiguration()

        if config.autoExecuteTools {
            // 自動実行モード
            var results: [ToolResultInfo] = []

            for call in calls {
                // 履歴に記録
                await stateManager.recordToolCall(call)

                // イベントをキュー
                pendingEvents.append(.toolCall(call))

                // ツールを実行
                let result = await executeToolSafely(call)
                results.append(result)
                pendingEvents.append(.toolResult(result))
            }

            // 結果をコンテキストに追加
            await context.addToolResults(results)

            // 最初のイベントを返す
            return consumePendingEvent()
        } else {
            // 手動実行モード: 完了としてマーク
            phase = .completed
            await context.markCompleted()

            // 手動モードでは呼び出し側がツール実行を処理するため、
            // ここでは単に nil を返してループを終了
            return nil
        }
    }

    /// 最終出力をデコードまたは最終出力フェーズへ遷移
    ///
    /// - ツールなしでリクエストした場合: 直接デコードを試行
    /// - ツールありでendTurnを受けた場合: 最終出力フェーズに遷移し、
    ///   構造化出力を要求する追加リクエストを送信
    private func decodeFinalOutput(_ text: String, response: LLMResponse) async throws -> AgentStep<Output>? {
        // フェーズに応じた処理
        switch phase {
        case .toolUse:
            // ツール使用フェーズでendTurnを受けた場合
            let tools = await context.getTools()
            if !tools.isEmpty {
                // ツールがまだ存在する = 非構造化テキストで終了しようとしている
                // 最終出力フェーズに遷移して、構造化出力を要求
                phase = .finalOutput(retryCount: 0)
                // thinking として返し、次のステップで構造化出力を要求
                return .thinking(response)
            }
            // ツールがない場合はそのままデコードを試行
            return try decodeAndComplete(text)

        case .finalOutput(let retryCount):
            // 最終出力フェーズでデコードを試行
            do {
                return try decodeAndComplete(text)
            } catch {
                // デコードに失敗した場合、再試行カウンタをチェック
                let newRetryCount = retryCount + 1
                if newRetryCount >= maxDecodeRetries {
                    // 最大再試行回数に達した場合はエラー
                    throw AgentError.outputDecodingFailed(error)
                }
                // 再試行回数を更新してリトライ
                phase = .finalOutput(retryCount: newRetryCount)
                return .thinking(response)
            }

        case .completed:
            // 既に完了している場合（通常は到達しない）
            return nil
        }
    }

    /// JSONをデコードして完了状態に遷移
    private func decodeAndComplete(_ text: String) throws -> AgentStep<Output> {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let output = try decoder.decode(Output.self, from: Data(text.utf8))
        phase = .completed
        Task { await context.markCompleted() }
        return .finalResponse(output)
    }

    /// 即座終了を処理
    private func handleImmediateTermination(_ reason: TerminationReason) -> AgentStep<Output>? {
        phase = .completed
        Task { await context.markCompleted() }

        // 終了理由に応じた処理
        switch reason {
        case .completed, .emptyResponse:
            return nil

        case .maxStepsReached:
            // このケースは通常、事前のチェックで処理されるべき
            return nil

        case .duplicateToolCallDetected(let toolName, let count):
            // 重複検出の場合はログ出力のみで終了
            #if DEBUG
            print("[AgentLoop] Duplicate tool call detected: \(toolName) called \(count) times with same input")
            #endif
            return nil

        case .maxToolCallsPerToolReached(let toolName, let count):
            // 同一ツールの呼び出し回数上限に到達
            #if DEBUG
            print("[AgentLoop] Tool call limit reached: \(toolName) called \(count) times total")
            #endif
            return nil

        case .unexpectedStopReason:
            return nil
        }
    }

    // MARK: - Helper Methods

    /// 保留中のイベントを消費
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

    /// LLM にリクエストを送信
    ///
    /// Anthropic の推奨パターンに従い、フェーズに応じてリクエストを構築：
    /// - ツール使用フェーズ: ツールを送信、responseSchemaは送らない
    /// - 最終出力フェーズ: ツールなし、responseSchemaを送信
    ///
    /// これにより、ツール使用中にLLMがテキスト応答を返した際の
    /// JSONデコードエラーを防ぎます。
    private func sendRequest() async throws -> LLMResponse {
        let messages = await context.getMessages()
        let systemPrompt = await context.getSystemPrompt()

        switch phase {
        case .toolUse:
            // ツール使用フェーズ: ツールを送信、responseSchemaは送らない
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
            // 最終出力フェーズ: ツールなし、responseSchemaを送信
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
            // 完了フェーズでは呼ばれないはず
            throw AgentError.invalidState("sendRequest called in completed phase")
        }
    }

    /// ツールを安全に実行（エラーをキャッチしてToolResultInfoとして返す）
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
