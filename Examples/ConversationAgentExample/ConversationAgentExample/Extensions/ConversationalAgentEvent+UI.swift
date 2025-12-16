import Foundation
import LLMStructuredOutputs

extension ConversationalAgentEvent {

    var displayMessage: String {
        switch self {
        case .userMessage:
            return "ユーザーメッセージが追加されました"
        case .assistantMessage:
            return "アシスタントメッセージが追加されました"
        case .interruptQueued(let msg):
            return "割り込みがキューに追加: \(msg)"
        case .interruptProcessed(let msg):
            return "割り込みが処理されました: \(msg)"
        case .askingUser(let question):
            return "AIがユーザーに質問中: \(question)"
        case .userAnswerProvided(let answer):
            return "ユーザーが回答しました: \(answer)"
        case .sessionStarted:
            return "セッションが開始されました"
        case .sessionCompleted:
            return "セッションが完了しました"
        case .sessionCancelled:
            return "セッションがキャンセルされました"
        case .cleared:
            return "会話履歴がクリアされました"
        case .error(let error):
            return "エラー: \(error.localizedDescription)"
        }
    }
}
