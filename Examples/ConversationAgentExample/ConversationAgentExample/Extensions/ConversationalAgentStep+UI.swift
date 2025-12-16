import Foundation
import LLMStructuredOutputs

extension ConversationalAgentStep {

    func toStepInfo() -> ConversationStepInfo {
        switch self {
        case .userMessage(let message):
            return .init(type: .userMessage, content: message)

        case .thinking(let response):
            let text = response.content.compactMap { block -> String? in
                if case .text(let value) = block { return value }
                return nil
            }.joined()

            if text.isEmpty {
                let hasToolUse = response.content.contains { block in
                    if case .toolUse = block { return true }
                    return false
                }
                return .init(type: .thinking, content: hasToolUse ? "（ツール実行中...）" : "（考え中...）")
            } else {
                return .init(type: .thinking, content: String(text.prefix(200)))
            }

        case .toolCall(let call):
            let args = formatToolArgs(call.arguments)
            return .init(type: .toolCall, content: call.name, detail: args)

        case .toolResult(let result):
            return .init(
                type: .toolResult,
                content: String(result.output.prefix(300)),
                isError: result.isError
            )

        case .interrupted(let message):
            return .init(type: .interrupted, content: "割り込み処理: \(message)")

        case .askingUser(let question):
            return .init(type: .askingUser, content: question)

        case .awaitingUserInput:
            return .init(type: .awaitingInput, content: "下の入力欄から回答してください")

        case .textResponse(let text):
            return .init(type: .textResponse, content: String(text.prefix(500)))

        case .finalResponse:
            return .init(type: .finalResponse, content: "レポート生成完了")
        }
    }

    private func formatToolArgs(_ data: Data) -> String? {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }
}
