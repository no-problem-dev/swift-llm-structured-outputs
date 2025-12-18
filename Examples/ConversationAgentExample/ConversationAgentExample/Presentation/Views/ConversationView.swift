import SwiftUI
import LLMStructuredOutputs
import LLMToolkits

private struct RunRequest: Equatable {
    let id = UUID()
    let prompt: String
    let outputType: AgentOutputType

    static func == (lhs: RunRequest, rhs: RunRequest) -> Bool {
        lhs.id == rhs.id
    }
}

struct ConversationView: View {
    @Environment(ConversationState.self) private var state
    @Environment(AppState.self) private var appState
    @Environment(\.useCase) private var useCase

    @State private var promptText = ""
    @State private var interruptText = ""
    @State private var answerText = ""
    @State private var showEventLog = false
    @State private var showResultSheet = false
    @State private var showSessionConfig = false
    @State private var runRequest: RunRequest?
    @State private var session: ProviderSession?
    @State private var eventMonitorTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            mainContentSection
            Divider()
            inputSection
        }
        .navigationTitle("会話エージェント")
        .toolbar { toolbarContent }
        .task(id: runRequest) {
            guard let request = runRequest else { return }
            await run(prompt: request.prompt, outputType: request.outputType)
        }
        .sheet(isPresented: $showEventLog) {
            NavigationStack {
                EventLogView(events: state.events)
                    .navigationTitle("イベントログ")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("閉じる") { showEventLog = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showResultSheet) {
            if let result = state.currentResult {
                ResultSheet(result: result) { showResultSheet = false }
            }
        }
        .sheet(isPresented: $showSessionConfig) {
            sessionConfigSheet
        }
        .onAppear {
            createSessionIfNeeded()
        }
        .onDisappear {
            Task {
                try? await saveSession()
            }
            eventMonitorTask?.cancel()
        }
        .onChange(of: state.waitingForAnswer) { _, isWaiting in
            if isWaiting {
                Task {
                    try? await saveSession()
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 12) {
                if state.turnCount > 0 {
                    Text("ターン \(state.turnCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button { showSessionConfig = true } label: {
                    Image(systemName: "gearshape")
                }

                Button { showEventLog.toggle() } label: {
                    Image(systemName: showEventLog ? "list.bullet.circle.fill" : "list.bullet.circle")
                }
            }
        }
    }

    // MARK: - Main Content

    private var mainContentSection: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if case .completed(let result) = state.executionState {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("結果", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.green)
                            ResultView(result: result)
                        }
                        .padding(.horizontal)

                        Divider()
                            .padding(.vertical, 8)
                    }

                    if case .error(let message) = state.executionState {
                        ErrorBanner(message: message)
                            .padding(.horizontal)
                    }

                    StepListView(
                        steps: state.steps,
                        isLoading: state.executionState.isRunning,
                        onResultTap: state.currentResult != nil ? { showResultSheet = true } : nil
                    )
                }
                .padding(.vertical)
                .padding(.top, state.executionState.isRunning ? 80 : 0)
            }
            .scrollDismissesKeyboard(.interactively)

            if state.executionState.isRunning {
                ExecutionProgressBanner(
                    currentPhase: state.steps.last?.type,
                    startTime: state.steps.first?.timestamp
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.executionState.isRunning)
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(spacing: 12) {
            if state.waitingForAnswer, let question = state.pendingQuestion {
                QuestionBanner(question: question)
            }

            if state.waitingForAnswer {
                ConversationInputField(
                    mode: .answer,
                    text: $answerText,
                    isEnabled: true,
                    onSubmit: sendAnswer
                )
            } else if state.executionState.isRunning {
                ConversationInputField(
                    mode: .interrupt,
                    text: $interruptText,
                    isEnabled: true,
                    onSubmit: sendInterrupt,
                    onStop: { cancel() }
                )
            } else {
                ConversationInputField(
                    mode: .prompt,
                    text: $promptText,
                    isEnabled: hasAPIKeyForCurrentProvider,
                    onSubmit: runQuery
                )
            }

            APIKeyStatusBar(
                hasLLMKey: hasAPIKeyForCurrentProvider,
                hasSearchKey: appState.hasBraveSearchKey
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Session Config Sheet

    @MainActor
    private var sessionConfigSheet: some View {
        UnifiedSettingsView(
            interactiveMode: Binding(
                get: { state.interactiveMode },
                set: { state.setInteractiveMode($0) }
            ),
            outputType: Binding(
                get: { state.selectedOutputType },
                set: { state.setSelectedOutputType($0) }
            ),
            isSessionDisabled: state.executionState.isRunning,
            onModeChange: {
                Task {
                    await clearSession()
                    createSession()
                    promptText = ""
                }
            },
            onClearSession: {
                Task {
                    await clearSession()
                    createSession()
                    promptText = ""
                }
            },
            onDismiss: { showSessionConfig = false }
        )
    }

    // MARK: - Helpers

    private var hasAPIKeyForCurrentProvider: Bool {
        switch state.sessionData.provider {
        case .anthropic: return appState.hasAnthropicKey
        case .openai: return appState.hasOpenAIKey
        case .gemini: return appState.hasGeminiKey
        }
    }

    private func apiKey(for provider: LLMProvider) -> String? {
        switch provider {
        case .anthropic: return useCase.apiKey.get(.anthropic)
        case .openai: return useCase.apiKey.get(.openai)
        case .gemini: return useCase.apiKey.get(.gemini)
        }
    }

    // MARK: - Session Management

    private func createSessionIfNeeded() {
        guard session == nil else { return }
        createSession()
    }

    private func createSession() {
        let provider = state.sessionData.provider
        guard let apiKey = apiKey(for: provider) else {
            state.setExecutionState(.error("APIキーが設定されていません"))
            return
        }

        let newSession: ProviderSession
        switch provider {
        case .anthropic:
            let client = useCase.conversation.createAnthropicClient(apiKey: apiKey)
            let s = useCase.conversation.createSession(
                client: client,
                outputType: state.selectedOutputType,
                interactiveMode: state.interactiveMode
            )
            newSession = .anthropic(s)

        case .openai:
            let client = useCase.conversation.createOpenAIClient(apiKey: apiKey)
            let s = useCase.conversation.createSession(
                client: client,
                outputType: state.selectedOutputType,
                interactiveMode: state.interactiveMode
            )
            newSession = .openai(s)

        case .gemini:
            let client = useCase.conversation.createGeminiClient(apiKey: apiKey)
            let s = useCase.conversation.createSession(
                client: client,
                outputType: state.selectedOutputType,
                interactiveMode: state.interactiveMode
            )
            newSession = .gemini(s)
        }

        session = newSession
        startEventMonitoring()

        if case .completed = state.executionState {
            // 復元された結果を維持
        } else {
            state.setExecutionState(.idle)
        }

        state.setWaitingForAnswer(false)
        state.setPendingQuestion(nil)
        state.addEvent("セッションが作成されました（\(state.selectedOutputType.displayName) / \(state.interactiveMode ? "インタラクティブ" : "自動")モード）")
    }

    private func clearSession() async {
        eventMonitorTask?.cancel()
        eventMonitorTask = nil

        if let session = session {
            await session.clear()
        }

        session = nil
        state.reset()
    }

    private func cancel() {
        guard state.executionState.isRunning else { return }

        Task {
            await session?.cancel()
        }

        state.setExecutionState(.idle)
        state.setWaitingForAnswer(false)
        state.setPendingQuestion(nil)
        state.addStep(ConversationStepInfo(type: .event, content: "実行を停止しました"))
    }

    // MARK: - Execution

    private func run(prompt: String, outputType: AgentOutputType) async {
        guard let session = session else {
            state.setExecutionState(.error("セッションが作成されていません"))
            return
        }
        guard !state.executionState.isRunning else { return }

        state.setExecutionState(.running)

        do {
            switch outputType {
            case .research:
                let stream = await session.runResearch(prompt)
                try await processStream(stream) { $0.formatted }

            case .articleSummary:
                let stream = await session.runArticleSummary(prompt)
                try await processStream(stream) { $0.formatted }

            case .codeReview:
                let stream = await session.runCodeReview(prompt)
                try await processStream(stream) { $0.formatted }
            }

            state.setTurnCount(await session.turnCount)
            try? await saveSession()

        } catch {
            state.setExecutionState(.error(error.localizedDescription))
            state.addStep(ConversationStepInfo(type: .error, content: error.localizedDescription, isError: true))
        }
    }

    private func processStream<Output: StructuredProtocol>(
        _ stream: AsyncThrowingStream<ConversationalAgentStep<Output>, Error>,
        formatResult: @escaping (Output) -> String
    ) async throws {
        var finalOutput: Output?

        for try await step in stream {
            state.addStep(step.toStepInfo())

            switch step {
            case .askingUser(let question):
                state.setPendingQuestion(question)
            case .awaitingUserInput:
                state.setWaitingForAnswer(true)
                state.setExecutionState(.idle)
            case .finalResponse(let output):
                finalOutput = output
            default:
                break
            }
        }

        if let output = finalOutput {
            state.setExecutionState(.completed(formatResult(output)))
        } else {
            state.setExecutionState(.completed("完了しました（テキスト応答）"))
        }
    }

    // MARK: - Event Monitoring

    private func startEventMonitoring() {
        guard let session = session else { return }

        eventMonitorTask?.cancel()
        eventMonitorTask = Task {
            for await event in session.eventStream {
                state.addEvent(event.displayMessage)
            }
        }
    }

    // MARK: - Actions

    private func runQuery() {
        guard !promptText.isEmpty, hasAPIKeyForCurrentProvider else { return }
        runRequest = RunRequest(prompt: promptText, outputType: state.selectedOutputType)
        promptText = ""
    }

    private func sendInterrupt() {
        guard !interruptText.isEmpty else { return }
        Task {
            await session?.interrupt(interruptText)
            state.addStep(ConversationStepInfo(type: .interrupted, content: "割り込み送信: \(interruptText)"))
            interruptText = ""
        }
    }

    private func sendAnswer() {
        guard !answerText.isEmpty, let session = session else { return }

        state.setWaitingForAnswer(false)
        state.setPendingQuestion(nil)
        state.setExecutionState(.running)

        Task {
            await session.reply(answerText)
        }
        answerText = ""
    }

    private func saveSession() async throws {
        guard !state.steps.isEmpty else { return }

        state.updateTitleFromFirstMessage()

        if case .completed(let result) = state.executionState {
            state.updateSessionData(result: result)
        }

        try await useCase.session.saveSession(state.sessionData)
    }
}

#Preview {
    NavigationStack {
        ConversationView()
            .environment(ConversationState())
            .environment(AppState())
    }
}
