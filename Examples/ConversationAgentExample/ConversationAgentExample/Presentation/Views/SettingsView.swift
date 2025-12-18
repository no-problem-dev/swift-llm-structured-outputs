import SwiftUI
import LLMClient

struct SettingsView: View {
    var onDismiss: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.useCase) private var useCase
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
            Form {
                providerSection
                modelSection
                agentConfigSection
                llmAPIKeysSection
                externalAPIKeysSection
                statusSection
                resetSection
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

    // MARK: - Provider Section

    private var providerSection: some View {
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
    }

    // MARK: - Model Section

    private var modelSection: some View {
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
    }

    // MARK: - Agent Config Section

    private var agentConfigSection: some View {
        Section {
            Stepper(
                "最大ステップ数: \(appState.maxSteps)",
                value: Binding(
                    get: { appState.maxSteps },
                    set: { appState.setMaxSteps($0) }
                ),
                in: 1...50
            )
        } header: {
            Text("エージェント設定")
        } footer: {
            Text("エージェントが実行できるツール呼び出しの最大回数です。Web検索とFetchを組み合わせる場合は30以上推奨。")
        }
    }

    // MARK: - LLM API Keys Section

    private var llmAPIKeysSection: some View {
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
    }

    // MARK: - External API Keys Section

    private var externalAPIKeysSection: some View {
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
    }

    // MARK: - Status Section

    private var statusSection: some View {
        Section {
            StatusRow(label: "Anthropic", isConfigured: appState.hasAnthropicKey)
            StatusRow(label: "OpenAI", isConfigured: appState.hasOpenAIKey)
            StatusRow(label: "Gemini", isConfigured: appState.hasGeminiKey)
            StatusRow(label: "Brave Search", isConfigured: appState.hasBraveSearchKey)
        } header: {
            Text("APIステータス")
        }
    }

    // MARK: - Reset Section

    private var resetSection: some View {
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
    SettingsView(onDismiss: {})
        .environment(AppState())
}
