//
//  PromptDSLDemo.swift
//  LLMStructuredOutputsExample
//
//  Prompt DSL デモ
//

import SwiftUI
import LLMStructuredOutputs

/// Prompt DSL デモ
///
/// `Prompt` DSL を使った構造化プロンプトの構築を体験できます。
/// 求人情報からスキルを抽出する例で、各コンポーネントの効果を確認します。
struct PromptDSLDemo: View {
    private var settings = AppSettings.shared

    @State private var selectedSampleIndex = 0
    @State private var inputText = JobSkills.sampleInputs[0]
    @State private var state: LoadingState<JobSkills> = .idle
    @State private var tokenUsage: TokenUsage?
    @State private var showingPromptPreview = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - 説明
                DescriptionSection()

                Divider()

                // MARK: - コンポーネント説明
                ComponentsExplanation()

                Divider()

                // MARK: - 使用するプロンプト
                PromptPreviewSection(showingPreview: $showingPromptPreview)

                Divider()

                // MARK: - 入力
                VStack(alignment: .leading, spacing: 12) {
                    SampleInputPicker(
                        samples: JobSkills.sampleInputs,
                        descriptions: JobSkills.sampleDescriptions,
                        selectedIndex: $selectedSampleIndex
                    )
                    .onChange(of: selectedSampleIndex) { _, newValue in
                        inputText = JobSkills.sampleInputs[newValue]
                    }

                    InputTextEditor(
                        title: "求人情報",
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
        .navigationTitle("Prompt DSL")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Prompt Builder

    private func buildPrompt() -> Prompt {
        Prompt {
            PromptComponent.role("人材採用の専門家であり、技術スキルの分析に精通しています")

            PromptComponent.expertise("IT業界の技術スタック")
            PromptComponent.expertise("求人要件の分析と構造化")

            PromptComponent.objective("求人情報からスキル要件を構造化して抽出する")

            PromptComponent.context("日本のIT企業の求人情報が入力されます")

            PromptComponent.instruction("各スキルの必須/歓迎を正確に区別する")
            PromptComponent.instruction("スキルレベルは文脈から適切に判断する")
            PromptComponent.instruction("経験年数が明記されていない場合は推測しない")

            PromptComponent.constraint("求人に記載されていない情報は含めない")
            PromptComponent.constraint("スキルカテゴリは定義された選択肢のみ使用")

            PromptComponent.example(
                input: "必須: Swift 3年以上、歓迎: Kotlin経験",
                output: """
                    [
                      {"name": "Swift", "category": "programming_language", "requiredLevel": "intermediate", "isRequired": true, "yearsOfExperience": 3},
                      {"name": "Kotlin", "category": "programming_language", "requiredLevel": "beginner", "isRequired": false}
                    ]
                    """
            )

            PromptComponent.important("スキルの必須/歓迎の区別は正確に行うこと")
        }
    }

    // MARK: - Actions

    private func executeExtraction() {
        state = .loading
        tokenUsage = nil

        Task {
            do {
                let prompt = buildPrompt()
                let systemPrompt = prompt.render()

                switch settings.selectedProvider {
                case .anthropic:
                    guard let client = settings.createAnthropicClient() else { return }
                    let response: ChatResponse<JobSkills> = try await client.chat(
                        input: LLMInput(inputText),
                        model: settings.claudeModelOption.model,
                        systemPrompt: systemPrompt,
                        temperature: settings.temperature,
                        maxTokens: settings.maxTokens
                    )
                    state = .success(response.result)
                    tokenUsage = response.usage

                case .openai:
                    guard let client = settings.createOpenAIClient() else { return }
                    let response: ChatResponse<JobSkills> = try await client.chat(
                        input: LLMInput(inputText),
                        model: settings.gptModelOption.model,
                        systemPrompt: systemPrompt,
                        temperature: settings.temperature,
                        maxTokens: settings.maxTokens
                    )
                    state = .success(response.result)
                    tokenUsage = response.usage

                case .gemini:
                    guard let client = settings.createGeminiClient() else { return }
                    let response: ChatResponse<JobSkills> = try await client.chat(
                        input: LLMInput(inputText),
                        model: settings.geminiModelOption.model,
                        systemPrompt: systemPrompt,
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
            `Prompt` DSL を使うと、構造化されたプロンプトを宣言的に構築できます。

            役割、専門性、目的、指示、制約、例示などのコンポーネントを組み合わせて、効果的なプロンプトを作成します。
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - ComponentsExplanation

private struct ComponentsExplanation: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("利用可能なコンポーネント")
                .font(.subheadline.bold())

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ComponentChip(name: "role", description: "役割を定義", color: .blue)
                ComponentChip(name: "expertise", description: "専門性を追加", color: .cyan)
                ComponentChip(name: "behavior", description: "振る舞いを指定", color: .teal)
                ComponentChip(name: "objective", description: "目的を明示", color: .green)
                ComponentChip(name: "context", description: "背景を説明", color: .mint)
                ComponentChip(name: "instruction", description: "具体的指示", color: .orange)
                ComponentChip(name: "constraint", description: "制約条件", color: .red)
                ComponentChip(name: "thinkingStep", description: "思考ステップ", color: .purple)
                ComponentChip(name: "reasoning", description: "推論の根拠", color: .indigo)
                ComponentChip(name: "example", description: "入出力例", color: .pink)
                ComponentChip(name: "important", description: "重要事項", color: .yellow)
                ComponentChip(name: "note", description: "補足情報", color: .gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ComponentChip: View {
    let name: String
    let description: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(color)
                .bold()
            Text(description)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - PromptPreviewSection

private struct PromptPreviewSection: View {
    @Binding var showingPreview: Bool

    var body: some View {
        DisclosureGroup("使用するプロンプト（XMLプレビュー）", isExpanded: $showingPreview) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(promptXML)
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

    private var promptXML: String {
        """
        <role>
        人材採用の専門家であり、技術スキルの分析に精通しています
        </role>

        <expertise>
        IT業界の技術スタック
        </expertise>

        <expertise>
        求人要件の分析と構造化
        </expertise>

        <objective>
        求人情報からスキル要件を構造化して抽出する
        </objective>

        <context>
        日本のIT企業の求人情報が入力されます
        </context>

        <instruction>
        各スキルの必須/歓迎を正確に区別する
        </instruction>

        <instruction>
        スキルレベルは文脈から適切に判断する
        </instruction>

        <constraint>
        求人に記載されていない情報は含めない
        </constraint>

        <example>
        Input: 必須: Swift 3年以上、歓迎: Kotlin経験
        Output: [{"name": "Swift", ...}, {"name": "Kotlin", ...}]
        </example>

        <important>
        スキルの必須/歓迎の区別は正確に行うこと
        </important>
        """
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

        // Prompt DSL でプロンプトを構築
        let prompt = Prompt {
            PromptComponent.role("人材採用の専門家")

            PromptComponent.expertise("技術スタックの分析")

            PromptComponent.objective("スキル要件を抽出")

            PromptComponent.instruction("必須/歓迎を区別する")
            PromptComponent.instruction("経験年数を抽出する")

            PromptComponent.constraint("記載情報のみ使用")

            PromptComponent.example(
                input: "必須: Swift 3年",
                output: "[{\"name\": \"Swift\", ...}]"
            )

            PromptComponent.important("正確に分類すること")
        }

        // プロンプトをシステムプロンプトとして使用
        let result: ChatResponse<JobSkills> = try await client.chat(
            input: jobDescription,
            model: .sonnet,
            systemPrompt: prompt.render()
        )
        """
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PromptDSLDemo()
    }
}
