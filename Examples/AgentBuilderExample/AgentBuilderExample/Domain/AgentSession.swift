import Foundation
import LLMClient

/// エージェントセッション
///
/// 特定のエージェント定義を使用した会話セッション。
/// 会話履歴と生成結果を保持する。
struct AgentSession: Identifiable, Codable, Sendable, Hashable {
    let id: UUID

    /// 使用するエージェント定義のID
    let definitionId: UUID

    /// セッション名（自動生成または手動設定）
    var name: String

    /// 会話履歴（シリアライズ用）
    var messageHistory: [SerializableMessage]

    /// 最後の生成結果（JSON文字列として保存）
    var lastResultJSON: String?

    /// セッションの状態
    var status: Status

    /// 使用したプロバイダー
    var provider: String

    /// 作成日時
    let createdAt: Date

    /// 更新日時
    var updatedAt: Date

    // MARK: - Nested Types

    enum Status: String, Codable, Sendable {
        case active
        case completed
        case archived
    }

    /// メッセージのシリアライズ用構造体
    struct SerializableMessage: Codable, Sendable, Hashable {
        let role: String
        let content: String
        let timestamp: Date

        init(role: String, content: String, timestamp: Date = Date()) {
            self.role = role
            self.content = content
            self.timestamp = timestamp
        }

        init(from message: LLMMessage) {
            self.role = message.role.rawValue
            self.content = message.contents.compactMap { content -> String? in
                if case .text(let text) = content {
                    return text
                }
                return nil
            }.joined(separator: "\n")
            self.timestamp = Date()
        }

        func toLLMMessage() -> LLMMessage {
            let messageRole: LLMMessage.Role = role == "assistant" ? .assistant : .user
            return LLMMessage(role: messageRole, contents: [.text(content)])
        }
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        definitionId: UUID,
        name: String? = nil,
        messageHistory: [SerializableMessage] = [],
        lastResultJSON: String? = nil,
        status: Status = .active,
        provider: String = "anthropic",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.definitionId = definitionId
        self.name = name ?? Self.generateDefaultName(createdAt: createdAt)
        self.messageHistory = messageHistory
        self.lastResultJSON = lastResultJSON
        self.status = status
        self.provider = provider
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Computed Properties

    /// ターン数（ユーザーメッセージの数）
    var turnCount: Int {
        messageHistory.filter { $0.role == "user" }.count
    }

    /// 最後のメッセージ
    var lastMessage: SerializableMessage? {
        messageHistory.last
    }

    /// 会話履歴をLLMMessageに変換
    var llmMessages: [LLMMessage] {
        messageHistory.map { $0.toLLMMessage() }
    }

    // MARK: - Methods

    /// メッセージを追加
    mutating func addMessage(_ message: LLMMessage) {
        messageHistory.append(SerializableMessage(from: message))
        updatedAt = Date()
    }

    /// 複数のメッセージを同期
    mutating func syncMessages(_ messages: [LLMMessage]) {
        messageHistory = messages.map { SerializableMessage(from: $0) }
        updatedAt = Date()
    }

    /// 結果を設定
    mutating func setResult(_ json: String) {
        lastResultJSON = json
        updatedAt = Date()
    }

    /// ステータスを更新
    mutating func updateStatus(_ newStatus: Status) {
        status = newStatus
        updatedAt = Date()
    }

    // MARK: - Private Helpers

    private static func generateDefaultName(createdAt: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return "セッション \(formatter.string(from: createdAt))"
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AgentSession, rhs: AgentSession) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Display Helpers

extension AgentSession.Status {
    var displayName: String {
        switch self {
        case .active: return "進行中"
        case .completed: return "完了"
        case .archived: return "アーカイブ"
        }
    }

    var iconName: String {
        switch self {
        case .active: return "bubble.left.and.bubble.right"
        case .completed: return "checkmark.circle"
        case .archived: return "archivebox"
        }
    }
}
