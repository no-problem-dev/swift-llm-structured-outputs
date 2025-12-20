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

    // MARK: - Timeline

    private var timelineIndicator: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(stepColor)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: step.type.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .overlay {
                    if isLatestActive {
                        Circle()
                            .stroke(stepColor.opacity(0.5), lineWidth: 3)
                            .scaleEffect(isPulsing ? 1.5 : 1.0)
                            .opacity(isPulsing ? 0 : 1)
                    }
                }
                .onAppear {
                    if isLatestActive {
                        withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                            isPulsing = true
                        }
                    }
                }

            if !isLast {
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
    }

    // MARK: - Content

    private var contentSection: some View {
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

            if step.type == .finalResponse, let onResultTap {
                Button(action: onResultTap) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("レポートを表示")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
        .padding(.bottom, isLast ? 0 : 16)
    }

    // MARK: - Helpers

    private var stepColor: Color {
        step.isError ? .red : step.type.tintColor
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
