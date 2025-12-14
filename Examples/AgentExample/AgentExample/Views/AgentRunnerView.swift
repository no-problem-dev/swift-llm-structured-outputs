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
    @State private var controller = AgentExecutionController()
    @State private var selectedScenarioIndex = 0
    @State private var inputText = ResearchScenario.scenarios[0].prompt

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - ヘッダー
                HeaderSection()

                Divider()

                // MARK: - ツール選択
                ToolSelectionSection()

                Divider()

                // MARK: - シナリオ選択
                ScenarioSection(
                    selectedIndex: $selectedScenarioIndex,
                    inputText: $inputText
                )

                // MARK: - 入力
                InputSection(inputText: $inputText)

                // MARK: - 実行/停止ボタン
                ExecutionControlSection(
                    controller: controller,
                    inputText: inputText
                )

                // MARK: - 結果表示
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
        .navigationTitle("リサーチエージェント")
        .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Execution Control Section

private struct ExecutionControlSection: View {
    let controller: AgentExecutionController
    let inputText: String

    var settings = AgentSettings.shared
    var toolConfig = ToolConfiguration.shared

    private var canExecute: Bool {
        controller.canExecute(prompt: inputText)
    }

    var body: some View {
        VStack(spacing: 12) {
            // 警告メッセージ
            WarningMessages(
                isProviderAvailable: settings.isCurrentProviderAvailable,
                hasUsableTools: toolConfig.hasUsableTools,
                providerName: settings.selectedProvider.shortName
            )

            // 実行/停止ボタン
            if controller.isRunning {
                StopButton(onStop: { controller.cancel() })
            } else {
                StartButton(
                    canExecute: canExecute,
                    onStart: { controller.start(prompt: inputText) }
                )
            }
        }
    }
}

/// 警告メッセージ表示
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

/// 警告バナー
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

/// 開始ボタン
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

/// 停止ボタン
private struct StopButton: View {
    let onStop: () -> Void

    var body: some View {
        Button(action: onStop) {
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
