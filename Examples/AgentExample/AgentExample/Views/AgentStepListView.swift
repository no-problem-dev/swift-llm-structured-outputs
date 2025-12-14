//
//  AgentStepListView.swift
//  AgentExample
//
//  エージェントステップリスト表示
//

import SwiftUI

/// エージェントステップリスト表示
///
/// エージェントの実行ステップを時系列で表示します。
/// 各ステップの種類に応じたアイコンと色で視覚的に区別します。
struct AgentStepListView: View {
    let steps: [AgentStepInfo]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("実行ステップ", systemImage: "list.bullet.circle")
                    .font(.headline)

                Spacer()

                if isLoading {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("実行中...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("\(steps.count) ステップ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    StepRow(step: step, isLast: index == steps.count - 1)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Step Row

private struct StepRow: View {
    let step: AgentStepInfo
    let isLast: Bool

    /// 折りたたみ表示の文字数閾値
    private let collapseThreshold = 150

    @State private var isExpanded = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // タイムライン
            VStack(spacing: 0) {
                Circle()
                    .fill(stepColor)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: step.type.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                if !isLast {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            // コンテンツ
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(step.type.label)
                        .font(.caption.bold())
                        .foregroundStyle(stepColor)

                    Spacer()

                    Text(formatTime(step.timestamp))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // メインコンテンツ（長い場合は折りたたみ）
                CollapsibleText(
                    text: step.content,
                    threshold: collapseThreshold,
                    isExpanded: $isExpanded,
                    isError: step.isError
                )

                // ツール引数などの詳細
                if let detail = step.detail {
                    CollapsibleDetail(
                        text: detail,
                        threshold: collapseThreshold
                    )
                }
            }
            .padding(.bottom, isLast ? 0 : 16)
        }
    }

    private var stepColor: Color {
        if step.isError {
            return .red
        }

        switch step.type {
        case .thinking:
            return .purple
        case .toolCall:
            return .blue
        case .toolResult:
            return .green
        case .finalResponse:
            return .orange
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Collapsible Text

private struct CollapsibleText: View {
    let text: String
    let threshold: Int
    @Binding var isExpanded: Bool
    var isError: Bool = false

    private var needsCollapse: Bool {
        text.count > threshold
    }

    private var displayText: String {
        if needsCollapse && !isExpanded {
            return String(text.prefix(threshold)) + "..."
        }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(displayText)
                .font(.subheadline)
                .foregroundStyle(isError ? .red : .primary)

            if needsCollapse {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "折りたたむ" : "すべて表示")
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption2)
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Collapsible Detail

private struct CollapsibleDetail: View {
    let text: String
    let threshold: Int

    @State private var isExpanded = false

    private var needsCollapse: Bool {
        text.count > threshold
    }

    private var displayText: String {
        if needsCollapse && !isExpanded {
            return String(text.prefix(threshold)) + "..."
        }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(displayText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if needsCollapse {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "折りたたむ" : "すべて表示")
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption2)
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        AgentStepListView(
            steps: [
                AgentStepInfo(type: .thinking, content: "ユーザーの質問を分析しています..."),
                AgentStepInfo(type: .toolCall, content: "web_search_tool", detail: "query: Swift Concurrency"),
                AgentStepInfo(type: .toolResult, content: "検索結果: Swift Concurrencyに関する5件の結果が見つかりました"),
                AgentStepInfo(type: .toolCall, content: "fetch_web_page", detail: "url: https://example.com/swift-concurrency"),
                AgentStepInfo(type: .toolResult, content: "ページ取得完了: 3000文字のコンテンツを取得しました"),
                AgentStepInfo(type: .thinking, content: "収集した情報を分析してレポートを作成しています..."),
                AgentStepInfo(type: .finalResponse, content: "Swift Concurrency 完全ガイド")
            ],
            isLoading: false
        )
        .padding()
    }
}
