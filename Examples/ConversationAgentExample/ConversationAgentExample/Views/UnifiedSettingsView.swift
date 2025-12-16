import SwiftUI

/// 統合設定ビュー
///
/// 「セッション設定」と「APIキー設定」を上タブで切り替えます。
struct UnifiedSettingsView: View {
    enum Tab: String, CaseIterable {
        case session = "セッション"
        case apiKeys = "APIキー"
    }

    @State private var selectedTab: Tab = .session

    // セッション設定用
    @Binding var interactiveMode: Bool
    @Binding var outputType: AgentOutputType
    var isSessionDisabled: Bool
    var onModeChange: () -> Void
    var onClearSession: () -> Void
    var onDismiss: () -> Void

    @State private var showInteractiveModeConfirm = false
    @State private var showClearConfirm = false
    @State private var pendingInteractiveMode = false

    // APIキー設定用
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
            VStack(spacing: 0) {
                // 上タブ
                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // コンテンツ
                switch selectedTab {
                case .session:
                    sessionSettingsContent
                case .apiKeys:
                    apiKeysSettingsContent
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了", action: onDismiss)
                }
            }
            .confirmationDialog(
                "モードを変更",
                isPresented: $showInteractiveModeConfirm,
                titleVisibility: .visible
            ) {
                Button("変更する", role: .destructive) {
                    interactiveMode = pendingInteractiveMode
                    onModeChange()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("モードを変更すると現在の会話履歴がクリアされます。")
            }
            .confirmationDialog(
                "セッションをクリア",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("クリア", role: .destructive) {
                    onClearSession()
                    onDismiss()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("現在の会話履歴がすべて削除されます。この操作は取り消せません。")
            }
        }
    }

    // MARK: - Session Settings

    private var sessionSettingsContent: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("インタラクティブモード")
                        Text(interactiveMode ? "AIが不明点を質問します" : "AIが自動で最後まで実行します")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { interactiveMode },
                        set: { newValue in
                            pendingInteractiveMode = newValue
                            showInteractiveModeConfirm = true
                        }
                    ))
                    .labelsHidden()
                    .disabled(isSessionDisabled)
                }
            } header: {
                Label("動作モード", systemImage: "person.2")
            } footer: {
                Text("モードを変更するとセッションがクリアされます")
            }

            Section {
                ForEach(AgentOutputType.allCases) { type in
                    Button {
                        outputType = type
                    } label: {
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundStyle(type.tintColor)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(type.displayName)
                                    .foregroundStyle(.primary)
                                Text(type.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if outputType == type {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .disabled(isSessionDisabled)
                }
            } header: {
                Label("出力タイプ", systemImage: "doc.text")
            } footer: {
                Text("次の実行時に使用する出力形式を選択します")
            }

            Section {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("セッションをクリア")
                    }
                }
                .disabled(isSessionDisabled)
            } footer: {
                Text("会話履歴がすべて削除されます")
            }
        }
    }

    // MARK: - API Keys Settings

    private var apiKeysSettingsContent: some View {
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
    @Previewable @State var interactive = true
    @Previewable @State var outputType = AgentOutputType.research

    UnifiedSettingsView(
        interactiveMode: $interactive,
        outputType: $outputType,
        isSessionDisabled: false,
        onModeChange: {},
        onClearSession: {},
        onDismiss: {}
    )
}
