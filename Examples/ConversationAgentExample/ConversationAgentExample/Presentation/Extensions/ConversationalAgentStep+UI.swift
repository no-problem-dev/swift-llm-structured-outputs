import Foundation
import LLMConversationalAgent
import LLMTool

extension AgentStep {

    func toStepInfo() -> ConversationStepInfo {
        switch self {
        case .userMessage(let message):
            return .init(type: .userMessage, content: message)

        case .thinking:
            return .init(type: .thinking, content: "（考え中...）")

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
        }
    }

    private func formatToolArgs(_ data: Data) -> String? {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }
}
