import Foundation
import LLMClient

// MARK: - ConversationEvent

/// 会話履歴で発生するイベント
///
/// `ConversationHistoryProtocol` の `eventStream` プロパティから取得できる
/// AsyncStream で配信されるイベントを表現します。
///
/// ## 使用例
///
/// ```swift
/// let history = ConversationHistory()
///
/// // イベントを購読
/// Task {
///     for await event in history.eventStream {
///         switch event {
///         case .userMessage(let message):
///             print("User: \(message.content)")
///         case .assistantMessage(let message):
///             print("Assistant: \(message.content)")
///         case .usageUpdated(let usage):
///             print("Tokens: \(usage.totalTokens)")
///         case .cleared:
///             print("History cleared")
///         case .error(let error):
///             print("Error: \(error)")
///         }
///     }
/// }
/// ```
public enum ConversationEvent: Sendable {
    /// ユーザーメッセージが追加された
    case userMessage(LLMMessage)

    /// アシスタントメッセージが追加された
    case assistantMessage(LLMMessage)

    /// トークン使用量が更新された
    case usageUpdated(TokenUsage)

    /// 履歴がクリアされた
    case cleared

    /// エラーが発生した
    case error(LLMError)
}
