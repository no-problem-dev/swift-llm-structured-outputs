//
//  SettingsView.swift
//  LLMStructuredOutputsExample
//
//  アプリ設定画面
//

import SwiftUI
import LLMStructuredOutputs

/// 設定画面
///
/// プロバイダー、モデル、生成パラメータ、APIキーを設定します。
/// 設定はアプリ全体で共有され、すべてのデモに反映されます。
struct SettingsView: View {
    @Bindable private var settings = AppSettings.shared
    @State private var showingAPIKeyGuide = false
    @State private var showingAPIKeyEditor = false

    var body: some View {
        Form {
            // MARK: - プロバイダー選択
            Section {
                ForEach(AppSettings.Provider.allCases) { provider in
                    HStack {
                        Button {
                            settings.selectedProvider = provider
                        } label: {
                            HStack {
                                Image(systemName: settings.selectedProvider == provider ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(settings.selectedProvider == provider ? .blue : .secondary)

                                Text(provider.rawValue)
                                    .foregroundStyle(.primary)

                                Spacer()

                                // APIキー状態
                                if provider.hasAPIKey {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                } else {
                                    Text("未設定")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("プロバイダー")
            } footer: {
                Text("使用するLLMプロバイダーを選択してください")
            }

            // MARK: - モデル選択
            Section {
                switch settings.selectedProvider {
                case .anthropic:
                    Picker("モデル", selection: $settings.claudeModelOption) {
                        ForEach(AppSettings.ClaudeModelOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.navigationLink)

                case .openai:
                    Picker("モデル", selection: $settings.gptModelOption) {
                        ForEach(AppSettings.GPTModelOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.navigationLink)

                case .gemini:
                    Picker("モデル", selection: $settings.geminiModelOption) {
                        ForEach(AppSettings.GeminiModelOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            } header: {
                Text("モデル選択")
            }

            // MARK: - 生成パラメータ
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text(String(format: "%.1f", settings.temperature))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.temperature, in: 0...1, step: 0.1)
                }

                HStack {
                    Text("最大トークン数")
                    Spacer()
                    TextField("", value: $settings.maxTokens, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            } header: {
                Text("生成パラメータ")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Temperature: 0.0（決定的）〜 1.0（創造的）")
                    Text("最大トークン数: 生成される出力の最大長")
                }
            }

            // MARK: - APIキー設定
            Section {
                APIKeyStatusRow(
                    provider: "Anthropic",
                    isConfigured: APIKeyManager.hasAnthropicKey,
                    source: APIKeyManager.anthropicKeySource
                )
                APIKeyStatusRow(
                    provider: "OpenAI",
                    isConfigured: APIKeyManager.hasOpenAIKey,
                    source: APIKeyManager.openAIKeySource
                )
                APIKeyStatusRow(
                    provider: "Gemini",
                    isConfigured: APIKeyManager.hasGeminiKey,
                    source: APIKeyManager.geminiKeySource
                )

                Button {
                    showingAPIKeyEditor = true
                } label: {
                    Label("APIキーを編集", systemImage: "key.fill")
                }

                Button {
                    showingAPIKeyGuide = true
                } label: {
                    Label("設定方法を見る", systemImage: "questionmark.circle")
                }
            } header: {
                Text("APIキー")
            } footer: {
                let status = APIKeyManager.status
                Text("\(status.configuredCount)/3 のプロバイダーが設定済み")
            }
        }
        .navigationTitle("設定")
        .sheet(isPresented: $showingAPIKeyGuide) {
            APIKeyGuideView()
        }
        .sheet(isPresented: $showingAPIKeyEditor) {
            APIKeyEditorView()
        }
    }
}

// MARK: - APIKeyStatusRow

/// APIキー状態の行
private struct APIKeyStatusRow: View {
    let provider: String
    let isConfigured: Bool
    let source: APIKeyManager.KeySource

    var body: some View {
        HStack {
            Text(provider)
            Spacer()
            if isConfigured {
                HStack(spacing: 4) {
                    Text(sourceLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            } else {
                Label("未設定", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
    }

    private var sourceLabel: String {
        switch source {
        case .environment:
            return "環境変数"
        case .userDefaults:
            return "保存済み"
        case .notSet:
            return ""
        }
    }
}

// MARK: - APIKeyEditorView

/// APIキー編集画面
struct APIKeyEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var anthropicKey: String = ""
    @State private var openAIKey: String = ""
    @State private var geminiKey: String = ""
    @State private var showingClearConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureInputField(
                        title: "Anthropic API Key",
                        placeholder: "sk-ant-...",
                        text: $anthropicKey,
                        isConfigured: APIKeyManager.hasAnthropicKey
                    )
                } header: {
                    Text("Anthropic")
                } footer: {
                    Text("Claude モデルに使用")
                }

                Section {
                    SecureInputField(
                        title: "OpenAI API Key",
                        placeholder: "sk-...",
                        text: $openAIKey,
                        isConfigured: APIKeyManager.hasOpenAIKey
                    )
                } header: {
                    Text("OpenAI")
                } footer: {
                    Text("GPT モデルに使用")
                }

                Section {
                    SecureInputField(
                        title: "Gemini API Key",
                        placeholder: "AIza...",
                        text: $geminiKey,
                        isConfigured: APIKeyManager.hasGeminiKey
                    )
                } header: {
                    Text("Google")
                } footer: {
                    Text("Gemini モデルに使用")
                }

                Section {
                    Button(role: .destructive) {
                        showingClearConfirm = true
                    } label: {
                        Label("すべてのAPIキーをクリア", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("APIキー編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveKeys()
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "すべてのAPIキーを削除しますか？",
                isPresented: $showingClearConfirm,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    APIKeyManager.clearAllKeys()
                    anthropicKey = ""
                    openAIKey = ""
                    geminiKey = ""
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    private func saveKeys() {
        // 入力があった場合のみ保存（空欄は既存のキーを維持）
        if !anthropicKey.isEmpty {
            APIKeyManager.setAnthropicKey(anthropicKey)
        }
        if !openAIKey.isEmpty {
            APIKeyManager.setOpenAIKey(openAIKey)
        }
        if !geminiKey.isEmpty {
            APIKeyManager.setGeminiKey(geminiKey)
        }
    }
}

// MARK: - SecureInputField

/// セキュアな入力フィールド
private struct SecureInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let isConfigured: Bool

    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if isRevealed {
                    TextField(placeholder, text: $text)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } else {
                    SecureField(placeholder, text: $text)
                        .textContentType(.password)
                }

                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if isConfigured && text.isEmpty {
                Text("設定済み（変更する場合のみ入力）")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
}
