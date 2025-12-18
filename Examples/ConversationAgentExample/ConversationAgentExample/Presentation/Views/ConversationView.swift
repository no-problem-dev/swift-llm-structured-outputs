import SwiftUI
import LLMAgent
import LLMStructuredOutputs
import LLMToolkits

struct ConversationView: View {
    @Environment(ActiveSessionState.self) private var sessionState
    @Environment(AppState.self) private var appState
    @Environment(\.useCase) private var useCase

    @State private var promptText = ""
    @State private var interruptText = ""
    @State private var answerText = ""
    @State private var showEventLog = false
    @State private var showResultSheet = false
    @State private var showSessionConfig = false

    var body: some View {
        VStack(spacing: 0) {
            mainContentSection
            Divider()
            inputSection
        }
        .navigationTitle("会話エージェント")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showEventLog) {
            NavigationStack {
                EventLogView(events: sessionState.events)
                    .navigationTitle("イベントログ")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("閉じる") { showEventLog = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showResultSheet) {
            if let result = sessionState.currentResult {
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
            // タスクはActiveSessionStateで管理されているため
            // ここではキャンセルしない（セッションはアプリ全体で共有される）
        }
        .onChange(of: sessionState.waitingForAnswer) { _, isWaiting in
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
                if sessionState.turnCount > 0 {
                    Text("ターン \(sessionState.turnCount)")
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
                    if case .completed(let result) = sessionState.executionState {
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

                    if case .error(let message) = sessionState.executionState {
                        ErrorBanner(message: message, onResume: resumeSession)
                            .padding(.horizontal)
                    }

                    StepListView(
                        steps: sessionState.steps,
                        isLoading: sessionState.executionState.isRunning,
                        onResultTap: sessionState.currentResult != nil ? { showResultSheet = true } : nil
                    )
                }
                .padding(.vertical)
                .padding(.top, sessionState.executionState.isRunning ? 80 : 0)
            }
            .scrollDismissesKeyboard(.interactively)

            if sessionState.executionState.isRunning {
                ExecutionProgressBanner(
                    currentPhase: sessionState.steps.last?.type,
                    startTime: sessionState.steps.first?.timestamp
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: sessionState.executionState.isRunning)
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(spacing: 12) {
            if sessionState.waitingForAnswer, let question = sessionState.pendingQuestion {
                QuestionBanner(question: question)
            }

            // 再開可能な状態では再開バナーを表示
            // （paused、error、または会話履歴がある idle/completed 状態）
            if sessionState.canResume {
                ResumeSessionBanner(onResume: resumeSession)
            }

            if sessionState.waitingForAnswer {
                ConversationInputField(
                    mode: .answer,
                    text: $answerText,
                    isEnabled: true,
                    onSubmit: sendAnswer
                )
            } else if sessionState.executionState.isRunning {
                ConversationInputField(
                    mode: .interrupt,
                    text: $interruptText,
                    isEnabled: true,
                    onSubmit: sendInterrupt,
                    onStop: { sessionState.stopExecution() }
                )
            } else if sessionState.canResume {
                // 再開可能な状態では入力を無効化（再開バナーを使用させる）
                ConversationInputField(
                    mode: .prompt,
                    text: $promptText,
                    isEnabled: false,
                    onSubmit: runQuery
                )
            } else {
                // 新規セッション（会話履歴なし）の場合のみ入力可能
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
                get: { sessionState.interactiveMode },
                set: { sessionState.setInteractiveMode($0) }
            ),
            outputType: Binding(
                get: { sessionState.selectedOutputType },
                set: { sessionState.setSelectedOutputType($0) }
            ),
            isSessionDisabled: sessionState.executionState.isRunning,
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
        switch sessionState.sessionData.provider {
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
        guard sessionState.session == nil else { return }
        createSession()
    }

    private func createSession() {
        let provider = sessionState.sessionData.provider
        guard let apiKey = apiKey(for: provider) else {
            sessionState.setExecutionState(.error("APIキーが設定されていません"))
            return
        }

        // AppStateのmaxStepsを使用してAgentConfigurationを作成
        let configuration = AgentConfiguration(
            maxSteps: appState.maxSteps,
            autoExecuteTools: true,
            maxDuplicateToolCalls: 2,
            maxToolCallsPerTool: nil  // ステップ数で制限するのでツール毎の制限は不要
        )

        // 復元する会話履歴
        let initialMessages = sessionState.sessionData.messages

        let newSession: ProviderSession
        switch provider {
        case .anthropic:
            let client = useCase.conversation.createAnthropicClient(apiKey: apiKey)
            let s = useCase.conversation.createSession(
                client: client,
                outputType: sessionState.selectedOutputType,
                interactiveMode: sessionState.interactiveMode,
                configuration: configuration,
                initialMessages: initialMessages
            )
            newSession = .anthropic(s)

        case .openai:
            let client = useCase.conversation.createOpenAIClient(apiKey: apiKey)
            let s = useCase.conversation.createSession(
                client: client,
                outputType: sessionState.selectedOutputType,
                interactiveMode: sessionState.interactiveMode,
                configuration: configuration,
                initialMessages: initialMessages
            )
            newSession = .openai(s)

        case .gemini:
            let client = useCase.conversation.createGeminiClient(apiKey: apiKey)
            let s = useCase.conversation.createSession(
                client: client,
                outputType: sessionState.selectedOutputType,
                interactiveMode: sessionState.interactiveMode,
                configuration: configuration,
                initialMessages: initialMessages
            )
            newSession = .gemini(s)
        }

        sessionState.setSession(newSession)

        if case .completed = sessionState.executionState {
            // 復元された結果を維持
        } else {
            sessionState.setExecutionState(.idle)
        }

        sessionState.setWaitingForAnswer(false)
        sessionState.setPendingQuestion(nil)

        let historyInfo = initialMessages.isEmpty ? "" : "（履歴: \(initialMessages.count)メッセージ）"
        sessionState.addEvent("セッションが作成されました（\(sessionState.selectedOutputType.displayName) / \(sessionState.interactiveMode ? "インタラクティブ" : "自動")モード）\(historyInfo)")
    }

    private func clearSession() async {
        if let session = sessionState.session {
            await session.clear()
        }

        sessionState.resetAll()
    }

    // MARK: - Actions

    private func runQuery() {
        guard !promptText.isEmpty, hasAPIKeyForCurrentProvider else { return }

        let prompt = promptText
        promptText = ""

        // ActiveSessionStateで実行タスクを管理
        sessionState.startExecution(prompt: prompt) { [useCase, sessionState] in
            try await ConversationView.saveSessionInternal(useCase: useCase, sessionState: sessionState)
        }
    }

    private func sendInterrupt() {
        guard !interruptText.isEmpty else { return }
        Task {
            await sessionState.session?.interrupt(interruptText)
            sessionState.addStep(ConversationStepInfo(type: .interrupted, content: "割り込み送信: \(interruptText)"))
            interruptText = ""
        }
    }

    private func resumeSession() {
        // ActiveSessionStateで再開タスクを管理
        sessionState.resumeExecution { [useCase, sessionState] in
            try await ConversationView.saveSessionInternal(useCase: useCase, sessionState: sessionState)
        }
    }

    private func sendAnswer() {
        guard !answerText.isEmpty, let session = sessionState.session else { return }

        sessionState.setWaitingForAnswer(false)
        sessionState.setPendingQuestion(nil)
        sessionState.setExecutionState(.running)

        Task {
            await session.reply(answerText)
        }
        answerText = ""
    }

    private func saveSession() async throws {
        try await Self.saveSessionInternal(useCase: useCase, sessionState: sessionState)
    }

    /// セッション保存の内部実装（クロージャから呼び出し可能）
    @MainActor
    private static func saveSessionInternal(
        useCase: any UseCaseContainer,
        sessionState: ActiveSessionState
    ) async throws {
        // messages が空の場合は保存しない
        guard !sessionState.sessionData.messages.isEmpty else { return }

        sessionState.updateTitleFromFirstMessage()

        if case .completed(let result) = sessionState.executionState {
            sessionState.updateSessionData(result: result)
        }

        try await useCase.session.saveSession(sessionState.sessionData)
    }
}

#Preview {
    NavigationStack {
        ConversationView()
            .environment(ActiveSessionState())
            .environment(AppState())
    }
}
