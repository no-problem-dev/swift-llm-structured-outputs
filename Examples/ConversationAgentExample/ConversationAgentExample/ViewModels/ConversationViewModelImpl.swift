import Foundation
import LLMStructuredOutputs
import LLMToolkits

/// 会話ViewModel 実装
///
/// ConversationalAgentSession を使用して、マルチターン会話を管理します。
/// LLMToolkits のプリセットと出力型を活用した3つのシナリオをサポート：
/// - Research: AnalysisResult
/// - Article Summary: Summary
/// - Code Review: CodeReview
@Observable @MainActor
final class ConversationViewModelImpl: ConversationViewModel {

    // MARK: - Session Data

    private(set) var sessionData: SessionData

    // MARK: - State Properties

    private(set) var state: SessionState = .idle
    private(set) var steps: [ConversationStepInfo] = []
    private(set) var events: [ConversationStepInfo] = []
    private(set) var turnCount: Int = 0
    private(set) var waitingForAnswer: Bool = false
    private(set) var pendingQuestion: String?

    // MARK: - Bindable Properties

    var selectedOutputType: AgentOutputType {
        didSet { sessionData.outputType = selectedOutputType }
    }

    var interactiveMode: Bool {
        didSet { sessionData.interactiveMode = interactiveMode }
    }

    // MARK: - Private Properties

    private var session: ConversationalAgentSession<AnthropicClient>?
    private var eventMonitorTask: Task<Void, Never>?
    private let storage: SessionStorage

    // MARK: - Initialization

    /// 新規セッションで初期化
    init(storage: SessionStorage = JSONFileSessionStorage()) {
        let newSessionData = SessionData()
        self.storage = storage
        self.sessionData = newSessionData
        self.selectedOutputType = newSessionData.outputType
        self.interactiveMode = newSessionData.interactiveMode
    }

    /// 既存セッションデータで初期化
    init(sessionData: SessionData, storage: SessionStorage = JSONFileSessionStorage()) {
        self.storage = storage
        self.sessionData = sessionData
        self.selectedOutputType = sessionData.outputType
        self.interactiveMode = sessionData.interactiveMode
        self.steps = sessionData.steps
    }

    // MARK: - Session Management

    var hasSession: Bool {
        session != nil
    }

    func createSessionIfNeeded() {
        guard session == nil else { return }
        createSession()
    }

    func createSession() {
        guard let apiKey = APIKeyManager.anthropicKey else {
            state = .error("APIキーが設定されていません")
            return
        }

        let client = AnthropicClient(apiKey: apiKey)

        // シナリオに応じたツールセットを構築
        let tools = buildToolSet(for: selectedOutputType)

        session = ConversationalAgentSession(
            client: client,
            systemPrompt: selectedOutputType.buildPrompt(interactiveMode: interactiveMode),
            tools: tools,
            interactiveMode: interactiveMode
        )

        // イベント監視を開始
        startEventMonitoring()

        state = .idle
        waitingForAnswer = false
        pendingQuestion = nil
        addEvent("セッションが作成されました（\(selectedOutputType.displayName) / \(interactiveMode ? "インタラクティブ" : "自動")モード）")
    }

    func clearSession() async {
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

        // SessionData もリセット
        sessionData.steps = []
        sessionData.updatedAt = Date()
    }

    func cancel() {
        guard state.isRunning else { return }

        Task {
            await session?.cancel()
        }

        state = .idle
        waitingForAnswer = false
        pendingQuestion = nil
        addStep(.init(type: .event, content: "実行を停止しました"))
    }

    // MARK: - User Answer API

    func reply(_ answer: String) {
        guard waitingForAnswer, let session = session else { return }

        waitingForAnswer = false
        pendingQuestion = nil
        state = .running

        Task {
            await session.reply(answer)
        }
    }

    // MARK: - Run Methods

    func run(prompt: String, outputType: AgentOutputType) async {
        guard let session = session else {
            state = .error("セッションが作成されていません")
            return
        }
        guard !state.isRunning else { return }

        state = .running
        await executeRun(session: session, prompt: prompt, outputType: outputType)
    }

    // MARK: - Interrupt

    func interrupt(message: String) async {
        guard let session = session else { return }
        await session.interrupt(message)
        addStep(.init(type: .interrupted, content: "割り込み送信: \(message)"))
    }

    // MARK: - Persistence

    func save() async throws {
        sessionData.steps = steps
        sessionData.updatedAt = Date()
        sessionData.updateTitleFromFirstMessage()
        try await storage.save(sessionData)
    }

    // MARK: - Private Methods

    /// シナリオに応じたツールセットを構築
    private func buildToolSet(for outputType: AgentOutputType) -> ToolSet {
        ToolSet {
            // Research: Web検索 + Webフェッチ
            if outputType.requiresWebSearch {
                WebSearchTool()
            }

            // Research, ArticleSummary: Webフェッチ
            if outputType.requiresWebFetch {
                FetchWebPageTool()
            }

            // CodeReview: テキスト分析ツール（LLMToolkits）
            if outputType == .codeReview {
                TextAnalysisTool()
            }
        }
    }

    private func executeRun(
        session: ConversationalAgentSession<AnthropicClient>,
        prompt: String,
        outputType: AgentOutputType
    ) async {
        do {
            switch outputType {
            case .research:
                // LLMToolkits の AnalysisResult を使用
                let stream: some ConversationalAgentStepStream<AnalysisResult> = await session.run(
                    prompt,
                    model: .sonnet
                )
                try await processStream(stream, outputType: outputType) { $0.formatted }

            case .articleSummary:
                // LLMToolkits の Summary を使用
                let stream: some ConversationalAgentStepStream<Summary> = await session.run(
                    prompt,
                    model: .sonnet
                )
                try await processStream(stream, outputType: outputType) { $0.formatted }

            case .codeReview:
                // LLMToolkits の CodeReview を使用
                let stream: some ConversationalAgentStepStream<CodeReview> = await session.run(
                    prompt,
                    model: .sonnet
                )
                try await processStream(stream, outputType: outputType) { $0.formatted }
            }

            turnCount = await session.turnCount

            // 実行完了時に自動保存
            try? await save()

        } catch {
            state = .error(error.localizedDescription)
            addStep(.init(type: .error, content: error.localizedDescription, isError: true))
        }
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
        sessionData.addStep(step)
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
