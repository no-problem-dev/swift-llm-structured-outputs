import Foundation

struct ConversationStepInfo: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: StepType
    let content: String
    let detail: String?
    let isError: Bool

    enum StepType: String {
        case userMessage = "👤"
        case thinking = "🤔"
        case toolCall = "🔧"
        case toolResult = "📄"
        case interrupted = "⚡"
        case askingUser = "❓"
        case awaitingInput = "⏳"
        case textResponse = "💬"
        case finalResponse = "✅"
        case event = "📢"
        case error = "❌"
    }

    init(type: StepType, content: String, detail: String? = nil, isError: Bool = false) {
        self.timestamp = Date()
        self.type = type
        self.content = content
        self.detail = detail
        self.isError = isError
    }
}
