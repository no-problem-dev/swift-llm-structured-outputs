import SwiftUI

/// アクティブセッションのミニプレイヤー風バー
///
/// Music appの「Now Playing」バーのように、
/// アクティブなセッションの状態を画面下部にフローティング表示する。
struct ActiveSessionBar: View {
    @Environment(ActiveSessionState.self) private var sessionState

    let onTap: () -> Void

    private var shouldShow: Bool {
        // セッションが存在し、何かしらのアクティビティがある場合に表示
        sessionState.hasActiveSession ||
        !sessionState.steps.isEmpty ||
        sessionState.executionState.isRunning
    }

    private var statusInfo: (icon: String, label: String, color: Color) {
        switch sessionState.executionState {
        case .running:
            if let lastStep = sessionState.steps.last {
                return (lastStep.type.progressIcon, lastStep.type.progressLabel, lastStep.type.tintColor)
            }
            return ("brain.head.profile", "実行中", .blue)
        case .paused:
            return ("pause.circle.fill", "一時停止", .orange)
        case .completed:
            return ("checkmark.circle.fill", "完了", .green)
        case .error:
            return ("exclamationmark.triangle.fill", "エラー", .red)
        case .idle:
            if sessionState.waitingForAnswer {
                return ("questionmark.circle.fill", "回答待ち", .orange)
            }
            if !sessionState.steps.isEmpty {
                return ("pause.circle.fill", "一時停止", .secondary)
            }
            return ("circle", "待機中", .secondary)
        }
    }

    var body: some View {
        if shouldShow {
            Button(action: onTap) {
                content
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var content: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let isRunning = sessionState.executionState.isRunning
            let dotCount = isRunning ? Int(timeline.date.timeIntervalSince1970 * 2) % 3 : 0
            let animatedDots = isRunning ? String(repeating: ".", count: dotCount + 1) : ""

            HStack(spacing: 12) {
                // ステータスアイコン
                ZStack {
                    Circle()
                        .fill(statusInfo.color.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: statusInfo.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(statusInfo.color)
                        .symbolEffect(.pulse, options: .repeating, isActive: isRunning)
                }

                // セッション情報
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(sessionState.sessionData.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 4) {
                        Text(statusInfo.label)
                            .font(.caption)
                            .foregroundStyle(statusInfo.color)

                        if isRunning {
                            Text(animatedDots)
                                .font(.caption)
                                .foregroundStyle(statusInfo.color)
                                .frame(width: 16, alignment: .leading)
                        }

                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Text(sessionState.selectedOutputType.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if sessionState.turnCount > 0 {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            Text("ターン \(sessionState.turnCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // 進捗インジケータまたは矢印
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.up")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(statusInfo.color.opacity(isRunning ? 0.5 : 0.2), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

#Preview {
    VStack {
        Spacer()
        ActiveSessionBar(onTap: {})
            .environment(ActiveSessionState())
    }
}
