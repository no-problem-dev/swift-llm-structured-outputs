import Foundation
import LLMStructuredOutputs

/// 会話コントローラー
///
/// ConversationalAgentSession を使用して、マルチターン会話を管理します。
@Observable @MainActor
final class ConversationController {

    // MARK: - Properties

    private(set) var state: SessionState = .idle
    private(set) var steps: [ConversationStepInfo] = []
    private(set) var events: [ConversationStepInfo] = []
    private(set) var turnCount: Int = 0

    var selectedOutputType: AgentOutputType = .research

    /// インタラクティブモード（AI がユーザーに質問できる）
    ///
    /// `true` の場合、`AskUserTool` が有効になり、AI が不明点を質問できます。
    /// `false` の場合、AI は質問せずに最後まで実行します。
    ///
    /// Note: モード変更時は UI 側で確認ダイアログを表示後、`clearSession()` と `createSession()` を呼び出してください。
    var interactiveMode: Bool = true

    /// AI がユーザーの回答を待っているかどうか
    private(set) var waitingForAnswer: Bool = false

    /// AI からの質問（回答待ち時）
    private(set) var pendingQuestion: String?

    private var session: ConversationalAgentSession<AnthropicClient>?
    private var runningTask: Task<Void, Never>?
    private var eventMonitorTask: Task<Void, Never>?

    // MARK: - Session Management

    /// セッションが存在するか
    var hasSession: Bool {
        session != nil
    }

    /// セッションを作成（存在しない場合のみ）
    func createSessionIfNeeded() {
        guard session == nil else { return }
        createSession()
    }

    /// セッションを作成
    func createSession() {
        guard let apiKey = APIKeyManager.anthropicKey else {
            state = .error("APIキーが設定されていません")
            return
        }

        let client = AnthropicClient(apiKey: apiKey)

        // インタラクティブモードに応じてツールセットを構築
        let tools: ToolSet
        if interactiveMode {
            tools = ToolSet {
                WebSearchTool.self
                FetchWebPageTool.self
                AskUserTool.self
            }
        } else {
            tools = ToolSet {
                WebSearchTool.self
                FetchWebPageTool.self
            }
        }

        session = ConversationalAgentSession(
            client: client,
            systemPrompt: selectedOutputType.buildPrompt(interactiveMode: interactiveMode),
            tools: tools
        )

        // イベント監視を開始
        startEventMonitoring()

        state = .idle
        steps = []
        events = []
        waitingForAnswer = false
        pendingQuestion = nil
        addEvent("セッションが作成されました（\(selectedOutputType.displayName) / \(interactiveMode ? "インタラクティブ" : "自動")モード）")
    }

    /// セッションをクリア
    func clearSession() async {
        runningTask?.cancel()
        runningTask = nil
        eventMonitorTask?.cancel()
        eventMonitorTask = nil

        if let session = session {
            await session.clear()
        }

        session = nil
        state = .idle
        steps = []
        events = []
        turnCount = 0
        waitingForAnswer = false
        pendingQuestion = nil
    }

    /// 実行中のエージェントを停止（会話履歴は保持）
    func stopExecution() {
        guard state.isRunning else { return }

        runningTask?.cancel()
        runningTask = nil

        // セッションの状態をリセット
        Task {
            await session?.cancel()
        }

        state = .idle
        waitingForAnswer = false
        pendingQuestion = nil
        addStep(.init(type: .event, content: "実行を停止しました"))
    }

    // MARK: - User Answer API

    /// AI の質問に回答する
    ///
    /// `waitingForAnswer` が `true` の場合に呼び出してください。
    /// 回答を提供すると、一時停止していたストリームが自動的に再開されます。
    func reply(_ answer: String) {
        guard waitingForAnswer, let session = session else { return }

        waitingForAnswer = false
        pendingQuestion = nil
        state = .running

        // 回答を提供して一時停止していたストリームを再開
        Task {
            await session.reply(answer)
        }
    }

    // MARK: - Run Methods

    /// リサーチレポートを生成
    func runResearch(prompt: String) {
        guard let session = session else {
            state = .error("セッションが作成されていません")
            return
        }
        guard !state.isRunning else { return }

        state = .running

        runningTask = Task {
            await executeRun(session: session, prompt: prompt, outputType: .research)
        }
    }

    /// サマリーレポートを生成
    func runSummary(prompt: String) {
        guard let session = session else {
            state = .error("セッションが作成されていません")
            return
        }
        guard !state.isRunning else { return }

        state = .running

        runningTask = Task {
            await executeRun(session: session, prompt: prompt, outputType: .summary)
        }
    }

    /// 比較レポートを生成
    func runComparison(prompt: String) {
        guard let session = session else {
            state = .error("セッションが作成されていません")
            return
        }
        guard !state.isRunning else { return }

        state = .running

        runningTask = Task {
            await executeRun(session: session, prompt: prompt, outputType: .comparison)
        }
    }

    /// 選択した出力タイプで実行
    func run(prompt: String, outputType: AgentOutputType) {
        switch outputType {
        case .research:
            runResearch(prompt: prompt)
        case .summary:
            runSummary(prompt: prompt)
        case .comparison:
            runComparison(prompt: prompt)
        }
    }

    // MARK: - Interrupt

    /// 割り込みメッセージを送信
    func interrupt(message: String) async {
        guard let session = session else { return }
        await session.interrupt(message)
        addStep(.init(type: .interrupted, content: "割り込み送信: \(message)"))
    }

    // MARK: - Private Methods

    private func executeRun(
        session: ConversationalAgentSession<AnthropicClient>,
        prompt: String,
        outputType: AgentOutputType
    ) async {
        do {
            switch outputType {
            case .research:
                let stream: some ConversationalAgentStepStream<ResearchReport> = await session.run(
                    prompt,
                    model: .sonnet
                )
                try await processStream(stream, outputType: outputType) { $0.formatted }

            case .summary:
                let stream: some ConversationalAgentStepStream<SummaryReport> = await session.run(
                    prompt,
                    model: .sonnet
                )
                try await processStream(stream, outputType: outputType) { $0.formatted }

            case .comparison:
                let stream: some ConversationalAgentStepStream<ComparisonReport> = await session.run(
                    prompt,
                    model: .sonnet
                )
                try await processStream(stream, outputType: outputType) { $0.formatted }
            }

            turnCount = await session.turnCount

        } catch {
            state = .error(error.localizedDescription)
            addStep(.init(type: .error, content: error.localizedDescription, isError: true))
        }

        runningTask = nil
    }

    private func processStream<Output: StructuredProtocol>(
        _ stream: some ConversationalAgentStepStream<Output>,
        outputType: AgentOutputType,
        formatResult: @escaping (Output) -> String
    ) async throws {
        var finalOutput: Output?

        for try await step in stream {
            addStep(step.toStepInfo())

            switch step {
            case .askingUser(let question):
                pendingQuestion = question
            case .awaitingUserInput:
                waitingForAnswer = true
                state = .idle
            case .finalResponse(let output):
                finalOutput = output
            default:
                break
            }
        }

        if let output = finalOutput {
            state = .completed(formatResult(output))
        } else {
            state = .completed("完了しました（テキスト応答）")
        }
    }

    private func addStep(_ step: ConversationStepInfo) {
        steps.append(step)
    }

    private func addEvent(_ message: String) {
        events.append(.init(type: .event, content: message))
    }

    // MARK: - Event Monitoring

    private func startEventMonitoring() {
        guard let session = session else { return }

        eventMonitorTask?.cancel()
        eventMonitorTask = Task {
            for await event in session.eventStream {
                handleEvent(event)
            }
        }
    }

    private func handleEvent(_ event: ConversationalAgentEvent) {
        addEvent(event.displayMessage)
    }
}
