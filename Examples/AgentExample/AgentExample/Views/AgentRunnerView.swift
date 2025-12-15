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
    @State private var selectedScenarioID: String = ScenarioRegistry.allScenarios.first?.id ?? ""
    @State private var selectedSampleScenario: SampleScenario?
    @State private var inputText = ""

    private var selectedScenarioInfo: ScenarioInfo? {
        ScenarioRegistry.scenario(for: selectedScenarioID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderSection()

                Divider()

                ToolSelectionSection()

                Divider()

                ScenarioSection(
                    selectedScenarioID: $selectedScenarioID,
                    selectedSampleScenario: $selectedSampleScenario,
                    inputText: $inputText
                )

                InputSection(inputText: $inputText)

                ExecutionControlSection(
                    controller: controller,
                    inputText: inputText,
                    selectedScenarioID: selectedScenarioID
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
        .onAppear {
            // 初期シナリオの設定
            if let firstScenario = selectedScenarioInfo,
               let firstSample = firstScenario.sampleScenarios.first {
                selectedSampleScenario = firstSample
                inputText = firstSample.prompt
            }
        }
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
    @Binding var selectedScenarioID: String
    @Binding var selectedSampleScenario: SampleScenario?
    @Binding var inputText: String

    private var scenarios: [ScenarioInfo] {
        ScenarioRegistry.allScenarios
    }

    private var sampleScenariosForCategory: [SampleScenario] {
        ScenarioRegistry.sampleScenarios(for: selectedScenarioID)
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
                        ForEach(scenarios) { scenario in
                            Button {
                                selectedScenarioID = scenario.id
                                if let firstSample = scenario.sampleScenarios.first {
                                    selectedSampleScenario = firstSample
                                    inputText = firstSample.prompt
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: scenario.icon)
                                        .font(.caption)
                                    Text(scenario.displayName)
                                        .font(.subheadline.bold())
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    selectedScenarioID == scenario.id
                                        ? Color.accentColor
                                        : Color(.systemGray5)
                                )
                                .foregroundStyle(selectedScenarioID == scenario.id ? .white : .primary)
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
                        ForEach(sampleScenariosForCategory) { sample in
                            Button {
                                selectedSampleScenario = sample
                                inputText = sample.prompt
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(sample.name)
                                        .font(.subheadline.bold())
                                    Text(sample.description)
                                        .font(.caption2)
                                        .foregroundStyle(selectedSampleScenario?.id == sample.id ? .white.opacity(0.8) : .secondary)
                                        .lineLimit(2)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(width: 160, alignment: .leading)
                                .background(
                                    selectedSampleScenario?.id == sample.id
                                        ? Color.accentColor
                                        : Color(.systemGray5)
                                )
                                .foregroundStyle(selectedSampleScenario?.id == sample.id ? .white : .primary)
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
    let selectedScenarioID: String

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
                    onStart: { controller.start(scenarioID: selectedScenarioID, prompt: inputText) }
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
