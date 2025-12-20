import SwiftUI
import LLMStructuredOutputs
import LLMToolkits
import ExamplesCommon

struct ConversationView: View {
    @Environment(ActiveSessionState.self) private var sessionState
    @Environment(AppState.self) private var appState
    @Environment(\.useCase) private var useCase

    @State private var inputText = ""
    @State private var showEventLog = false
    @State private var showResultSheet = false
    @State private var showSessionConfig = false
    @State private var executionTask: Task<Void, Never>?

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
        .onDisappear {
            Task { try? await saveSession() }
        }
        .onChange(of: sessionState.waitingForAnswer) { _, isWaiting in
            if isWaiting {
                Task { try? await saveSession() }
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
            ScrollViewReader { proxy in
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
                            ErrorBanner(message: message, onResume: { submitInput() })
                                .padding(.horizontal)
                        }

                        StepListView(
                            steps: sessionState.steps,
                            isLoading: sessionState.executionState.isRunning,
                            isCompleted: sessionState.isCompleted,
                            onResultTap: sessionState.currentResult != nil ? { showResultSheet = true } : nil
                        )
                    }
                    .padding(.vertical)
                    .padding(.top, sessionState.executionState.isRunning ? 80 : 0)
                }
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: sessionState.steps.count) { _, _ in
                    if let lastStep = sessionState.steps.last {
                        withAnimation {
                            proxy.scrollTo(lastStep.id, anchor: .bottom)
                        }
                    }
                }
            }

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

            InputField(
                configuration: inputConfiguration,
                text: $inputText,
                isEnabled: isInputEnabled,
                onSubmit: submitInput,
                leadingAction: leadingAction
            )

            APIKeyStatusBar(
                hasLLMKey: hasAPIKeyForCurrentProvider,
                hasSearchKey: appState.hasBraveSearchKey
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Input Configuration

    private var inputConfiguration: InputField.Configuration {
        switch sessionState.inputMode {
        case .prompt:
            return .init(
                placeholder: "質問を入力...",
                submitIcon: "paperplane.fill",
                submitTint: .accentColor
            )
        case .interrupt:
            return .init(
                placeholder: "割り込みメッセージ...",
                submitIcon: "bolt.fill",
                submitTint: .orange
            )
        case .answer:
            return .init(
                placeholder: "回答を入力...",
                submitIcon: "arrowshape.turn.up.right.fill",
                submitTint: .indigo
            )
        case .resume:
            return .init(
                placeholder: "追加の指示（任意）...",
                submitIcon: "play.fill",
                submitTint: .green,
                allowEmptySubmit: true
            )
        }
    }

    private var isInputEnabled: Bool {
        switch sessionState.inputMode {
        case .prompt, .resume:
            return hasAPIKeyForCurrentProvider
        case .interrupt, .answer:
            return true
        }
    }

    private var leadingAction: InputField.LeadingAction? {
        guard sessionState.inputMode == .interrupt else { return nil }
        return .init(icon: "stop.fill", tint: .red) {
            stopExecution()
        }
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
                    inputText = ""
                }
            },
            onClearSession: {
                Task {
                    await clearSession()
                    inputText = ""
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

        let configuration = AgentConfiguration(
            maxSteps: appState.maxSteps,
            autoExecuteTools: true,
            maxDuplicateToolCalls: 2,
            maxToolCallsPerTool: nil
        )

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

        if !sessionState.executionState.isCompleted {
            sessionState.setExecutionState(.idle)
        }

        sessionState.setWaitingForAnswer(false)
        sessionState.setPendingQuestion(nil)

        let historyInfo = initialMessages.isEmpty ? "" : "（履歴: \(initialMessages.count)メッセージ）"
        sessionState.addEvent("セッションが作成されました（\(sessionState.selectedOutputType.displayName) / \(sessionState.interactiveMode ? "インタラクティブ" : "自動")モード）\(historyInfo)")
    }

    private func clearSession() async {
        executionTask?.cancel()
        executionTask = nil
        if let session = sessionState.session {
            await session.clear()
        }
        sessionState.resetAll()
    }

    // MARK: - Execution

    private func startExecution(prompt: String) {
        guard let session = sessionState.session else {
            sessionState.setExecutionState(.error("セッションが作成されていません"))
            return
        }

        executionTask?.cancel()
        sessionState.initializeLiveSteps()
        sessionState.setExecutionState(.running)

        executionTask = Task {
            await runSession(session: session, prompt: prompt)
        }
    }

    private func resumeExecution() {
        guard let session = sessionState.session else {
            sessionState.setExecutionState(.error("セッションが存在しません"))
            return
        }

        // 既存タスクをキャンセル
        executionTask?.cancel()
        executionTask = nil

        sessionState.initializeLiveSteps()
        sessionState.setExecutionState(.running)
        sessionState.addStep(ConversationStepInfo(type: .event, content: "セッションを再開しています..."))

        executionTask = Task {
            // セッションが確実に停止状態になるのを待つ
            await useCase.execution.stop(session: session)
            await resumeSession(session: session)
        }
    }

    private func stopExecution() {
        guard sessionState.executionState.isRunning, let session = sessionState.session else { return }

        // まずタスクをキャンセル
        executionTask?.cancel()
        executionTask = nil

        // UI状態を即座に更新
        sessionState.setExecutionState(.paused)
        sessionState.setWaitingForAnswer(false)
        sessionState.setPendingQuestion(nil)
        sessionState.addStep(ConversationStepInfo(type: .event, content: "実行を停止しました"))

        // セッションのキャンセルとメッセージ同期はバックグラウンドで
        Task {
            await useCase.execution.stop(session: session)
            await sessionState.syncMessagesFromSession()
        }
    }

    private func runSession(session: ProviderSession, prompt: String) async {
        do {
            switch sessionState.selectedOutputType {
            case .research:
                let stream = session.runResearch(prompt)
                try await processStream(stream, session: session) { $0.formatted }

            case .articleSummary:
                let stream = session.runArticleSummary(prompt)
                try await processStream(stream, session: session) { $0.formatted }

            case .codeReview:
                let stream = session.runCodeReview(prompt)
                try await processStream(stream, session: session) { $0.formatted }
            }
        } catch is CancellationError {
            sessionState.addEvent("実行がキャンセルされました")
            await sessionState.syncMessagesFromSession()
        } catch {
            sessionState.setExecutionState(.error(error.localizedDescription))
            sessionState.addStep(ConversationStepInfo(
                type: .error,
                content: error.localizedDescription,
                isError: true
            ))
            await sessionState.syncMessagesFromSession()
        }

        executionTask = nil
    }

    private func resumeSession(session: ProviderSession) async {
        do {
            switch sessionState.selectedOutputType {
            case .research:
                let stream = session.resumeResearch()
                try await processStream(stream, session: session) { $0.formatted }

            case .articleSummary:
                let stream = session.resumeArticleSummary()
                try await processStream(stream, session: session) { $0.formatted }

            case .codeReview:
                let stream = session.resumeCodeReview()
                try await processStream(stream, session: session) { $0.formatted }
            }
        } catch is CancellationError {
            sessionState.addEvent("実行がキャンセルされました")
            await sessionState.syncMessagesFromSession()
        } catch {
            sessionState.setExecutionState(.error(error.localizedDescription))
            sessionState.addStep(ConversationStepInfo(
                type: .error,
                content: error.localizedDescription,
                isError: true
            ))
            await sessionState.syncMessagesFromSession()
        }

        executionTask = nil
    }

    private func processStream<Output: StructuredProtocol>(
        _ stream: AsyncThrowingStream<SessionPhase<Output>, Error>,
        session: ProviderSession,
        formatResult: @escaping (Output) -> String
    ) async throws {
        var finalOutput: Output?

        for try await phase in stream {
            try Task.checkCancellation()

            switch phase {
            case .idle:
                break

            case .running(let step):
                sessionState.addStep(step.toStepInfo())
                if case .askingUser(let question) = step {
                    sessionState.setPendingQuestion(question)
                }

            case .awaitingUserInput(let question):
                sessionState.setPendingQuestion(question)
                sessionState.setWaitingForAnswer(true)
                sessionState.setExecutionState(.idle)
                sessionState.addStep(ConversationStepInfo(
                    type: .awaitingInput,
                    content: "下の入力欄から回答してください"
                ))

            case .paused:
                sessionState.addEvent("セッションが一時停止されました")

            case .completed(let output):
                finalOutput = output
                sessionState.addStep(ConversationStepInfo(type: .finalResponse, content: "レポート生成完了"))

            case .failed(let error):
                sessionState.addStep(ConversationStepInfo(type: .error, content: error, isError: true))
            }
        }

        await sessionState.syncMessagesFromSession()

        if let output = finalOutput {
            sessionState.setExecutionState(.completed(formatResult(output)))
        } else {
            sessionState.setExecutionState(.paused)
        }

        sessionState.setTurnCount(await session.turnCount)
        sessionState.syncStepsFromMessages()

        try? await saveSession()
    }

    // MARK: - Actions

    private func submitInput() {
        let text = inputText

        switch sessionState.inputMode {
        case .prompt:
            guard !text.isEmpty else { return }
            inputText = ""
            createSessionIfNeeded()
            startExecution(prompt: text)

        case .interrupt:
            guard !text.isEmpty, let session = sessionState.session else { return }
            inputText = ""
            Task {
                await useCase.execution.interrupt(session: session, message: text)
                sessionState.addStep(ConversationStepInfo(type: .interrupted, content: "割り込み送信: \(text)"))
            }

        case .answer:
            guard !text.isEmpty, let session = sessionState.session else { return }
            inputText = ""
            sessionState.setWaitingForAnswer(false)
            sessionState.setPendingQuestion(nil)
            sessionState.setExecutionState(.running)
            Task {
                await useCase.execution.reply(session: session, answer: text)
            }

        case .resume:
            inputText = ""
            createSessionIfNeeded()
            if !text.isEmpty, let session = sessionState.session {
                Task {
                    await useCase.execution.interrupt(session: session, message: text)
                    sessionState.addStep(ConversationStepInfo(type: .interrupted, content: "追加指示: \(text)"))
                }
            }
            resumeExecution()
        }
    }

    private func saveSession() async throws {
        guard !sessionState.sessionData.messages.isEmpty else { return }

        sessionState.updateTitleFromFirstMessage()

        if case .completed(let result) = sessionState.executionState {
            sessionState.updateSessionData(result: result)
        }

        try await useCase.execution.save(
            sessionData: sessionState.sessionData,
            sessionUseCase: useCase.session
        )
    }
}

#Preview {
    NavigationStack {
        ConversationView()
            .environment(ActiveSessionState())
            .environment(AppState())
    }
}
