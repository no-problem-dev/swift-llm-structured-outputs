import Foundation
import LLMClient

/// 会話セッション
struct Session: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let agentId: UUID
    var name: String
    var messages: [Message]
    var lastResultJSON: String?
    var status: Status
    var provider: String
    let createdAt: Date
    var updatedAt: Date

    enum Status: String, Codable, Sendable {
        case active, completed, archived

        var displayName: String {
            switch self {
            case .active: "進行中"
            case .completed: "完了"
            case .archived: "アーカイブ"
            }
        }

        var icon: String {
            switch self {
            case .active: "bubble.left.and.bubble.right"
            case .completed: "checkmark.circle"
            case .archived: "archivebox"
            }
        }
    }

    struct Message: Codable, Sendable, Hashable {
        let role: String
        let content: String
        let timestamp: Date

        init(role: String, content: String, timestamp: Date = Date()) {
            self.role = role
            self.content = content
            self.timestamp = timestamp
        }

        init(from llmMessage: LLMMessage) {
            self.role = llmMessage.role.rawValue
            self.content = llmMessage.contents.compactMap { content -> String? in
                if case .text(let text) = content { return text }
                return nil
            }.joined(separator: "\n")
            self.timestamp = Date()
        }

        func toLLMMessage() -> LLMMessage {
            let messageRole: LLMMessage.Role = role == "assistant" ? .assistant : .user
            return LLMMessage(role: messageRole, contents: [.text(content)])
        }
    }

    init(
        id: UUID = UUID(),
        agentId: UUID,
        name: String? = nil,
        messages: [Message] = [],
        lastResultJSON: String? = nil,
        status: Status = .active,
        provider: String = "anthropic",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.agentId = agentId
        self.name = name ?? Self.generateDefaultName(createdAt: createdAt)
        self.messages = messages
        self.lastResultJSON = lastResultJSON
        self.status = status
        self.provider = provider
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var turnCount: Int { messages.filter { $0.role == "user" }.count }
    var lastMessage: Message? { messages.last }
    var llmMessages: [LLMMessage] { messages.map { $0.toLLMMessage() } }

    mutating func addMessage(_ message: LLMMessage) {
        messages.append(Message(from: message))
        updatedAt = Date()
    }

    mutating func syncMessages(_ llmMessages: [LLMMessage]) {
        messages = llmMessages.map { Message(from: $0) }
        updatedAt = Date()
    }

    mutating func setResult(_ json: String) {
        lastResultJSON = json
        updatedAt = Date()
    }

    mutating func updateStatus(_ newStatus: Status) {
        status = newStatus
        updatedAt = Date()
    }

    private static func generateDefaultName(createdAt: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return "セッション \(formatter.string(from: createdAt))"
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Session, rhs: Session) -> Bool { lhs.id == rhs.id }
}
