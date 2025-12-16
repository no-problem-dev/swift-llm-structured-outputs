import Foundation
import LLMClient

// MARK: - ConversationHistory

/// 会話履歴を管理する Actor
///
/// `ConversationHistoryProtocol` のデフォルト実装です。
/// メッセージ履歴とトークン使用量を Actor で保護された状態として管理し、
/// イベントストリームを通じて変更を通知します。
///
/// ## 概要
///
/// この Actor はモデルやクライアントから独立しており、
/// 同じ履歴を異なるプロバイダー・モデルで継続できます。
///
/// ## 使用例
///
/// ```swift
/// // 履歴を作成
/// let history = ConversationHistory()
///
/// // イベントを購読（オプション）
/// Task {
///     for await event in history.eventStream {
///         switch event {
///         case .userMessage(let msg):
///             print("User: \(msg.content)")
///         case .assistantMessage(let msg):
///             print("Assistant: \(msg.content)")
///         case .usageUpdated(let usage):
///             print("Total tokens: \(usage.totalTokens)")
///         case .cleared:
///             print("History cleared")
///         case .error(let error):
///             print("Error: \(error)")
///         }
///     }
/// }
///
/// // 会話を実行
/// let result: CityInfo = try await client.chat(
///     "日本の首都は？",
///     history: history,
///     model: .sonnet
/// )
///
/// // 状態を確認
/// print(await history.turnCount)  // 1
/// print(await history.getTotalUsage().totalTokens)  // 使用トークン数
/// ```
///
/// ## 既存の履歴から初期化
///
/// ```swift
/// let existingMessages: [LLMMessage] = [
///     .user("こんにちは"),
///     .assistant("こんにちは！何かお手伝いできることはありますか？")
/// ]
/// let history = ConversationHistory(messages: existingMessages)
/// ```
public actor ConversationHistory: ConversationHistoryProtocol {
    // MARK: - Properties

    /// メッセージ履歴
    private var messages: [LLMMessage]

    /// 累計トークン使用量
    private var totalUsage: TokenUsage

    /// イベントストリーム
    public nonisolated let eventStream: AsyncStream<ConversationEvent>

    /// イベントストリームの継続
    private let continuation: AsyncStream<ConversationEvent>.Continuation

    // MARK: - Initialization

    /// 空の会話履歴を作成
    public init() {
        self.messages = []
        self.totalUsage = TokenUsage(inputTokens: 0, outputTokens: 0)
        (self.eventStream, self.continuation) = AsyncStream.makeStream(of: ConversationEvent.self)
    }

    /// 既存のメッセージから会話履歴を作成
    ///
    /// - Parameter messages: 初期メッセージ履歴
    public init(messages: [LLMMessage]) {
        self.messages = messages
        self.totalUsage = TokenUsage(inputTokens: 0, outputTokens: 0)
        (self.eventStream, self.continuation) = AsyncStream.makeStream(of: ConversationEvent.self)
    }

    /// 既存のメッセージとトークン使用量から会話履歴を作成
    ///
    /// - Parameters:
    ///   - messages: 初期メッセージ履歴
    ///   - totalUsage: 初期トークン使用量
    public init(messages: [LLMMessage], totalUsage: TokenUsage) {
        self.messages = messages
        self.totalUsage = totalUsage
        (self.eventStream, self.continuation) = AsyncStream.makeStream(of: ConversationEvent.self)
    }

    // MARK: - ConversationHistoryProtocol

    public func getMessages() -> [LLMMessage] {
        messages
    }

    public func getTotalUsage() -> TokenUsage {
        totalUsage
    }

    public var turnCount: Int {
        messages.count / 2
    }

    public func append(_ message: LLMMessage) {
        messages.append(message)

        // イベントを発行
        let event: ConversationEvent = message.role == .user
            ? .userMessage(message)
            : .assistantMessage(message)
        emit(event)
    }

    public func addUsage(_ usage: TokenUsage) {
        totalUsage = TokenUsage(
            inputTokens: totalUsage.inputTokens + usage.inputTokens,
            outputTokens: totalUsage.outputTokens + usage.outputTokens
        )
        emit(.usageUpdated(totalUsage))
    }

    public func clear() {
        messages = []
        totalUsage = TokenUsage(inputTokens: 0, outputTokens: 0)
        emit(.cleared)
    }

    public func emitError(_ error: LLMError) {
        emit(.error(error))
    }

    // MARK: - Private Methods

    /// イベントを発行
    private func emit(_ event: ConversationEvent) {
        continuation.yield(event)
    }
}
