import SwiftUI

extension ConversationStepInfo.StepType {

    var icon: String {
        switch self {
        case .userMessage: return "person.fill"
        case .thinking: return "brain.head.profile"
        case .toolCall: return "wrench.and.screwdriver"
        case .toolResult: return "doc.text"
        case .interrupted: return "bolt.fill"
        case .askingUser: return "questionmark.bubble"
        case .awaitingInput: return "ellipsis.bubble"
        case .textResponse: return "text.bubble"
        case .finalResponse: return "checkmark.circle.fill"
        case .event: return "bell.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var label: String {
        switch self {
        case .userMessage: return "ユーザー"
        case .thinking: return "思考中"
        case .toolCall: return "ツール呼び出し"
        case .toolResult: return "ツール結果"
        case .interrupted: return "割り込み"
        case .askingUser: return "質問"
        case .awaitingInput: return "回答待ち"
        case .textResponse: return "応答"
        case .finalResponse: return "完了"
        case .event: return "イベント"
        case .error: return "エラー"
        }
    }

    var tintColor: Color {
        switch self {
        case .userMessage: return .blue
        case .thinking: return .purple
        case .toolCall: return .blue
        case .toolResult: return .green
        case .interrupted: return .orange
        case .askingUser: return .indigo
        case .awaitingInput: return .indigo
        case .textResponse: return .cyan
        case .finalResponse: return .orange
        case .event: return .gray
        case .error: return .red
        }
    }

    var progressLabel: String {
        switch self {
        case .userMessage: return "ユーザー入力処理中"
        case .thinking: return "思考中"
        case .toolCall: return "ツール実行中"
        case .toolResult: return "結果処理中"
        case .interrupted: return "割り込み処理中"
        case .askingUser: return "ユーザーに質問中"
        case .awaitingInput: return "回答待ち"
        case .textResponse: return "応答生成中"
        case .finalResponse: return "レポート生成中"
        case .event: return "イベント処理中"
        case .error: return "エラー発生"
        }
    }

    var progressIcon: String {
        switch self {
        case .finalResponse: return "sparkles"
        case .error: return "exclamationmark.triangle"
        default: return icon
        }
    }
}
