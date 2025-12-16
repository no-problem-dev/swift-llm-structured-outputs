import SwiftUI

extension SessionState {

    var displayLabel: String {
        switch self {
        case .idle: return "待機中"
        case .running: return "実行中"
        case .completed: return "完了"
        case .error: return "エラー"
        }
    }

    var icon: String {
        switch self {
        case .idle: return "circle"
        case .running: return "play.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .idle: return .secondary
        case .running: return .blue
        case .completed: return .green
        case .error: return .red
        }
    }
}
