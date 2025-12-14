//
//  AgentRunnerView.swift
//  AgentExample
//
//  エージェント実行画面
//

import SwiftUI
import LLMStructuredOutputs

/// エージェント実行画面
///
/// リサーチエージェントを実行し、ステップごとの進行状況を可視化します。
struct AgentRunnerView: View {
    private var settings = AgentSettings.shared

    @State private var selectedScenarioIndex = 0
    @State private var inputText = ResearchScenario.scenarios[0].prompt
    @State private var state: AgentExecutionState = .idle
    @State private var steps: [AgentStepInfo] = []
    @State private var isRunning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - ヘッダー
                HeaderSection()

                Divider()

                // MARK: - ツール一覧
                ToolsSection()

                Divider()

                // MARK: - シナリオ選択
                ScenarioSection(
                    selectedIndex: $selectedScenarioIndex,
                    inputText: $inputText
                )

                // MARK: - 入力
                InputSection(inputText: $inputText)

                // MARK: - 実行ボタン
                ExecutionSection(
                    isRunning: isRunning,
                    canExecute: canExecute,
                    onExecute: executeAgent
                )

                // MARK: - 結果表示
                if !state.isIdle {
                    ResultSection(state: state, steps: steps)
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("リサーチエージェント")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Computed Properties

    private var canExecute: Bool {
        !inputText.isEmpty && settings.isCurrentProviderAvailable && !isRunning
    }

    // MARK: - Actions

    private func executeAgent() {
        state = .loading
        steps = []
        isRunning = true

        let tools = ResearchToolSet.tools

        Task {
            do {
                switch settings.selectedProvider {
                case .anthropic:
                    guard let client = settings.createAnthropicClient() else {
                        state = .error("Anthropic クライアントの作成に失敗しました")
                        isRunning = false
                        return
                    }
                    try await runAnthropicAgent(client: client, tools: tools)

                case .openai:
                    guard let client = settings.createOpenAIClient() else {
                        state = .error("OpenAI クライアントの作成に失敗しました")
                        isRunning = false
                        return
                    }
                    try await runOpenAIAgent(client: client, tools: tools)
                }
            } catch {
                state = .error(error.localizedDescription)
            }
            isRunning = false
        }
    }

    private func runAnthropicAgent(client: AnthropicClient, tools: ToolSet) async throws {
        let systemPrompt = ResearchAgentPrompt.build()
        let config = settings.createAgentConfiguration()

        let agentSequence: AgentStepSequence<AnthropicClient, ResearchReport> = client.runAgent(
            prompt: inputText,
            model: settings.claudeModelOption.model,
            tools: tools,
            systemPrompt: systemPrompt,
            configuration: config
        )

        var finalResult: ResearchReport?

        for try await step in agentSequence {
            let stepInfo = processStep(step)
            await MainActor.run {
                steps.append(stepInfo)
            }

            if case .finalResponse(let report) = step {
                finalResult = report
            }
        }

        if let result = finalResult {
            state = .success(result)
        } else {
            state = .error("最終レスポンスが取得できませんでした")
        }
    }

    private func runOpenAIAgent(client: OpenAIClient, tools: ToolSet) async throws {
        let systemPrompt = ResearchAgentPrompt.build()
        let config = settings.createAgentConfiguration()

        let agentSequence: AgentStepSequence<OpenAIClient, ResearchReport> = client.runAgent(
            prompt: inputText,
            model: settings.gptModelOption.model,
            tools: tools,
            systemPrompt: systemPrompt,
            configuration: config
        )

        var finalResult: ResearchReport?

        for try await step in agentSequence {
            let stepInfo = processStep(step)
            await MainActor.run {
                steps.append(stepInfo)
            }

            if case .finalResponse(let report) = step {
                finalResult = report
            }
        }

        if let result = finalResult {
            state = .success(result)
        } else {
            state = .error("最終レスポンスが取得できませんでした")
        }
    }

    private func processStep(_ step: AgentStep<ResearchReport>) -> AgentStepInfo {
        switch step {
        case .thinking(let response):
            let text = response.content.compactMap { $0.text }.joined()
            return AgentStepInfo(
                type: .thinking,
                content: text.isEmpty ? "（考え中...）" : text
            )

        case .toolCall(let info):
            return AgentStepInfo(
                type: .toolCall,
                content: info.name,
                detail: formatToolInput(info.input)
            )

        case .toolResult(let info):
            // 全文を渡す（表示側で折りたたみ処理）
            return AgentStepInfo(
                type: .toolResult,
                content: info.content,
                isError: info.isError
            )

        case .finalResponse(let report):
            return AgentStepInfo(
                type: .finalResponse,
                content: report.title
            )
        }
    }

    private func formatToolInput(_ data: Data) -> String? {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }
}

// MARK: - Header Section

private struct HeaderSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("リサーチエージェント", systemImage: "brain.head.profile")
                .font(.headline)

            Text("""
            Webを検索し、ページを取得して情報を収集し、
            構造化されたリサーチレポートを自動生成します。
            エージェントの思考プロセスをステップごとに確認できます。
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Tools Section

private struct ToolsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("利用可能なツール")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(ResearchToolSet.descriptions, id: \.name) { tool in
                    VStack(spacing: 4) {
                        Image(systemName: tool.icon)
                            .font(.title3)
                            .foregroundStyle(.blue)
                        Text(tool.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            if !ResearchToolSet.isWebSearchAvailable {
                Label("Web検索を使用するには Brave Search API キーを設定してください", systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Scenario Section

private struct ScenarioSection: View {
    @Binding var selectedIndex: Int
    @Binding var inputText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("シナリオ")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(ResearchScenario.scenarios.enumerated()), id: \.element.id) { index, scenario in
                        Button {
                            selectedIndex = index
                            inputText = scenario.prompt
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(scenario.name)
                                    .font(.subheadline.bold())
                                Text(scenario.description)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedIndex == index
                                    ? Color.accentColor
                                    : Color(.systemGray5)
                            )
                            .foregroundStyle(selectedIndex == index ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Input Section

private struct InputSection: View {
    @Binding var inputText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("リサーチ依頼")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            TextEditor(text: $inputText)
                .font(.body)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Execution Section

struct ExecutionSection: View {
    let isRunning: Bool
    let canExecute: Bool
    let onExecute: () -> Void

    var body: some View {
        let settings = AgentSettings.shared
        VStack(spacing: 12) {
            if !settings.isCurrentProviderAvailable {
                Label("\(settings.selectedProvider.shortName) API キーが設定されていません", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button {
                onExecute()
            } label: {
                HStack {
                    if isRunning {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(isRunning ? "実行中..." : "エージェントを実行")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canExecute ? Color.accentColor : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canExecute)
        }
    }
}

// MARK: - Result Section

private struct ResultSection: View {
    let state: AgentExecutionState
    let steps: [AgentStepInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ステップ履歴
            if !steps.isEmpty {
                AgentStepListView(steps: steps, isLoading: state.isLoading)
            }

            // 最終結果
            switch state {
            case .success(let report):
                FinalReportView(report: report)

            case .error(let message):
                ErrorView(message: message)

            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Error View

private struct ErrorView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("エラー", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.red)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    NavigationStack {
        AgentRunnerView()
    }
}
