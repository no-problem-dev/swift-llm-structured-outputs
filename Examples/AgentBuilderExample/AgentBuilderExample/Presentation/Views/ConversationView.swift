import SwiftUI
import LLMStructuredOutputs
import LLMDynamicStructured
import LLMClient
import ExamplesCommon

struct ConversationView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.useCase) private var useCase
    @Environment(\.dismiss) private var dismiss

    let builtType: BuiltType

    @State private var sessionState: AgentSessionState
    @State private var inputText = ""
    @State private var showResultSheet = false
    @State private var executionTask: Task<Void, Never>?

    init(builtType: BuiltType) {
        self.builtType = builtType
        self._sessionState = State(initialValue: AgentSessionState(builtType: builtType))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 型情報ヘッダー
                TypeInfoHeader(type: builtType)

                Divider()

                // メインコンテンツ
                mainContentSection

                Divider()

                // 入力エリア
                inputSection
            }
            .navigationTitle("実行")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(role: .destructive) {
                            Task {
                                await clearSession()
                            }
                        } label: {
                            Label("セッションをクリア", systemImage: "trash")
                        }
                        .disabled(sessionState.executionState.isRunning)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showResultSheet) {
                if let result = sessionState.result {
                    ResultSheet(result: result, builtType: builtType)
                }
            }
        }
    }

    // MARK: - Main Content Section

    private var mainContentSection: some View {
        ZStack(alignment: .top) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if sessionState.steps.isEmpty && !sessionState.executionState.isRunning {
                            emptyStateView
                        } else {
                            StepListView(
                                steps: sessionState.steps,
                                isLoading: sessionState.executionState.isRunning,
                                isCompleted: sessionState.isCompleted,
                                onResultTap: sessionState.result != nil ? { showResultSheet = true } : nil
                            )
                        }
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

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("会話を開始", systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text("下の入力欄からプロンプトを送信して\n\(builtType.name) の生成を開始します")
        }
        .padding(.top, 40)
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(spacing: 12) {
            InputField(
                configuration: inputConfiguration,
                text: $inputText,
                isEnabled: isInputEnabled,
                onSubmit: submitInput,
                leadingAction: nil
            )

            APIKeyStatusBar(hasLLMKey: hasAPIKeyForCurrentProvider)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Input Configuration

    private var inputConfiguration: InputField.Configuration {
        switch sessionState.inputMode {
        case .prompt:
            return .init(
                placeholder: "プロンプトを入力...",
                submitIcon: "paperplane.fill",
                submitTint: .accentColor
            )
        case .interrupt:
            // 現在の実装ではinterruptはサポートされていない
            return .init(
                placeholder: "処理中...",
                submitIcon: "ellipsis",
                submitTint: .gray
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
        case .interrupt:
            return false
        }
    }

    // MARK: - Helpers

    private var hasAPIKeyForCurrentProvider: Bool {
        switch appState.selectedProvider {
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

    // MARK: - Submit Input

    private func submitInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""

        switch sessionState.inputMode {
        case .prompt:
            guard !text.isEmpty else { return }
            createSessionIfNeeded()
            startExecution(prompt: text)

        case .interrupt:
            // 現在の実装ではinterruptはサポートされていない
            break

        case .resume:
            if !text.isEmpty {
                sessionState.addStep(ConversationStepInfo(type: .userMessage, content: text))
            }
            resumeExecution()
        }
    }

    // MARK: - Session Management

    private func createSessionIfNeeded() {
        guard sessionState.session == nil else { return }
        createSession()
    }

    private func createSession() {
        let provider = appState.selectedProvider
        guard let apiKey = apiKey(for: provider) else {
            sessionState.setExecutionState(.error("APIキーが設定されていません"))
            return
        }

        let systemPrompt = buildSystemPrompt()

        let client: ProviderClient
        switch provider {
        case .anthropic:
            client = .anthropic(AnthropicClient(apiKey: apiKey))
        case .openai:
            client = .openai(OpenAIClient(apiKey: apiKey))
        case .gemini:
            client = .gemini(GeminiClient(apiKey: apiKey))
        }

        let newSession = ProviderSession(
            client: client,
            systemPrompt: systemPrompt,
            initialMessages: sessionState.messages
        )

        sessionState.setSession(newSession)

        if !sessionState.executionState.isCompleted {
            sessionState.setExecutionState(.idle)
        }

        sessionState.addEvent("セッションが作成されました")
    }

    private func buildSystemPrompt() -> String {
        var prompt = "あなたはユーザーの要求に基づいて構造化データを生成するアシスタントです。\n\n"
        prompt += "出力する型: \(builtType.name)\n"

        if let description = builtType.description {
            prompt += "説明: \(description)\n"
        }

        prompt += "\nフィールド:\n"
        for field in builtType.fields {
            var fieldDesc = "- \(field.name): \(field.fieldType.displayName)"
            if !field.isRequired {
                fieldDesc += " (optional)"
            }
            if let desc = field.description {
                fieldDesc += " - \(desc)"
            }
            prompt += fieldDesc + "\n"
        }

        prompt += "\nユーザーの要求を理解し、適切な値で各フィールドを埋めてください。"

        return prompt
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

        let dynamicStructured = builtType.toDynamicStructured()

        executionTask = Task {
            await runSession(session: session, prompt: prompt, dynamicStructured: dynamicStructured)
        }
    }

    private func resumeExecution() {
        guard let session = sessionState.session else {
            sessionState.setExecutionState(.error("セッションが存在しません"))
            return
        }

        executionTask?.cancel()
        executionTask = nil

        sessionState.initializeLiveSteps()
        sessionState.setExecutionState(.running)
        sessionState.addStep(ConversationStepInfo(type: .event, content: "セッションを再開しています..."))

        let dynamicStructured = builtType.toDynamicStructured()

        executionTask = Task {
            await resumeSession(session: session, dynamicStructured: dynamicStructured)
        }
    }

    private func runSession(session: ProviderSession, prompt: String, dynamicStructured: DynamicStructured) async {
        do {
            let stream = session.run(
                prompt,
                output: dynamicStructured,
                claudeModel: appState.claudeModelOption.model,
                gptModel: appState.gptModelOption.model,
                geminiModel: appState.geminiModelOption.model
            )
            try await processStream(stream, session: session)
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

    private func resumeSession(session: ProviderSession, dynamicStructured: DynamicStructured) async {
        do {
            let stream = session.resume(
                output: dynamicStructured,
                claudeModel: appState.claudeModelOption.model,
                gptModel: appState.gptModelOption.model,
                geminiModel: appState.geminiModelOption.model
            )
            try await processStream(stream, session: session)
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

    private func processStream(
        _ stream: AsyncThrowingStream<GenerationPhase, Error>,
        session: ProviderSession
    ) async throws {
        var finalOutput: DynamicStructuredResult?

        for try await phase in stream {
            try Task.checkCancellation()

            switch phase {
            case .idle:
                break

            case .running(let step):
                sessionState.addStep(step.toStepInfo())

            case .completed(let output):
                finalOutput = output
                sessionState.addStep(ConversationStepInfo(type: .finalResponse, content: "生成完了"))

            case .failed(let error):
                sessionState.addStep(ConversationStepInfo(type: .error, content: error, isError: true))
            }
        }

        await sessionState.syncMessagesFromSession()

        if let output = finalOutput {
            sessionState.setResult(output)
            sessionState.setExecutionState(.completed)
        }
    }
}

// MARK: - TypeInfoHeader

private struct TypeInfoHeader: View {
    let type: BuiltType

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(type.name)
                    .font(.headline)

                Spacer()

                Text("\(type.fields.count) fields")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let description = type.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(type.fields.prefix(5)) { field in
                    Label(field.name, systemImage: field.fieldType.iconName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.fill.tertiary)
                        .clipShape(Capsule())
                }
                if type.fields.count > 5 {
                    Text("+\(type.fields.count - 5)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.fill.quaternary)
    }
}

// MARK: - APIKeyStatusBar

private struct APIKeyStatusBar: View {
    let hasLLMKey: Bool

    var body: some View {
        HStack(spacing: 8) {
            if hasLLMKey {
                Label("LLM APIキー設定済み", systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            } else {
                Label("LLM APIキー未設定", systemImage: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            Spacer()
        }
    }
}

// MARK: - GenerationStep → ConversationStepInfo

extension GenerationStep {
    func toStepInfo() -> ConversationStepInfo {
        switch self {
        case .userMessage(let message):
            return ConversationStepInfo(type: .userMessage, content: message)

        case .generating:
            return ConversationStepInfo(type: .thinking, content: "生成中...")

        case .finalResponse(let json):
            let truncated = json.count > 200 ? String(json.prefix(200)) + "..." : json
            return ConversationStepInfo(type: .textResponse, content: truncated)
        }
    }
}

#Preview {
    ConversationView(
        builtType: BuiltType(
            name: "UserInfo",
            description: "ユーザー情報",
            fields: [
                BuiltField(name: "name", fieldType: .string, description: "ユーザー名"),
                BuiltField(name: "age", fieldType: .integer, description: "年齢")
            ]
        )
    )
    .environment(AppState())
}
