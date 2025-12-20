import SwiftUI
import ExamplesCommon

struct StepRow: View {
    let step: ConversationStepInfo
    let isLast: Bool
    let isLatestActive: Bool
    var onResultTap: (() -> Void)?

    private let lineThreshold = 5

    @State private var isExpanded = false
    @State private var isPulsing = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            timelineIndicator
            contentSection
        }
    }

    // MARK: - Timeline Indicator

    private var timelineIndicator: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(step.type.tintColor.opacity(0.15))
                    .frame(width: 32, height: 32)

                if isLatestActive && !isLast {
                    Circle()
                        .fill(step.type.tintColor.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .scaleEffect(isPulsing ? 1.3 : 1.0)
                        .opacity(isPulsing ? 0 : 1)
                        .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: isPulsing)
                        .onAppear { isPulsing = true }
                }

                Image(systemName: step.type.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(step.type.tintColor)
            }

            if !isLast {
                Rectangle()
                    .fill(step.type.tintColor.opacity(0.2))
                    .frame(width: 2)
                    .frame(minHeight: 20)
            }
        }
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(step.type.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(step.type.tintColor)

                Spacer()

                Text(step.timestamp, format: .dateTime.hour().minute().second())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            CollapsibleText(
                text: step.content,
                lineThreshold: lineThreshold,
                foregroundStyle: step.isError ? .red : .primary
            )

            if let detail = step.detail {
                CollapsibleText(
                    text: detail,
                    lineThreshold: lineThreshold,
                    font: .caption,
                    foregroundStyle: .secondary,
                    showBackground: true
                )
            }

            if step.type == .finalResponse, onResultTap != nil {
                Button {
                    onResultTap?()
                } label: {
                    Label("結果を表示", systemImage: "doc.text.magnifyingglass")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(step.type.tintColor)
                .padding(.top, 4)
            }
        }
        .padding(.bottom, isLast ? 0 : 12)
    }
}

// MARK: - StepListView

struct StepListView: View {
    let steps: [ConversationStepInfo]
    let isLoading: Bool
    let isCompleted: Bool
    var onResultTap: (() -> Void)?

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                StepRow(
                    step: step,
                    isLast: index == steps.count - 1 && !isLoading,
                    isLatestActive: index == steps.count - 1 && isLoading,
                    onResultTap: step.type == .finalResponse ? onResultTap : nil
                )
                .id(step.id)
            }

            if isLoading {
                loadingIndicator
            }
        }
        .padding(.horizontal)
    }

    private var loadingIndicator: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 32, height: 32)

                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            Text("処理中...")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
        .padding(.top, 4)
    }
}
