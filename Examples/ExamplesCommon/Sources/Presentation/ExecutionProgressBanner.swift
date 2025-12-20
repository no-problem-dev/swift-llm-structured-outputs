import SwiftUI

// MARK: - ExecutionPhaseProvider Protocol

/// 実行フェーズの表示情報を提供するプロトコル
///
/// 各アプリケーション固有のフェーズ型はこのプロトコルに準拠することで、
/// 共通の `ExecutionProgressBanner` を使用できる。
public protocol ExecutionPhaseProvider {
    /// 進捗表示用のアイコン名（SF Symbols）
    var progressIcon: String { get }
    /// 進捗表示用のラベル
    var progressLabel: String { get }
    /// テーマカラー
    var tintColor: Color { get }
}

// MARK: - ExecutionProgressBanner

/// 実行進捗を表示するバナー
///
/// TimelineViewを使用してアニメーションドットと経過時間を表示。
/// フェーズ型はジェネリックで、`ExecutionPhaseProvider`準拠の任意の型を使用可能。
public struct ExecutionProgressBanner<Phase: ExecutionPhaseProvider>: View {
    public let currentPhase: Phase?
    public let startTime: Date?
    public var processingMessage: String

    public init(
        currentPhase: Phase?,
        startTime: Date?,
        processingMessage: String = "エージェントが処理を実行しています"
    ) {
        self.currentPhase = currentPhase
        self.startTime = startTime
        self.processingMessage = processingMessage
    }

    private var phaseInfo: (icon: String, label: String, color: Color) {
        guard let phase = currentPhase else {
            return ("brain.head.profile", "準備中", .gray)
        }
        return (phase.progressIcon, phase.progressLabel, phase.tintColor)
    }

    #if os(iOS)
    private var backgroundColor: Color { Color(.secondarySystemGroupedBackground) }
    #else
    private var backgroundColor: Color { Color(nsColor: .controlBackgroundColor) }
    #endif

    public var body: some View {
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
                        Text(processingMessage)
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
                    .fill(backgroundColor)
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

// MARK: - Default Phase Type

/// デフォルトの実行フェーズ型
///
/// シンプルなユースケース向けの汎用フェーズ型。
public enum DefaultExecutionPhase: String, ExecutionPhaseProvider {
    case preparing = "preparing"
    case generating = "generating"
    case processing = "processing"
    case completed = "completed"
    case error = "error"

    public var progressIcon: String {
        switch self {
        case .preparing: return "brain.head.profile"
        case .generating: return "text.bubble"
        case .processing: return "gearshape.2"
        case .completed: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    public var progressLabel: String {
        switch self {
        case .preparing: return "準備中"
        case .generating: return "生成中"
        case .processing: return "処理中"
        case .completed: return "完了"
        case .error: return "エラー"
        }
    }

    public var tintColor: Color {
        switch self {
        case .preparing: return .gray
        case .generating: return .blue
        case .processing: return .purple
        case .completed: return .green
        case .error: return .red
        }
    }
}
