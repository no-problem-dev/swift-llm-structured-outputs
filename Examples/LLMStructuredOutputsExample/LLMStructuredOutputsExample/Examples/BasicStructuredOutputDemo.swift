//
//  BasicStructuredOutputDemo.swift
//  LLMStructuredOutputsExample
//
//  基本の構造化出力デモ
//

import SwiftUI
import LLMStructuredOutputs

/// 基本の構造化出力デモ
///
/// `@Structured` マクロを使った基本的な構造化出力を体験できます。
/// 名刺テキストから連絡先情報を抽出する例を示します。
struct BasicStructuredOutputDemo: View {
    private var settings = AppSettings.shared

    @State private var selectedSampleIndex = 0
    @State private var inputText = BusinessCardInfo.sampleInputs[0]
    @State private var state: LoadingState<BusinessCardInfo> = .idle
    @State private var tokenUsage: TokenUsage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - 説明
                DescriptionSection()

                Divider()

                // MARK: - 入力
                VStack(alignment: .leading, spacing: 12) {
                    SampleInputPicker(
                        samples: BusinessCardInfo.sampleInputs,
                        descriptions: BusinessCardInfo.sampleDescriptions,
                        selectedIndex: $selectedSampleIndex
                    )
                    .onChange(of: selectedSampleIndex) { _, newValue in
                        inputText = BusinessCardInfo.sampleInputs[newValue]
                    }

                    InputTextEditor(
                        title: "名刺テキスト",
                        text: $inputText,
                        minHeight: 120
                    )
                }

                // MARK: - 実行
                if settings.isCurrentProviderAvailable {
                    ExecuteButton(
                        isLoading: state.isLoading,
                        isEnabled: !inputText.isEmpty
                    ) {
                        executeExtraction()
                    }
                } else {
                    APIKeyRequiredView(provider: settings.selectedProvider)
                }

                // MARK: - 結果
                ResultDisplayView(state: state, usage: tokenUsage)

                // MARK: - コード例
                CodeExampleSection()
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("基本の構造化出力")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions

    private func executeExtraction() {
        state = .loading
        tokenUsage = nil

        Task {
            do {
                switch settings.selectedProvider {
                case .anthropic:
                    guard let client = settings.createAnthropicClient() else { return }
                    let response: ChatResponse<BusinessCardInfo> = try await client.chat(
                        input: LLMInput(inputText),
                        model: settings.claudeModelOption.model,
                        systemPrompt: "名刺のテキストから情報を抽出してください。",
                        temperature: settings.temperature,
                        maxTokens: settings.maxTokens
                    )
                    state = .success(response.result)
                    tokenUsage = response.usage

                case .openai:
                    guard let client = settings.createOpenAIClient() else { return }
                    let response: ChatResponse<BusinessCardInfo> = try await client.chat(
                        input: LLMInput(inputText),
                        model: settings.gptModelOption.model,
                        systemPrompt: "名刺のテキストから情報を抽出してください。",
                        temperature: settings.temperature,
                        maxTokens: settings.maxTokens
                    )
                    state = .success(response.result)
                    tokenUsage = response.usage

                case .gemini:
                    guard let client = settings.createGeminiClient() else { return }
                    let response: ChatResponse<BusinessCardInfo> = try await client.chat(
                        input: LLMInput(inputText),
                        model: settings.geminiModelOption.model,
                        systemPrompt: "名刺のテキストから情報を抽出してください。",
                        temperature: settings.temperature,
                        maxTokens: settings.maxTokens
                    )
                    state = .success(response.result)
                    tokenUsage = response.usage
                }
            } catch {
                state = .error(error)
            }
        }
    }
}

// MARK: - DescriptionSection

private struct DescriptionSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("このデモについて", systemImage: "info.circle.fill")
                .font(.headline)

            Text("""
            `@Structured` マクロを使って、テキストから構造化されたデータを抽出します。

            この例では、名刺のテキストから以下の情報を自動抽出します：
            • 氏名、会社名、部署、役職
            • メールアドレス、電話番号
            • 住所、Webサイト
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - CodeExampleSection

private struct CodeExampleSection: View {
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup("コード例", isExpanded: $isExpanded) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(codeExample)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
    }

    private var codeExample: String {
        """
        import LLMStructuredOutputs

        // 構造化出力の型を定義
        @Structured("名刺から抽出した連絡先情報")
        struct BusinessCardInfo {
            @StructuredField("氏名")
            var name: String

            @StructuredField("会社名")
            var company: String?

            @StructuredField("メールアドレス", .format(.email))
            var email: String?

            @StructuredField("電話番号")
            var phone: String?
        }

        // クライアントを作成して実行
        let client = AnthropicClient(apiKey: "sk-ant-...")
        let result: BusinessCardInfo = try await client.generate(
            input: "名刺のテキスト...",
            model: .sonnet
        )

        print(result.name)    // "山田太郎"
        print(result.company) // "株式会社テック"
        """
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BasicStructuredOutputDemo()
    }
}
