//
//  EnumSupportDemo.swift
//  LLMStructuredOutputsExample
//
//  Enum対応デモ
//

import SwiftUI
import LLMStructuredOutputs

/// Enum対応デモ
///
/// `@StructuredEnum` と `@StructuredCase` マクロを体験できます。
/// タスク情報の分類を例に、選択肢を限定した出力を行います。
struct EnumSupportDemo: View {
    private var settings = AppSettings.shared

    @State private var selectedSampleIndex = 0
    @State private var inputText = TaskInfo.sampleInputs[0]
    @State private var state: LoadingState<TaskInfo> = .idle
    @State private var tokenUsage: TokenUsage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - 説明
                DescriptionSection()

                Divider()

                // MARK: - Enum定義の説明
                EnumDefinitionSection()

                Divider()

                // MARK: - 入力
                VStack(alignment: .leading, spacing: 12) {
                    SampleInputPicker(
                        samples: TaskInfo.sampleInputs,
                        descriptions: TaskInfo.sampleDescriptions,
                        selectedIndex: $selectedSampleIndex
                    )
                    .onChange(of: selectedSampleIndex) { _, newValue in
                        inputText = TaskInfo.sampleInputs[newValue]
                    }

                    InputTextEditor(
                        title: "タスク説明",
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
                        executeClassification()
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
        .navigationTitle("Enum対応")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions

    private func executeClassification() {
        state = .loading
        tokenUsage = nil

        Task {
            do {
                let systemPrompt = """
                タスクの説明文を解析し、以下の情報を抽出してください：
                - タイトル、詳細説明
                - 優先度（low/medium/high/critical）
                - ステータス（not_started/in_progress/pending/completed/blocked）
                - カテゴリ（feature/bugfix/documentation/refactoring/testing/infrastructure）
                - 担当者、期限、見積もり工数
                """

                switch settings.selectedProvider {
                case .anthropic:
                    guard let client = settings.createAnthropicClient() else { return }
                    let response: ChatResponse<TaskInfo> = try await client.chat(
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
                    let response: ChatResponse<TaskInfo> = try await client.chat(
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
                    let response: ChatResponse<TaskInfo> = try await client.chat(
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
            `@StructuredEnum` と `@StructuredCase` を使って、出力を特定の選択肢に限定できます。

            この例では、タスクの説明文から以下を分類します：
            • 優先度: low / medium / high / critical
            • ステータス: not_started / in_progress / pending / completed / blocked
            • カテゴリ: feature / bugfix / documentation など
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - EnumDefinitionSection

private struct EnumDefinitionSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("定義されているEnum")
                .font(.subheadline.bold())

            VStack(alignment: .leading, spacing: 12) {
                EnumPreview(
                    name: "TaskPriority",
                    cases: ["low", "medium", "high", "critical"],
                    color: .orange
                )

                EnumPreview(
                    name: "TaskStatus",
                    cases: ["not_started", "in_progress", "pending", "completed", "blocked"],
                    color: .blue
                )

                EnumPreview(
                    name: "TaskCategory",
                    cases: ["feature", "bugfix", "documentation", "refactoring", "testing", "infrastructure"],
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct EnumPreview: View {
    let name: String
    let cases: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(color)
                .bold()

            FlowLayout(spacing: 4) {
                ForEach(cases, id: \.self) { caseName in
                    Text(caseName)
                        .font(.system(.caption2, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }
}

/// 簡易的なFlowLayout
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > width, x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: width, height: y + lineHeight)
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
        // Enumを定義（各ケースに説明を付与）
        @StructuredEnum("タスクの優先度")
        enum TaskPriority: String {
            @StructuredCase("緊急ではないタスク")
            case low

            @StructuredCase("通常の優先度")
            case medium

            @StructuredCase("重要度が高いタスク")
            case high

            @StructuredCase("最優先の緊急タスク")
            case critical
        }

        // 構造体でEnumを使用
        @Structured("タスク情報")
        struct TaskInfo {
            @StructuredField("タイトル")
            var title: String

            @StructuredField("優先度")
            var priority: TaskPriority

            @StructuredField("ステータス")
            var status: TaskStatus
        }

        // 使用例
        let task: TaskInfo = try await client.generate(
            prompt: "バグ修正タスクの説明...",
            model: .sonnet
        )
        print(task.priority)  // .high
        """
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EnumSupportDemo()
    }
}
