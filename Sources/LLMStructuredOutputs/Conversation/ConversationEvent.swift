import Foundation

// MARK: - ConversationEvent

/// 会話履歴で発生するイベント
///
/// `ConversationHistoryProtocol` の `makeEventStream()` から取得できる
/// AsyncStream で配信されるイベントを表現します。
///
/// ## 使用例
///
/// ```swift
/// let history = ConversationHistory()
///
/// // イベントを購読
/// Task {
///     for await event in await history.makeEventStream() {
///         switch event {
///         case .userMessage(let message):
///             print("User: \(message.content)")
///         case .assistantMessage(let message):
///             print("Assistant: \(message.content)")
///         case .usageUpdated(let usage):
///             print("Tokens: \(usage.totalTokens)")
///         case .cleared:
///             print("History cleared")
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
}
