//
//  PromptBuilderDemo.swift
//  LLMStructuredOutputsExample
//
//  インタラクティブ Prompt Builder デモ
//

import SwiftUI
import LLMStructuredOutputs

/// インタラクティブ Prompt Builder デモ
///
/// プロンプトコンポーネントを自由に追加・削除して、
/// 出力の変化をリアルタイムで確認できます。
struct PromptBuilderDemo: View {
    private var settings = AppSettings.shared

    // 入力テキスト
    @State private var inputText = "山田太郎さん（35歳）はITエンジニアで、東京のスタートアップで働いています。"

    // 追加済みコンポーネント
    @State private var components: [EditableComponent] = []

    // 結果
    @State private var state: LoadingState<BusinessCardInfo> = .idle
    @State private var tokenUsage: TokenUsage?

    // シート
    @State private var showingAddSheet = false
    @State private var showingPromptPreview = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - 説明
                DescriptionSection()

                Divider()

                // MARK: - 入力テキスト
                InputTextEditor(
                    title: "抽出対象テキスト",
                    text: $inputText,
                    minHeight: 80
                )

                Divider()

                // MARK: - コンポーネント管理
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("プロンプトコンポーネント")
                            .font(.subheadline.bold())

                        Spacer()

                        Button {
                            showingAddSheet = true
                        } label: {
                            Label("追加", systemImage: "plus.circle.fill")
                                .font(.caption)
                        }
                    }

                    if components.isEmpty {
                        EmptyComponentsView()
                    } else {
                        ComponentListView(components: $components)
                    }

                    // プレビューボタン
                    Button {
                        showingPromptPreview = true
                    } label: {
                        Label("XMLプレビュー", systemImage: "eye")
                            .font(.caption)
                    }
                    .disabled(components.isEmpty)
                }

                Divider()

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

                // MARK: - ヒント
                TipsSection()
            }
            .padding()
        }
        .navigationTitle("Prompt Builder")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddSheet) {
            AddComponentSheet(components: $components)
        }
        .sheet(isPresented: $showingPromptPreview) {
            PromptPreviewSheet(components: components)
        }
    }

    // MARK: - Actions

    private func buildPrompt() -> Prompt {
        let promptComponents = components.map { $0.toPromptComponent() }
        return Prompt(components: promptComponents)
    }

    private func executeExtraction() {
        state = .loading
        tokenUsage = nil

        Task {
            do {
                let systemPrompt: String?
                if components.isEmpty {
                    systemPrompt = "テキストから人物情報を抽出してください。"
                } else {
                    systemPrompt = buildPrompt().render()
                }

                switch settings.selectedProvider {
                case .anthropic:
                    guard let client = settings.createAnthropicClient() else { return }
                    let response: ChatResponse<BusinessCardInfo> = try await client.chat(
                        prompt: inputText,
                        model: settings.claudeModelOption.model,
                        systemPrompt: systemPrompt,
                        temperature: settings.temperature,
                        maxTokens: settings.maxTokens
                    )
                    state = .success(response.result)
                    tokenUsage = response.usage

                case .openai:
                    guard let client = settings.createOpenAIClient() else { return }
                    let response: ChatResponse<BusinessCardInfo> = try await client.chat(
                        prompt: inputText,
                        model: settings.gptModelOption.model,
                        systemPrompt: systemPrompt,
                        temperature: settings.temperature,
                        maxTokens: settings.maxTokens
                    )
                    state = .success(response.result)
                    tokenUsage = response.usage

                case .gemini:
                    guard let client = settings.createGeminiClient() else { return }
                    let response: ChatResponse<BusinessCardInfo> = try await client.chat(
                        prompt: inputText,
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

// MARK: - EditableComponent

/// 編集可能なコンポーネント
struct EditableComponent: Identifiable {
    let id = UUID()
    var type: ComponentType
    var value: String
    var exampleOutput: String? // exampleの場合のみ

    enum ComponentType: String, CaseIterable {
        case role = "役割"
        case expertise = "専門性"
        case behavior = "振る舞い"
        case objective = "目的"
        case context = "コンテキスト"
        case instruction = "指示"
        case constraint = "制約"
        case thinkingStep = "思考ステップ"
        case reasoning = "推論"
        case example = "例"
        case important = "重要事項"
        case note = "補足"

        var icon: String {
            switch self {
            case .role: return "person.fill"
            case .expertise: return "star.fill"
            case .behavior: return "figure.walk"
            case .objective: return "target"
            case .context: return "doc.text.fill"
            case .instruction: return "list.bullet"
            case .constraint: return "exclamationmark.triangle.fill"
            case .thinkingStep: return "brain"
            case .reasoning: return "lightbulb.fill"
            case .example: return "rectangle.and.pencil.and.ellipsis"
            case .important: return "exclamationmark.circle.fill"
            case .note: return "note.text"
            }
        }

        var color: Color {
            switch self {
            case .role: return .blue
            case .expertise: return .cyan
            case .behavior: return .teal
            case .objective: return .green
            case .context: return .mint
            case .instruction: return .orange
            case .constraint: return .red
            case .thinkingStep: return .purple
            case .reasoning: return .indigo
            case .example: return .pink
            case .important: return .yellow
            case .note: return .gray
            }
        }
    }

    func toPromptComponent() -> PromptComponent {
        switch type {
        case .role: return .role(value)
        case .expertise: return .expertise(value)
        case .behavior: return .behavior(value)
        case .objective: return .objective(value)
        case .context: return .context(value)
        case .instruction: return .instruction(value)
        case .constraint: return .constraint(value)
        case .thinkingStep: return .thinkingStep(value)
        case .reasoning: return .reasoning(value)
        case .example: return .example(input: value, output: exampleOutput ?? "")
        case .important: return .important(value)
        case .note: return .note(value)
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
            プロンプトコンポーネントを自由に追加・削除して、出力への影響を確認できます。

            コンポーネントを追加するほど、より詳細で正確な抽出が期待できますが、トークン消費も増えます。
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - EmptyComponentsView

private struct EmptyComponentsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.rectangle.on.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("コンポーネントを追加してください")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("追加なしでも実行可能です")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - ComponentListView

private struct ComponentListView: View {
    @Binding var components: [EditableComponent]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(components.enumerated()), id: \.element.id) { index, component in
                ComponentRow(component: component) {
                    components.remove(at: index)
                }
            }
        }
    }
}

private struct ComponentRow: View {
    let component: EditableComponent
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: component.type.icon)
                .foregroundStyle(component.type.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(component.type.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(component.type.color)

                Text(component.value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red.opacity(0.7))
            }
        }
        .padding(8)
        .background(component.type.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - AddComponentSheet

private struct AddComponentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var components: [EditableComponent]

    @State private var selectedType: EditableComponent.ComponentType = .role
    @State private var value = ""
    @State private var exampleOutput = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("コンポーネントの種類") {
                    Picker("種類", selection: $selectedType) {
                        ForEach(EditableComponent.ComponentType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("内容") {
                    TextField("値を入力", text: $value, axis: .vertical)
                        .lineLimit(3...6)

                    if selectedType == .example {
                        TextField("期待する出力", text: $exampleOutput, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }

                Section("プリセット") {
                    ForEach(presets, id: \.value) { preset in
                        Button {
                            selectedType = preset.type
                            value = preset.value
                            exampleOutput = preset.exampleOutput ?? ""
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Image(systemName: preset.type.icon)
                                        .foregroundStyle(preset.type.color)
                                    Text(preset.type.rawValue)
                                        .font(.caption.bold())
                                }
                                Text(preset.value)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("コンポーネント追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let component = EditableComponent(
                            type: selectedType,
                            value: value,
                            exampleOutput: selectedType == .example ? exampleOutput : nil
                        )
                        components.append(component)
                        dismiss()
                    }
                    .disabled(value.isEmpty)
                }
            }
        }
    }

    private var presets: [EditableComponent] {
        [
            EditableComponent(type: .role, value: "情報抽出の専門家"),
            EditableComponent(type: .objective, value: "テキストから人物情報を正確に抽出する"),
            EditableComponent(type: .instruction, value: "名前は敬称（さん、様）を除いて抽出する"),
            EditableComponent(type: .instruction, value: "年齢は数値のみ抽出する"),
            EditableComponent(type: .constraint, value: "テキストに記載されていない情報は推測しない"),
            EditableComponent(type: .important, value: "不明な項目はnullを返すこと"),
        ]
    }
}

// MARK: - PromptPreviewSheet

private struct PromptPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let components: [EditableComponent]

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(renderedPrompt)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
            }
            .navigationTitle("XMLプレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var renderedPrompt: String {
        let promptComponents = components.map { $0.toPromptComponent() }
        return Prompt(components: promptComponents).render()
    }
}

// MARK: - TipsSection

private struct TipsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tips", systemImage: "lightbulb.fill")
                .font(.caption.bold())
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 4) {
                Text("• コンポーネントなしで実行すると、シンプルなプロンプトで抽出されます")
                Text("• role + objective + instruction の組み合わせが基本です")
                Text("• constraint を追加すると、不要な推測を抑制できます")
                Text("• example を追加すると、出力形式が安定します")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PromptBuilderDemo()
    }
}
