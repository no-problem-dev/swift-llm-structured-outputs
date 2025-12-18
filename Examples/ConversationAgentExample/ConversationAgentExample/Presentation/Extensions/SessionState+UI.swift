import SwiftUI
import LLMConversationalAgent

extension SessionStatus {

    /// UI表示用ラベル
    var displayLabel: String {
        switch self {
        case .idle: return "待機中"
        case .running: return "実行中"
        case .awaitingUserInput: return "回答待ち"
        case .paused: return "一時停止"
        case .failed: return "エラー"
        }
    }

    /// UI表示用アイコン
    var icon: String {
        switch self {
        case .idle: return "circle"
        case .running: return "play.circle.fill"
        case .awaitingUserInput: return "questionmark.circle.fill"
        case .paused: return "pause.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    /// UI表示用カラー
    var tintColor: Color {
        switch self {
        case .idle: return .secondary
        case .running: return .blue
        case .awaitingUserInput: return .orange
        case .paused: return .orange
        case .failed: return .red
        }
    }
}
