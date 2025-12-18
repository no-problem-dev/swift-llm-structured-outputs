import SwiftUI

struct ExecutionProgressBanner: View {
    let currentPhase: ConversationStepInfo.StepType?
    let startTime: Date?

    private var phaseInfo: (icon: String, label: String, color: Color) {
        guard let phase = currentPhase else {
            return ("brain.head.profile", "準備中", .gray)
        }
        return (phase.progressIcon, phase.progressLabel, phase.tintColor)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let dotCount = Int(timeline.date.timeIntervalSince1970 * 2) % 3
            let animatedDots = String(repeating: ".", count: dotCount + 1)
            let elapsedTime = startTime.map { timeline.date.timeIntervalSince($0) } ?? 0
            let elapsedTimeText = formatElapsedTime(elapsedTime)

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(phaseInfo.color.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: phaseInfo.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(phaseInfo.color)
                        .symbolEffect(.pulse, options: .repeating)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(phaseInfo.label)
                            .font(.subheadline.bold())
                            .foregroundStyle(phaseInfo.color)

                        Text(animatedDots)
                            .font(.subheadline.bold())
                            .foregroundStyle(phaseInfo.color)
                            .frame(width: 20, alignment: .leading)
                    }

                    HStack(spacing: 8) {
                        Text("エージェントが処理を実行しています")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if startTime != nil {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(elapsedTimeText)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                ProgressView()
                    .scaleEffect(0.9)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(phaseInfo.color, lineWidth: 1)
                    )
            )
        }
    }

    private func formatElapsedTime(_ elapsed: TimeInterval) -> String {
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "%d秒", seconds)
        }
    }
}
