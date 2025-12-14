//
//  AgentRunnerView.swift
//  AgentExample
//
//  エージェント実行画面
//

import SwiftUI
import LLMStructuredOutputs

/// エージェント実行画面
struct AgentRunnerView: View {
    @State private var controller = AgentExecutionController()
    @State private var selectedCategory: ScenarioCategory = .research
    @State private var selectedScenario: AgentScenario? = AgentScenario.scenarios(for: .research).first
    @State private var inputText = AgentScenario.scenarios(for: .research).first?.prompt ?? ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderSection()

                Divider()

                ToolSelectionSection()

                Divider()

                ScenarioSection(
                    selectedCategory: $selectedCategory,
                    selectedScenario: $selectedScenario,
                    inputText: $inputText
                )

                InputSection(inputText: $inputText)

                ExecutionControlSection(
                    controller: controller,
                    inputText: inputText,
                    selectedCategory: selectedCategory
                )

                if !controller.state.isIdle {
                    ResultSection(
                        state: controller.state,
                        steps: controller.steps
                    )
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("エージェント")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Header Section

private struct HeaderSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("エージェント", systemImage: "brain.head.profile")
                .font(.headline)

            Text("""
            様々なツールを使って情報収集・計算・分析を行い、
            カテゴリに応じた構造化レポートを自動生成します。
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Scenario Section

private struct ScenarioSection: View {
    @Binding var selectedCategory: ScenarioCategory
    @Binding var selectedScenario: AgentScenario?
    @Binding var inputText: String

    private var scenariosForCategory: [AgentScenario] {
        AgentScenario.scenarios(for: selectedCategory)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // カテゴリ選択
            VStack(alignment: .leading, spacing: 8) {
                Text("カテゴリ")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ScenarioCategory.allCases) { category in
                            Button {
                                selectedCategory = category
                                if let firstScenario = AgentScenario.scenarios(for: category).first {
                                    selectedScenario = firstScenario
                                    inputText = firstScenario.prompt
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: category.icon)
                                        .font(.caption)
                                    Text(category.rawValue)
                                        .font(.subheadline.bold())
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    selectedCategory == category
                                        ? Color.accentColor
                                        : Color(.systemGray5)
                                )
                                .foregroundStyle(selectedCategory == category ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // シナリオ選択
            VStack(alignment: .leading, spacing: 8) {
                Text("シナリオ")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(scenariosForCategory) { scenario in
                            Button {
                                selectedScenario = scenario
                                inputText = scenario.prompt
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(scenario.name)
                                        .font(.subheadline.bold())
                                    Text(scenario.description)
                                        .font(.caption2)
                                        .foregroundStyle(selectedScenario?.id == scenario.id ? .white.opacity(0.8) : .secondary)
                                        .lineLimit(2)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(width: 160, alignment: .leading)
                                .background(
                                    selectedScenario?.id == scenario.id
                                        ? Color.accentColor
                                        : Color(.systemGray5)
                                )
                                .foregroundStyle(selectedScenario?.id == scenario.id ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
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
            Text("依頼内容")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            TextEditor(text: $inputText)
                .font(.body)
                .foregroundColor(.primary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Execution Control Section

private struct ExecutionControlSection: View {
    let controller: AgentExecutionController
    let inputText: String
    let selectedCategory: ScenarioCategory

    var settings = AgentSettings.shared
    var toolConfig = ToolConfiguration.shared

    private var canExecute: Bool {
        controller.canExecute(prompt: inputText)
    }

    var body: some View {
        VStack(spacing: 12) {
            WarningMessages(
                isProviderAvailable: settings.isCurrentProviderAvailable,
                hasUsableTools: toolConfig.hasUsableTools,
                providerName: settings.selectedProvider.shortName
            )

            if controller.isRunning {
                StopButton(onStop: { controller.cancel() })
            } else {
                StartButton(
                    canExecute: canExecute,
                    onStart: { controller.start(prompt: inputText, category: selectedCategory) }
                )
            }
        }
    }
}

private struct WarningMessages: View {
    let isProviderAvailable: Bool
    let hasUsableTools: Bool
    let providerName: String

    var body: some View {
        VStack(spacing: 8) {
            if !isProviderAvailable {
                WarningBanner(
                    message: "\(providerName) API キーが設定されていません",
                    color: .orange
                )
            }

            if !hasUsableTools {
                WarningBanner(
                    message: "使用するツールを1つ以上選択してください",
                    color: .orange
                )
            }
        }
    }
}

private struct WarningBanner: View {
    let message: String
    let color: Color

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(color)
            .padding()
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct StartButton: View {
    let canExecute: Bool
    let onStart: () -> Void

    var body: some View {
        Button(action: onStart) {
            HStack {
                Image(systemName: "play.fill")
                Text("エージェントを実行")
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

private struct StopButton: View {
    let onStop: () -> Void
    @State private var showingConfirmation = false

    var body: some View {
        Button {
            showingConfirmation = true
        } label: {
            HStack {
                Image(systemName: "stop.fill")
                Text("停止")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .confirmationDialog(
            "エージェントを停止しますか？",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("停止する", role: .destructive) {
                onStop()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("実行中の処理が中断されます。")
        }
    }
}

// MARK: - Result Section

private struct ResultSection: View {
    let state: AgentExecutionState
    let steps: [AgentStepInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !steps.isEmpty {
                AgentStepListView(steps: steps, isLoading: state.isLoading)
            }

            switch state {
            case .success(let result):
                AgentResultView(result: result)

            case .error(let message):
                ErrorView(message: message)

            default:
                EmptyView()
            }
        }
    }
}

private struct ErrorView: View {
    let message: String

    private var isCancelled: Bool {
        message == "キャンセルされました"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                isCancelled ? "キャンセル" : "エラー",
                systemImage: isCancelled ? "xmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .font(.headline)
            .foregroundStyle(isCancelled ? .orange : .red)

            if !isCancelled {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isCancelled ? Color.orange : Color.red).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AgentRunnerView()
    }
}
