import Foundation
import SwiftUI
import LLMClient
import ExamplesCommon

/// 会話ステップ情報（UI表示専用）
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

// MARK: - StepType UI Extensions

extension ConversationStepInfo.StepType: ExecutionPhaseProvider {

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
                break

            case .image:
                steps.append(ConversationStepInfo(type: .userMessage, content: "[画像]"))

            case .audio:
                steps.append(ConversationStepInfo(type: .userMessage, content: "[音声]"))

            case .video:
                steps.append(ConversationStepInfo(type: .userMessage, content: "[動画]"))
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
                break

            case .image:
                steps.append(ConversationStepInfo(type: .textResponse, content: "[画像]"))

            case .audio:
                steps.append(ConversationStepInfo(type: .textResponse, content: "[音声]"))

            case .video:
                steps.append(ConversationStepInfo(type: .textResponse, content: "[動画]"))
            }
        }

        return steps
    }

    private func formatToolInput(_ input: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: input) as? [String: Any] else {
            return ""
        }

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
