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
        private let client: Client
        private let model: Client.Model
        private let context: AgentContext
        private let state: IteratorState<Client>

        init(client: Client, model: Client.Model, context: AgentContext) {
            self.client = client
            self.model = model
            self.context = context
            self.state = IteratorState<Client>()
        }

        public mutating func next() async throws -> Element? {
            try await state.next(client: client, model: model, context: context)
        }
    }
}

// MARK: - IteratorState (Actor)

/// イテレータの内部状態を管理する Actor
private actor IteratorState<Client: AgentCapableClient> where Client.Model: Sendable {
    /// 現在の状態
    private var phase: Phase = .initial

    /// 保留中のイベント（ツール呼び出し/結果を順次返すため）
    private var pendingEvents: [PendingEvent] = []

    /// フェーズ
    enum Phase {
        case initial
        case waitingForLLM
        case processingToolCalls([ToolCallInfo])
        case completed
    }

    /// 保留中のイベント
    enum PendingEvent {
        case toolCall(ToolCallInfo)
        case toolResult(ToolResultInfo)
    }

    /// 次の要素を取得
    func next<Output: StructuredProtocol>(
        client: Client,
        model: Client.Model,
        context: AgentContext
    ) async throws -> AgentStep<Output>? {
        // 保留中のイベントがあれば返す
        if !pendingEvents.isEmpty {
            let event = pendingEvents.removeFirst()
            switch event {
            case .toolCall(let info):
                return .toolCall(info)
            case .toolResult(let info):
                return .toolResult(info)
            }
        }

        // 完了している場合
        if case .completed = phase {
            return nil
        }

        // 継続可能かチェック
        let canContinue = await context.canContinue()
        if !canContinue {
            let isCompleted = await context.getIsCompleted()
            if isCompleted {
                phase = .completed
                return nil
            }
            let config = await context.getConfiguration()
            throw AgentError.maxStepsExceeded(steps: config.maxSteps)
        }

        // ステップをインクリメント
        try await context.incrementStep()

        // LLM にリクエストを送信
        let response = try await sendRequest(
            client: client,
            model: model,
            context: context,
            responseSchema: Output.jsonSchema
        )

        // レスポンスをコンテキストに追加
        await context.addAssistantResponse(response)

        // ツール呼び出しをチェック
        let toolCalls = await context.extractToolCalls(from: response)

        if !toolCalls.isEmpty {
            // ツール呼び出しがある場合
            phase = .processingToolCalls(toolCalls)

            // 設定を取得
            let config = await context.getConfiguration()

            if config.autoExecuteTools {
                // 自動実行: ツール呼び出しと結果をイベントとしてキュー
                var results: [ToolResultInfo] = []

                for call in toolCalls {
                    pendingEvents.append(.toolCall(call))

                    // ツールを実行
                    let result = await executeToolSafely(context: context, call: call)
                    results.append(result)
                    pendingEvents.append(.toolResult(result))
                }

                // 結果をコンテキストに追加
                await context.addToolResults(results)

                // 次のLLM呼び出しのためにフェーズをリセット
                phase = .waitingForLLM

                // 最初のイベントを返す
                if !pendingEvents.isEmpty {
                    let event = pendingEvents.removeFirst()
                    switch event {
                    case .toolCall(let info):
                        return .toolCall(info)
                    case .toolResult(let info):
                        return .toolResult(info)
                    }
                }
            } else {
                // 手動実行モード: thinking イベントを返して終了
                // （呼び出し側がツール実行を処理する必要あり）
                await context.markCompleted()
                phase = .completed
                return .thinking(response)
            }
        }

        // テキストレスポンスを取得
        let textContent = await context.extractText(from: response)

        // 最終出力をデコードしてみる
        if !textContent.isEmpty {
            do {
                let output = try JSONDecoder().decode(Output.self, from: Data(textContent.utf8))
                await context.markCompleted()
                phase = .completed
                return .finalResponse(output)
            } catch {
                // デコードに失敗した場合、thinking として返す
                // （次のステップでLLMが構造化出力を生成することを期待）
                return .thinking(response)
            }
        }

        // 空のレスポンスの場合
        await context.markCompleted()
        phase = .completed
        return nil
    }

    /// LLM にリクエストを送信
    private func sendRequest(
        client: Client,
        model: Client.Model,
        context: AgentContext,
        responseSchema: JSONSchema
    ) async throws -> LLMResponse {
        let messages = await context.getMessages()
        let systemPrompt = await context.getSystemPrompt()
        let tools = await context.getTools()

        do {
            return try await client.executeAgentStep(
                messages: messages,
                model: model,
                systemPrompt: systemPrompt,
                tools: tools,
                toolChoice: .auto,
                responseSchema: responseSchema
            )
        } catch let error as LLMError {
            throw AgentError.llmError(error)
        }
    }

    /// ツールを安全に実行（エラーをキャッチしてToolResultInfoとして返す）
    private func executeToolSafely(context: AgentContext, call: ToolCallInfo) async -> ToolResultInfo {
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
