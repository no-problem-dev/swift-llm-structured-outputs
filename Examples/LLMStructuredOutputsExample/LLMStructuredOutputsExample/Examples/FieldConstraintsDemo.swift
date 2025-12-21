//
//  FieldConstraintsDemo.swift
//  LLMStructuredOutputsExample
//
//  制約の活用デモ
//

import SwiftUI
import LLMStructuredOutputs

/// 制約の活用デモ
///
/// `@StructuredField` の制約オプションを体験できます。
/// 商品レビューの解析を例に、最小値・最大値・文字数制限などを活用します。
struct FieldConstraintsDemo: View {
    private var settings = AppSettings.shared

    @State private var selectedSampleIndex = 0
    @State private var inputText = ProductReview.sampleInputs[0]
    @State private var state: LoadingState<ProductReview> = .idle
    @State private var tokenUsage: TokenUsage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - 説明
                DescriptionSection()

                Divider()

                // MARK: - 制約の説明
                ConstraintsExplanation()

                Divider()

                // MARK: - 入力
                VStack(alignment: .leading, spacing: 12) {
                    SampleInputPicker(
                        samples: ProductReview.sampleInputs,
                        descriptions: ProductReview.sampleDescriptions,
                        selectedIndex: $selectedSampleIndex
                    )
                    .onChange(of: selectedSampleIndex) { _, newValue in
                        inputText = ProductReview.sampleInputs[newValue]
                    }

                    InputTextEditor(
                        title: "レビューテキスト",
                        text: $inputText,
                        minHeight: 150
                    )
                }

                // MARK: - 実行
                if settings.isCurrentProviderAvailable {
                    ExecuteButton(
                        isLoading: state.isLoading,
                        isEnabled: !inputText.isEmpty
                    ) {
                        executeAnalysis()
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
        .navigationTitle("制約の活用")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions

    private func executeAnalysis() {
        state = .loading
        tokenUsage = nil

        Task {
            do {
                switch settings.selectedProvider {
                case .anthropic:
                    guard let client = settings.createAnthropicClient() else { return }
                    let response: ChatResponse<ProductReview> = try await client.chat(
                        input: LLMInput(inputText),
                        model: settings.claudeModelOption.model,
                        systemPrompt: "商品レビューを解析し、評価情報を抽出してください。",
                        temperature: settings.temperature,
                        maxTokens: settings.maxTokens
                    )
                    state = .success(response.result)
                    tokenUsage = response.usage

                case .openai:
                    guard let client = settings.createOpenAIClient() else { return }
                    let response: ChatResponse<ProductReview> = try await client.chat(
                        input: LLMInput(inputText),
                        model: settings.gptModelOption.model,
                        systemPrompt: "商品レビューを解析し、評価情報を抽出してください。",
                        temperature: settings.temperature,
                        maxTokens: settings.maxTokens
                    )
                    state = .success(response.result)
                    tokenUsage = response.usage

                case .gemini:
                    guard let client = settings.createGeminiClient() else { return }
                    let response: ChatResponse<ProductReview> = try await client.chat(
                        input: LLMInput(inputText),
                        model: settings.geminiModelOption.model,
                        systemPrompt: "商品レビューを解析し、評価情報を抽出してください。",
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
            `@StructuredField` に制約を追加することで、出力値の範囲や形式を制御できます。

            この例では、商品レビューを解析し、以下の制約付きで情報を抽出します：
            • 評価: 1〜5の範囲（minimum/maximum）
            • 要約: 10〜200文字（minLength/maxLength）
            • タグ: 1〜5個（minItems/maxItems）
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - ConstraintsExplanation

private struct ConstraintsExplanation: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("使用している制約")
                .font(.subheadline.bold())

            VStack(alignment: .leading, spacing: 8) {
                ConstraintRow(
                    name: ".minimum(1), .maximum(5)",
                    description: "評価値を1〜5に制限"
                )
                ConstraintRow(
                    name: ".minLength(10), .maxLength(200)",
                    description: "要約を10〜200文字に制限"
                )
                ConstraintRow(
                    name: ".minItems(1), .maxItems(5)",
                    description: "配列の要素数を1〜5に制限"
                )
                ConstraintRow(
                    name: ".enum([...])",
                    description: "選択肢を限定（感情分析）"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ConstraintRow: View {
    let name: String
    let description: String

    var body: some View {
        HStack(alignment: .top) {
            Text(name)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.blue)
                .frame(width: 200, alignment: .leading)

            Text(description)
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
        @Structured("商品レビューの解析結果")
        struct ProductReview {
            @StructuredField("商品名")
            var productName: String

            // 数値制約: 1〜5の範囲
            @StructuredField("総合評価", .minimum(1), .maximum(5))
            var rating: Int

            // 文字数制約: 10〜200文字
            @StructuredField("要約", .minLength(10), .maxLength(200))
            var summary: String

            // 配列制約: 1〜5個
            @StructuredField("良い点", .minItems(1), .maxItems(5))
            var pros: [String]

            // 列挙制約: 選択肢を限定
            @StructuredField("感情", .enum(["満足", "普通", "不満"]))
            var sentiment: String
        }
        """
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FieldConstraintsDemo()
    }
}
