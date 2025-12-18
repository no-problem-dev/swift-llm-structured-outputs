import SwiftUI

struct StepListView: View {
    let steps: [ConversationStepInfo]
    let isLoading: Bool
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
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        let isLastStep = index == steps.count - 1
                        StepRow(
                            step: step,
                            isLast: isLastStep,
                            isLatestActive: isLastStep && isLoading,
                            onResultTap: step.type == .finalResponse ? onResultTap : nil
                        )
                        .id(step.id)
                    }
                }
                .padding()
            }
            .background(Color(.systemGray6))
            .onChange(of: steps.count) { _, _ in
                if let lastStep = steps.last {
                    withAnimation {
                        proxy.scrollTo(lastStep.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        StepListView(
            steps: [
                .init(type: .userMessage, content: "AIエージェントについて調べて"),
                .init(type: .thinking, content: "調査を開始します..."),
                .init(type: .toolCall, content: "web_search", detail: "query: AI agent"),
                .init(type: .toolResult, content: "検索結果が見つかりました。"),
                .init(type: .finalResponse, content: "レポート生成完了")
            ],
            isLoading: true
        )
        .padding()
    }
}
