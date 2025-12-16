import SwiftUI

/// 実行リクエスト
///
/// `.task(id:)` のトリガーとして使用。
/// `id` が変わると前のタスクがキャンセルされ、新しいタスクが開始される。
private struct RunRequest: Equatable {
    let id = UUID()
    let prompt: String
    let outputType: AgentOutputType

    static func == (lhs: RunRequest, rhs: RunRequest) -> Bool {
        lhs.id == rhs.id
    }
}

struct ConversationView<ViewModel: ConversationViewModel>: View {
    @Bindable var viewModel: ViewModel
    @State private var promptText = ""
    @State private var interruptText = ""
    @State private var answerText = ""
    @State private var showEventLog = false
    @State private var showResultSheet = false
    @State private var showSessionConfig = false
    @State private var runRequest: RunRequest?

    private var currentResult: String? {
        if case .completed(let result) = viewModel.state {
            return result
        }
        return nil
    }

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
            await viewModel.run(prompt: request.prompt, outputType: request.outputType)
        }
        .sheet(isPresented: $showEventLog) {
            NavigationStack {
                EventLogView(events: viewModel.events)
                    .navigationTitle("イベントログ")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("閉じる") { showEventLog = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showResultSheet) {
            if let result = currentResult {
                ResultSheet(result: result) { showResultSheet = false }
            }
        }
        .sheet(isPresented: $showSessionConfig) {
            SessionConfigSheet(
                interactiveMode: $viewModel.interactiveMode,
                outputType: $viewModel.selectedOutputType,
                isDisabled: viewModel.state.isRunning,
                onModeChange: {
                    Task {
                        await viewModel.clearSession()
                        viewModel.createSession()
                        promptText = ""
                    }
                },
                onClearSession: {
                    Task {
                        await viewModel.clearSession()
                        viewModel.createSession()
                        promptText = ""
                    }
                },
                onDismiss: { showSessionConfig = false }
            )
            .presentationDetents([.medium])
        }
        .onAppear {
            viewModel.createSessionIfNeeded()
        }
        .onDisappear {
            Task {
                try? await viewModel.save()
            }
        }
        .onChange(of: viewModel.waitingForAnswer) { _, isWaiting in
            if isWaiting {
                Task {
                    try? await viewModel.save()
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 12) {
                if viewModel.turnCount > 0 {
                    Text("ターン \(viewModel.turnCount)")
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
                    if case .completed(let result) = viewModel.state {
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

                    if case .error(let message) = viewModel.state {
                        ErrorBanner(message: message)
                            .padding(.horizontal)
                    }

                    StepListView(
                        steps: viewModel.steps,
                        isLoading: viewModel.state.isRunning,
                        onResultTap: currentResult != nil ? { showResultSheet = true } : nil
                    )
                }
                .padding(.vertical)
                .padding(.top, viewModel.state.isRunning ? 80 : 0)
            }
            .scrollDismissesKeyboard(.interactively)

            if viewModel.state.isRunning {
                ExecutionProgressBanner(
                    currentPhase: viewModel.steps.last?.type,
                    startTime: viewModel.steps.first?.timestamp
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.state.isRunning)
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(spacing: 12) {
            if viewModel.waitingForAnswer, let question = viewModel.pendingQuestion {
                QuestionBanner(question: question)
            }

            if viewModel.waitingForAnswer {
                ConversationInputField(
                    mode: .answer,
                    text: $answerText,
                    isEnabled: true,
                    onSubmit: sendAnswer
                )
            } else if viewModel.state.isRunning {
                ConversationInputField(
                    mode: .interrupt,
                    text: $interruptText,
                    isEnabled: true,
                    onSubmit: sendInterrupt,
                    onStop: { viewModel.cancel() }
                )
            } else {
                ConversationInputField(
                    mode: .prompt,
                    text: $promptText,
                    isEnabled: APIKeyManager.hasAnyLLMKey,
                    onSubmit: runQuery
                )
            }

            APIKeyStatusBar(
                hasLLMKey: APIKeyManager.hasAnyLLMKey,
                hasSearchKey: APIKeyManager.hasBraveSearchKey
            )
        }
        .padding()
    }

    // MARK: - Actions

    private func runQuery() {
        guard !promptText.isEmpty, APIKeyManager.hasAnyLLMKey else { return }
        runRequest = RunRequest(prompt: promptText, outputType: viewModel.selectedOutputType)
        promptText = ""
    }

    private func sendInterrupt() {
        guard !interruptText.isEmpty else { return }
        Task {
            await viewModel.interrupt(message: interruptText)
            interruptText = ""
        }
    }

    private func sendAnswer() {
        guard !answerText.isEmpty else { return }
        viewModel.reply(answerText)
        answerText = ""
    }
}

#Preview {
    @Previewable @State var viewModel = ConversationViewModelImpl()
    NavigationStack {
        ConversationView(viewModel: viewModel)
    }
}
