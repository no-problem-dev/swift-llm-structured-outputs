import SwiftUI

/// メインコンテンツビュー
///
/// アプリのエントリーポイントとなるビューです。
/// セッション一覧をメイン画面として表示し、設定はナビゲーションバーからモーダルで開きます。
struct ContentView: View {
    @State private var sessionListViewModel = SessionListViewModel()
    @State private var selectedSession: SessionData?
    @State private var conversationViewModel: ConversationViewModelImpl?
    @State private var navigationPath = NavigationPath()
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            SessionListView(
                viewModel: sessionListViewModel,
                selectedSession: $selectedSession,
                onNewSession: createNewSession
            )
            .navigationDestination(for: SessionData.self) { session in
                if let viewModel = conversationViewModel, viewModel.sessionData.id == session.id {
                    ConversationView(viewModel: viewModel)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .onAppear {
            // 環境変数からAPIキーを同期
            APIKeyManager.syncFromEnvironment()
        }
        .onChange(of: selectedSession) { _, newSession in
            if let session = newSession {
                openSession(session)
            }
        }
        .sheet(isPresented: $showSettings) {
            // セッションがない状態での設定画面（APIキーのみ）
            APIKeysOnlySettingsView {
                showSettings = false
            }
        }
    }

    // MARK: - Actions

    private func createNewSession() {
        let newSession = sessionListViewModel.createNewSession()
        openSession(newSession)
    }

    private func openSession(_ session: SessionData) {
        conversationViewModel = ConversationViewModelImpl(sessionData: session)
        navigationPath.append(session)
        selectedSession = nil
    }
}

/// APIキーのみの設定ビュー（セッション一覧から開く用）
struct APIKeysOnlySettingsView: View {
    var onDismiss: () -> Void

    @State private var anthropicKey = ""
    @State private var openAIKey = ""
    @State private var geminiKey = ""
    @State private var braveSearchKey = ""
    @State private var showingAnthropicKey = false
    @State private var showingOpenAIKey = false
    @State private var showingGeminiKey = false
    @State private var showingBraveSearchKey = false

    private var settings: AgentSettings { AgentSettings.shared }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - プロバイダー選択
                Section {
                    Picker("LLMプロバイダー", selection: Binding(
                        get: { settings.selectedProvider },
                        set: { settings.selectedProvider = $0 }
                    )) {
                        ForEach(AgentSettings.Provider.allCases) { provider in
                            HStack {
                                Text(provider.rawValue)
                                if provider.hasAPIKey {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .tag(provider)
                        }
                    }
                } header: {
                    Text("プロバイダー")
                }

                // MARK: - モデル選択
                Section {
                    if settings.selectedProvider == .anthropic {
                        Picker("Claude モデル", selection: Binding(
                            get: { settings.claudeModelOption },
                            set: { settings.claudeModelOption = $0 }
                        )) {
                            ForEach(AgentSettings.ClaudeModelOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } else if settings.selectedProvider == .openai {
                        Picker("GPT モデル", selection: Binding(
                            get: { settings.gptModelOption },
                            set: { settings.gptModelOption = $0 }
                        )) {
                            ForEach(AgentSettings.GPTModelOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } else if settings.selectedProvider == .gemini {
                        Picker("Gemini モデル", selection: Binding(
                            get: { settings.geminiModelOption },
                            set: { settings.geminiModelOption = $0 }
                        )) {
                            ForEach(AgentSettings.GeminiModelOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    }
                } header: {
                    Text("モデル")
                }

                // MARK: - エージェント設定
                Section {
                    Stepper(
                        "最大ステップ数: \(settings.maxSteps)",
                        value: Binding(
                            get: { settings.maxSteps },
                            set: { settings.maxSteps = $0 }
                        ),
                        in: 1...20
                    )
                } header: {
                    Text("エージェント設定")
                } footer: {
                    Text("エージェントが実行できるツール呼び出しの最大回数です。")
                }

                // MARK: - LLM APIキー
                Section {
                    APIKeyRow(
                        label: "Anthropic API Key",
                        key: $anthropicKey,
                        isVisible: $showingAnthropicKey,
                        isSet: APIKeyManager.hasAnthropicKey,
                        onSave: { APIKeyManager.setAnthropicKey($0) }
                    )

                    APIKeyRow(
                        label: "OpenAI API Key",
                        key: $openAIKey,
                        isVisible: $showingOpenAIKey,
                        isSet: APIKeyManager.hasOpenAIKey,
                        onSave: { APIKeyManager.setOpenAIKey($0) }
                    )

                    APIKeyRow(
                        label: "Gemini API Key",
                        key: $geminiKey,
                        isVisible: $showingGeminiKey,
                        isSet: APIKeyManager.hasGeminiKey,
                        onSave: { APIKeyManager.setGeminiKey($0) }
                    )
                } header: {
                    Text("LLM APIキー")
                } footer: {
                    Text("少なくとも1つのLLM APIキーが必要です。")
                }

                // MARK: - 外部APIキー
                Section {
                    APIKeyRow(
                        label: "Brave Search API Key",
                        key: $braveSearchKey,
                        isVisible: $showingBraveSearchKey,
                        isSet: APIKeyManager.hasBraveSearchKey,
                        onSave: { APIKeyManager.setBraveSearchKey($0) }
                    )
                } header: {
                    Text("外部APIキー（オプション）")
                } footer: {
                    Text("Brave Search APIキーがない場合、Web検索ツールは利用できません。")
                }

                // MARK: - ステータス
                Section {
                    StatusRow(label: "Anthropic", isConfigured: APIKeyManager.hasAnthropicKey)
                    StatusRow(label: "OpenAI", isConfigured: APIKeyManager.hasOpenAIKey)
                    StatusRow(label: "Gemini", isConfigured: APIKeyManager.hasGeminiKey)
                    StatusRow(label: "Brave Search", isConfigured: APIKeyManager.hasBraveSearchKey)
                } header: {
                    Text("APIステータス")
                }

                // MARK: - リセット
                Section {
                    Button(role: .destructive) {
                        APIKeyManager.clearAllKeys()
                        anthropicKey = ""
                        openAIKey = ""
                        geminiKey = ""
                        braveSearchKey = ""
                    } label: {
                        Label("すべてのAPIキーをクリア", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了", action: onDismiss)
                }
            }
        }
    }
}

// MARK: - API Key Row

private struct APIKeyRow: View {
    let label: String
    @Binding var key: String
    @Binding var isVisible: Bool
    let isSet: Bool
    let onSave: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                Spacer()
                if isSet {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            HStack {
                if isVisible {
                    TextField("APIキーを入力", text: $key)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField("APIキーを入力", text: $key)
                        .textContentType(.password)
                }

                Button {
                    isVisible.toggle()
                } label: {
                    Image(systemName: isVisible ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if !key.isEmpty {
                Button("保存") {
                    onSave(key)
                    key = ""
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - Status Row

private struct StatusRow: View {
    let label: String
    let isConfigured: Bool

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            if isConfigured {
                Label("設定済み", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("未設定", systemImage: "xmark.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
    }
}

#Preview {
    ContentView()
}
