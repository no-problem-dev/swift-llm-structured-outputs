import SwiftUI

struct StepListView: View {
    let steps: [ConversationStepInfo]
    let isLoading: Bool
    let isCompleted: Bool
    var onResultTap: (() -> Void)?

    private var latestStepType: ConversationStepInfo.StepType? {
        steps.last?.type
    }

    private var startTime: Date? {
        steps.first?.timestamp
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if steps.isEmpty {
                emptyState
            } else {
                stepList
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Label("実行ステップ", systemImage: "list.bullet.circle")
                .font(.headline)

            Spacer()

            Text("\(steps.count) ステップ")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "ステップなし",
            systemImage: "list.bullet.rectangle",
            description: Text("プロンプトを入力して実行してください")
        )
        .frame(minHeight: 200)
    }

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                let isLastStep = index == steps.count - 1 && !isCompleted
                StepRow(
                    step: step,
                    isLast: isLastStep,
                    isLatestActive: isLastStep && isLoading,
                    onResultTap: step.type == .finalResponse ? onResultTap : nil
                )
                .id(step.id)
            }

            // 完了時は最後に目立つ結果リンクを表示
            if isCompleted, let onResultTap {
                completionBanner(onTap: onResultTap)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }

    private func completionBanner(onTap: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // タイムラインインジケータ
            Circle()
                .fill(Color.green)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

            // コンテンツ
            VStack(alignment: .leading, spacing: 8) {
                Text("完了")
                    .font(.caption.bold())
                    .foregroundStyle(.green)

                Button(action: onTap) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                        Text("リサーチ結果を見る")
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 16)
    }
}

#Preview("実行中") {
    ScrollView {
        StepListView(
            steps: [
                .init(type: .userMessage, content: "AIエージェントについて調べて"),
                .init(type: .thinking, content: "調査を開始します..."),
                .init(type: .toolCall, content: "web_search", detail: "query: AI agent"),
                .init(type: .toolResult, content: "検索結果が見つかりました。"),
                .init(type: .finalResponse, content: "レポート生成完了")
            ],
            isLoading: true,
            isCompleted: false
        )
        .padding()
    }
}

#Preview("完了") {
    ScrollView {
        StepListView(
            steps: [
                .init(type: .userMessage, content: "AIエージェントについて調べて"),
                .init(type: .thinking, content: "調査を開始します..."),
                .init(type: .toolCall, content: "web_search", detail: "query: AI agent"),
                .init(type: .toolResult, content: "検索結果が見つかりました。"),
                .init(type: .finalResponse, content: "レポート生成完了")
            ],
            isLoading: false,
            isCompleted: true,
            onResultTap: { print("Result tapped") }
        )
        .padding()
    }
}
