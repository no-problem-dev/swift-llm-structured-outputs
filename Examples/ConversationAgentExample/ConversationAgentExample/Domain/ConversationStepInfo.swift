import Foundation
import LLMClient

/// 会話ステップ情報（UI表示専用）
///
/// LLMMessage から動的に生成される表示用モデル。
/// 永続化は LLMMessage で行うため、このモデルは Codable ではありません。
struct ConversationStepInfo: Identifiable {
    let id: UUID
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
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
        self.content = content
        self.detail = detail
        self.isError = isError
    }
}

// MARK: - LLMMessage → ConversationStepInfo 変換

extension Array where Element == LLMMessage {
    /// LLMMessage 配列を UI 表示用の ConversationStepInfo 配列に変換
    func toStepInfos() -> [ConversationStepInfo] {
        var steps: [ConversationStepInfo] = []

        for message in self {
            switch message.role {
            case .user:
                steps.append(contentsOf: convertUserMessage(message))
            case .assistant:
                steps.append(contentsOf: convertAssistantMessage(message))
            }
        }

        return steps
    }

    private func convertUserMessage(_ message: LLMMessage) -> [ConversationStepInfo] {
        var steps: [ConversationStepInfo] = []

        for content in message.contents {
            switch content {
            case .text(let text):
                steps.append(ConversationStepInfo(type: .userMessage, content: text))

            case .toolResult(let toolCallId, let name, let resultContent, let isError):
                let truncatedContent = resultContent.count > 200
                    ? String(resultContent.prefix(200)) + "..."
                    : resultContent
                steps.append(ConversationStepInfo(
                    type: .toolResult,
                    content: "\(name): \(truncatedContent)",
                    detail: "ID: \(toolCallId)",
                    isError: isError
                ))

            case .toolUse:
                // ユーザーメッセージには通常 toolUse は含まれない
                break
            }
        }

        return steps
    }

    private func convertAssistantMessage(_ message: LLMMessage) -> [ConversationStepInfo] {
        var steps: [ConversationStepInfo] = []

        for content in message.contents {
            switch content {
            case .text(let text):
                if !text.isEmpty {
                    steps.append(ConversationStepInfo(type: .textResponse, content: text))
                }

            case .toolUse(_, let name, let input):
                let inputString = formatToolInput(input)
                steps.append(ConversationStepInfo(
                    type: .toolCall,
                    content: name,
                    detail: inputString.isEmpty ? nil : inputString
                ))

            case .toolResult:
                // アシスタントメッセージには通常 toolResult は含まれない
                break
            }
        }

        return steps
    }

    private func formatToolInput(_ input: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: input) as? [String: Any] else {
            return ""
        }

        // 重要なフィールドのみ表示
        let displayFields = json.compactMap { key, value -> String? in
            guard let stringValue = value as? String else { return nil }
            let truncated = stringValue.count > 50
                ? String(stringValue.prefix(50)) + "..."
                : stringValue
            return "\(key): \(truncated)"
        }

        return displayFields.joined(separator: ", ")
    }
}
