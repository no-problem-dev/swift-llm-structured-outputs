import SwiftUI
import LLMStructuredOutputs

struct UnifiedSettingsView: View {
    enum Tab: String, CaseIterable {
        case session = "セッション"
        case apiKeys = "APIキー"
    }

    @Environment(AppState.self) private var appState
    @Environment(\.useCase) private var useCase
    @State private var selectedTab: Tab = .session

    @Binding var interactiveMode: Bool
    @Binding var outputType: AgentOutputType
    var isSessionDisabled: Bool
    var onModeChange: () -> Void
    var onClearSession: () -> Void
    var onDismiss: () -> Void

    @State private var showInteractiveModeConfirm = false
    @State private var showClearConfirm = false
    @State private var pendingInteractiveMode = false

    @State private var anthropicKey = ""
    @State private var openAIKey = ""
    @State private var geminiKey = ""
    @State private var braveSearchKey = ""
    @State private var showingAnthropicKey = false
    @State private var showingOpenAIKey = false
    @State private var showingGeminiKey = false
    @State private var showingBraveSearchKey = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

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
            Section {
                Picker("LLMプロバイダー", selection: Binding(
                    get: { appState.selectedProvider },
                    set: { appState.setSelectedProvider($0) }
                )) {
                    ForEach(AppState.Provider.allCases) { provider in
                        HStack {
                            Text(provider.rawValue)
                            if hasAPIKey(for: provider) {
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

            Section {
                if appState.selectedProvider == .anthropic {
                    Picker("Claude モデル", selection: Binding(
                        get: { appState.claudeModelOption },
                        set: { appState.setClaudeModelOption($0) }
                    )) {
                        ForEach(AppState.ClaudeModelOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } else if appState.selectedProvider == .openai {
                    Picker("GPT モデル", selection: Binding(
                        get: { appState.gptModelOption },
                        set: { appState.setGPTModelOption($0) }
                    )) {
                        ForEach(AppState.GPTModelOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } else if appState.selectedProvider == .gemini {
                    Picker("Gemini モデル", selection: Binding(
                        get: { appState.geminiModelOption },
                        set: { appState.setGeminiModelOption($0) }
                    )) {
                        ForEach(AppState.GeminiModelOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                }
            } header: {
                Text("モデル")
            }

            Section {
                Stepper(
                    "最大ステップ数: \(appState.maxSteps)",
                    value: Binding(
                        get: { appState.maxSteps },
                        set: { appState.setMaxSteps($0) }
                    ),
                    in: 1...20
                )
            } header: {
                Text("エージェント設定")
            } footer: {
                Text("エージェントが実行できるツール呼び出しの最大回数です。")
            }

            Section {
                APIKeyRow(
                    label: "Anthropic API Key",
                    key: $anthropicKey,
                    isVisible: $showingAnthropicKey,
                    isSet: appState.hasAnthropicKey,
                    onSave: { key in
                        try? useCase.apiKey.set(.anthropic, value: key)
                        appState.syncKeyStatuses(from: useCase.apiKey)
                    }
                )

                APIKeyRow(
                    label: "OpenAI API Key",
                    key: $openAIKey,
                    isVisible: $showingOpenAIKey,
                    isSet: appState.hasOpenAIKey,
                    onSave: { key in
                        try? useCase.apiKey.set(.openai, value: key)
                        appState.syncKeyStatuses(from: useCase.apiKey)
                    }
                )

                APIKeyRow(
                    label: "Gemini API Key",
                    key: $geminiKey,
                    isVisible: $showingGeminiKey,
                    isSet: appState.hasGeminiKey,
                    onSave: { key in
                        try? useCase.apiKey.set(.gemini, value: key)
                        appState.syncKeyStatuses(from: useCase.apiKey)
                    }
                )
            } header: {
                Text("LLM APIキー")
            } footer: {
                Text("少なくとも1つのLLM APIキーが必要です。")
            }

            Section {
                APIKeyRow(
                    label: "Brave Search API Key",
                    key: $braveSearchKey,
                    isVisible: $showingBraveSearchKey,
                    isSet: appState.hasBraveSearchKey,
                    onSave: { key in
                        try? useCase.apiKey.set(.braveSearch, value: key)
                        appState.syncKeyStatuses(from: useCase.apiKey)
                    }
                )
            } header: {
                Text("外部APIキー（オプション）")
            } footer: {
                Text("Brave Search APIキーがない場合、Web検索ツールは利用できません。")
            }

            Section {
                StatusRow(label: "Anthropic", isConfigured: appState.hasAnthropicKey)
                StatusRow(label: "OpenAI", isConfigured: appState.hasOpenAIKey)
                StatusRow(label: "Gemini", isConfigured: appState.hasGeminiKey)
                StatusRow(label: "Brave Search", isConfigured: appState.hasBraveSearchKey)
            } header: {
                Text("APIステータス")
            }

            Section {
                Button(role: .destructive) {
                    try? useCase.apiKey.deleteAll()
                    anthropicKey = ""
                    openAIKey = ""
                    geminiKey = ""
                    braveSearchKey = ""
                    appState.syncKeyStatuses(from: useCase.apiKey)
                } label: {
                    Label("すべてのAPIキーをクリア", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Helpers

    private func hasAPIKey(for provider: AppState.Provider) -> Bool {
        switch provider {
        case .anthropic: return appState.hasAnthropicKey
        case .openai: return appState.hasOpenAIKey
        case .gemini: return appState.hasGeminiKey
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
    .environment(AppState())
}
