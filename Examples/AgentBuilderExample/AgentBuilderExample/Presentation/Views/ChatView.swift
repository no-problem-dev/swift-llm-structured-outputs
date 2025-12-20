import SwiftUI
import LLMStructuredOutputs
import LLMDynamicStructured
import LLMClient
import ExamplesCommon

/// チャット画面
struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.useCase) private var useCase

    let session: Session
    let agent: Agent

    @State private var chatState: ChatState
    @State private var inputText = ""
    @State private var showResultSheet = false
    @State private var executionTask: Task<Void, Never>?

    init(session: Session, agent: Agent) {
        self.session = session
        self.agent = agent
        self._chatState = State(initialValue: ChatState(outputSchema: agent.outputSchema))
    }

    var body: some View {
        VStack(spacing: 0) {
            SchemaInfoHeader(schema: agent.outputSchema)

            Divider()

            mainContentSection

            Divider()

            inputSection
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        Task { await clearSession() }
                    } label: {
                        Label("セッションをクリア", systemImage: "trash")
                    }
                    .disabled(chatState.executionState.isRunning)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showResultSheet) {
            if let result = chatState.result {
                ResultSheet(result: result, outputSchema: agent.outputSchema)
            }
        }
    }

    // MARK: - Main Content Section

    private var mainContentSection: some View {
        ZStack(alignment: .top) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if chatState.steps.isEmpty && !chatState.executionState.isRunning {
                            emptyStateView
                        } else {
                            StepListView(
                                steps: chatState.steps,
                                isLoading: chatState.executionState.isRunning,
                                isCompleted: chatState.isCompleted,
                                onResultTap: chatState.result != nil ? { showResultSheet = true } : nil
                            )
                        }
                    }
                    .padding(.vertical)
                    .padding(.top, chatState.executionState.isRunning ? 80 : 0)
                }
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: chatState.steps.count) { _, _ in
                    if let lastStep = chatState.steps.last {
                        withAnimation {
                            proxy.scrollTo(lastStep.id, anchor: .bottom)
                        }
                    }
                }
            }

            if chatState.executionState.isRunning {
                ExecutionProgressBanner(
                    currentPhase: chatState.steps.last?.type,
                    startTime: chatState.steps.first?.timestamp
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: chatState.executionState.isRunning)
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("会話を開始", systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text("下の入力欄からプロンプトを送信して\n\(agent.outputSchema.name) の生成を開始します")
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
        switch chatState.inputMode {
        case .prompt:
            return .init(
                placeholder: "プロンプトを入力...",
                submitIcon: "paperplane.fill",
                submitTint: .accentColor
            )
        case .interrupt:
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
        switch chatState.inputMode {
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

        switch chatState.inputMode {
        case .prompt:
            guard !text.isEmpty else { return }
            createSessionIfNeeded()
            startExecution(prompt: text)

        case .interrupt:
            break

        case .resume:
            if !text.isEmpty {
                chatState.addStep(ConversationStepInfo(type: .userMessage, content: text))
            }
            resumeExecution()
        }
    }

    // MARK: - Session Management

    private func createSessionIfNeeded() {
        guard chatState.session == nil else { return }
        createSession()
    }

    private func createSession() {
        let provider = appState.selectedProvider
        guard let apiKey = apiKey(for: provider) else {
            chatState.setExecutionState(.error("APIキーが設定されていません"))
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
            initialMessages: []
        )

        chatState.setSession(newSession)

        if !chatState.executionState.isCompleted {
            chatState.setExecutionState(.idle)
        }

        chatState.addEvent("セッションが作成されました")
    }

    private func buildSystemPrompt() -> String {
        // Use agent's system prompt if defined
        if !agent.systemPrompt.isEmpty {
            return agent.systemPrompt.render()
        }

        // Default system prompt
        var prompt = "あなたはユーザーの要求に基づいて構造化データを生成するアシスタントです。\n\n"
        prompt += "出力する型: \(agent.outputSchema.name)\n"

        if let description = agent.outputSchema.description {
            prompt += "説明: \(description)\n"
        }

        prompt += "\nフィールド:\n"
        for field in agent.outputSchema.fields {
            var fieldDesc = "- \(field.name): \(field.type.displayName)"
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
        if let session = chatState.session {
            await session.clear()
        }
        chatState.resetAll()
    }

    // MARK: - Execution

    private func startExecution(prompt: String) {
        guard let session = chatState.session else {
            chatState.setExecutionState(.error("セッションが作成されていません"))
            return
        }

        executionTask?.cancel()
        chatState.initializeLiveSteps()
        chatState.setExecutionState(.running)

        let dynamicStructured = agent.outputSchema.toDynamicStructured()

        executionTask = Task {
            await runSession(session: session, prompt: prompt, dynamicStructured: dynamicStructured)
        }
    }

    private func resumeExecution() {
        guard let session = chatState.session else {
            chatState.setExecutionState(.error("セッションが存在しません"))
            return
        }

        executionTask?.cancel()
        executionTask = nil

        chatState.initializeLiveSteps()
        chatState.setExecutionState(.running)
        chatState.addStep(ConversationStepInfo(type: .event, content: "セッションを再開しています..."))

        let dynamicStructured = agent.outputSchema.toDynamicStructured()

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
            chatState.addEvent("実行がキャンセルされました")
            await chatState.syncMessagesFromSession()
        } catch {
            chatState.setExecutionState(.error(error.localizedDescription))
            chatState.addStep(ConversationStepInfo(
                type: .error,
                content: error.localizedDescription,
                isError: true
            ))
            await chatState.syncMessagesFromSession()
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
            chatState.addEvent("実行がキャンセルされました")
            await chatState.syncMessagesFromSession()
        } catch {
            chatState.setExecutionState(.error(error.localizedDescription))
            chatState.addStep(ConversationStepInfo(
                type: .error,
                content: error.localizedDescription,
                isError: true
            ))
            await chatState.syncMessagesFromSession()
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
                chatState.addStep(step.toStepInfo())

            case .completed(let output):
                finalOutput = output
                chatState.addStep(ConversationStepInfo(type: .finalResponse, content: "生成完了"))

            case .failed(let error):
                chatState.addStep(ConversationStepInfo(type: .error, content: error, isError: true))
            }
        }

        await chatState.syncMessagesFromSession()

        if let output = finalOutput {
            chatState.setResult(output)
            chatState.setExecutionState(.completed)
        }
    }
}

// MARK: - SchemaInfoHeader

private struct SchemaInfoHeader: View {
    let schema: OutputSchema

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(schema.name)
                    .font(.headline)

                Spacer()

                Text("\(schema.fields.count) fields")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let description = schema.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(schema.fields.prefix(5)) { field in
                    Label(field.name, systemImage: field.type.icon)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.fill.tertiary)
                        .clipShape(Capsule())
                }
                if schema.fields.count > 5 {
                    Text("+\(schema.fields.count - 5)")
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
