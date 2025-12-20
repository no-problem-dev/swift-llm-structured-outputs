import SwiftUI
import ExamplesCommon

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.useCase) private var useCase
    @Environment(\.dismiss) private var dismiss

    @State private var anthropicKey: String = ""
    @State private var openaiKey: String = ""
    @State private var geminiKey: String = ""
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                // API Keys
                Section {
                    APIKeyField(
                        title: "Anthropic",
                        placeholder: "sk-ant-...",
                        text: $anthropicKey,
                        hasKey: appState.hasAnthropicKey
                    )

                    APIKeyField(
                        title: "OpenAI",
                        placeholder: "sk-...",
                        text: $openaiKey,
                        hasKey: appState.hasOpenAIKey
                    )

                    APIKeyField(
                        title: "Google Gemini",
                        placeholder: "AIza...",
                        text: $geminiKey,
                        hasKey: appState.hasGeminiKey
                    )
                } header: {
                    Text("API Keys")
                } footer: {
                    Text("APIキーは安全にKeychainに保存されます。\n環境変数で設定済みの場合は入力不要です。")
                }

                // Provider Selection
                Section("デフォルトプロバイダー") {
                    Picker("プロバイダー", selection: Binding(
                        get: { appState.selectedProvider },
                        set: { appState.setSelectedProvider($0) }
                    )) {
                        ForEach(LLMProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Model Selection
                Section("モデル") {
                    switch appState.selectedProvider {
                    case .anthropic:
                        Picker("Claude Model", selection: Binding(
                            get: { appState.claudeModelOption },
                            set: { appState.setClaudeModelOption($0) }
                        )) {
                            ForEach(AppState.ClaudeModelOption.allCases, id: \.self) { option in
                                Text(option.shortName).tag(option)
                            }
                        }

                    case .openai:
                        Picker("GPT Model", selection: Binding(
                            get: { appState.gptModelOption },
                            set: { appState.setGPTModelOption($0) }
                        )) {
                            ForEach(AppState.GPTModelOption.allCases, id: \.self) { option in
                                Text(option.shortName).tag(option)
                            }
                        }

                    case .gemini:
                        Picker("Gemini Model", selection: Binding(
                            get: { appState.geminiModelOption },
                            set: { appState.setGeminiModelOption($0) }
                        )) {
                            ForEach(AppState.GeminiModelOption.allCases, id: \.self) { option in
                                Text(option.shortName).tag(option)
                            }
                        }
                    }
                }

                // Agent Configuration
                Section("エージェント設定") {
                    HStack {
                        Text("最大ステップ数")
                        Spacer()
                        TextField("30", value: Binding(
                            get: { appState.maxSteps },
                            set: { appState.setMaxSteps($0) }
                        ), format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    }

                    HStack {
                        Text("最大トークン数")
                        Spacer()
                        TextField("16384", value: Binding(
                            get: { appState.maxTokens },
                            set: { appState.setMaxTokens($0) }
                        ), format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    }
                }

                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        deleteAllKeys()
                    } label: {
                        Label("全てのAPIキーを削除", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        saveAndDismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentKeys()
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Actions

    private func loadCurrentKeys() {
        // 現在保存されているキーをマスク表示用に読み込み
        // 実際のキーは表示しない（セキュリティ）
    }

    private func saveAndDismiss() {
        saveKeys()
        dismiss()
    }

    private func saveKeys() {
        do {
            if !anthropicKey.isEmpty {
                try useCase.apiKey.set(.anthropic, value: anthropicKey)
                appState.setAnthropicKeyStatus(true)
            }

            if !openaiKey.isEmpty {
                try useCase.apiKey.set(.openai, value: openaiKey)
                appState.setOpenAIKeyStatus(true)
            }

            if !geminiKey.isEmpty {
                try useCase.apiKey.set(.gemini, value: geminiKey)
                appState.setGeminiKeyStatus(true)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func deleteAllKeys() {
        do {
            try useCase.apiKey.deleteAll()
            appState.setAnthropicKeyStatus(false)
            appState.setOpenAIKeyStatus(false)
            appState.setGeminiKeyStatus(false)
            anthropicKey = ""
            openaiKey = ""
            geminiKey = ""
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - APIKeyField

struct APIKeyField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let hasKey: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)

                Spacer()

                if hasKey {
                    Label("設定済み", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }

            SecureField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
