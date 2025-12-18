import Foundation
import LLMClient

// MARK: - LLMProvider

/// LLMプロバイダー
enum LLMProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case anthropic = "Anthropic (Claude)"
    case openai = "OpenAI (GPT)"
    case gemini = "Google (Gemini)"

    var id: String { rawValue }
}

// MARK: - SessionData

/// セッションデータ
///
/// 会話セッションの永続化用データモデル。
/// `messages` は会話履歴の Single Source of Truth として機能します。
/// UI表示用の `ConversationStepInfo` は `messages` から動的に生成します。
struct SessionData: Identifiable, Codable, Sendable {
    let id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var provider: LLMProvider
    var outputType: AgentOutputType
    var interactiveMode: Bool
    var messages: [LLMMessage]
    var result: String?

    /// 新規セッションを作成
    init(
        title: String = "新規セッション",
        provider: LLMProvider = .anthropic,
        outputType: AgentOutputType = .research,
        interactiveMode: Bool = true
    ) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.provider = provider
        self.outputType = outputType
        self.interactiveMode = interactiveMode
        self.messages = []
        self.result = nil
    }

    /// 既存データから復元
    init(
        id: UUID,
        title: String,
        createdAt: Date,
        updatedAt: Date,
        provider: LLMProvider,
        outputType: AgentOutputType,
        interactiveMode: Bool,
        messages: [LLMMessage],
        result: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.provider = provider
        self.outputType = outputType
        self.interactiveMode = interactiveMode
        self.messages = messages
        self.result = result
    }
}

// MARK: - SessionData Helpers

extension SessionData {
    /// メッセージを追加して更新日時を更新
    mutating func addMessage(_ message: LLMMessage) {
        messages.append(message)
        updatedAt = Date()
    }

    /// 最初のユーザーメッセージからタイトルを自動生成
    mutating func updateTitleFromFirstMessage() {
        guard title == "新規セッション" else { return }

        // 最初のユーザーメッセージを検索
        if let firstUserMessage = messages.first(where: { $0.role == .user }),
           let firstText = firstUserMessage.contents.compactMap({ content -> String? in
               if case .text(let text) = content { return text }
               return nil
           }).first {
            // 最大30文字に制限
            if firstText.count > 30 {
                title = String(firstText.prefix(30)) + "..."
            } else {
                title = firstText
            }
        }
    }

    /// セッションの表示用サマリー
    var summary: String {
        let messageCount = messages.count
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .abbreviated
        let relativeTime = formatter.localizedString(for: updatedAt, relativeTo: Date())
        return "\(messageCount)メッセージ • \(relativeTime)"
    }
}
