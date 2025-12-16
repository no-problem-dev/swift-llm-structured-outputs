import SwiftUI

struct ConversationView: View {
    @Bindable var controller: ConversationController
    @State private var promptText = ""
    @State private var interruptText = ""
    @State private var answerText = ""
    @State private var showEventLog = false
    @State private var showResultSheet = false
    @State private var showSessionConfig = false

    private var currentResult: String? {
        if case .completed(let result) = controller.state {
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
        .sheet(isPresented: $showEventLog) {
            NavigationStack {
                EventLogView(events: controller.events)
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
                interactiveMode: $controller.interactiveMode,
                outputType: $controller.selectedOutputType,
                isDisabled: controller.state.isRunning,
                onModeChange: {
                    Task {
                        await controller.clearSession()
                        controller.createSession()
                        promptText = ""
                    }
                },
                onClearSession: {
                    Task {
                        await controller.clearSession()
                        controller.createSession()
                        promptText = ""
                    }
                },
                onDismiss: { showSessionConfig = false }
            )
            .presentationDetents([.medium])
        }
        .onAppear {
            controller.createSessionIfNeeded()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 12) {
                if controller.turnCount > 0 {
                    Text("ターン \(controller.turnCount)")
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
                    if case .completed(let result) = controller.state {
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

                    if case .error(let message) = controller.state {
                        ErrorBanner(message: message)
                            .padding(.horizontal)
                    }

                    StepListView(
                        steps: controller.steps,
                        isLoading: controller.state.isRunning,
                        onResultTap: currentResult != nil ? { showResultSheet = true } : nil
                    )
                }
                .padding(.vertical)
                .padding(.top, controller.state.isRunning ? 80 : 0)
            }
            .scrollDismissesKeyboard(.interactively)

            if controller.state.isRunning {
                ExecutionProgressBanner(
                    currentPhase: controller.steps.last?.type,
                    startTime: controller.steps.first?.timestamp
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: controller.state.isRunning)
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(spacing: 12) {
            if controller.waitingForAnswer, let question = controller.pendingQuestion {
                QuestionBanner(question: question)
            }

            if controller.waitingForAnswer {
                ConversationInputField(
                    mode: .answer,
                    text: $answerText,
                    isEnabled: true,
                    onSubmit: sendAnswer
                )
            } else if controller.state.isRunning {
                ConversationInputField(
                    mode: .interrupt,
                    text: $interruptText,
                    isEnabled: true,
                    onSubmit: sendInterrupt,
                    onStop: { controller.stopExecution() }
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
        controller.run(prompt: promptText, outputType: controller.selectedOutputType)
        promptText = ""
    }

    private func sendInterrupt() {
        guard !interruptText.isEmpty else { return }
        Task {
            await controller.interrupt(message: interruptText)
            interruptText = ""
        }
    }

    private func sendAnswer() {
        guard !answerText.isEmpty else { return }
        controller.reply(answerText)
        answerText = ""
    }
}

#Preview {
    @Previewable @State var controller = ConversationController()
    NavigationStack {
        ConversationView(controller: controller)
    }
}
