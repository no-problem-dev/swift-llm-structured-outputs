import Foundation
import LLMAgent
import LLMClient
import LLMMCP
import LLMStructuredOutputs
import LLMToolkits

/// 会話エージェントセッションの管理を担当
protocol AgentService: Sendable {
    func createSession<Client: AgentCapableClient>(
        client: Client,
        outputType: AgentOutputType,
        interactiveMode: Bool,
        configuration: AgentConfiguration,
        initialMessages: [LLMMessage]
    ) -> ConversationalAgentSession<Client> where Client.Model: Sendable

    func buildToolSet(for outputType: AgentOutputType) -> ToolSet
}

final class AgentServiceImpl: AgentService {

    private let apiKeyUseCase: APIKeyUseCase

    init(apiKeyUseCase: APIKeyUseCase) {
        self.apiKeyUseCase = apiKeyUseCase
    }

    func createSession<Client: AgentCapableClient>(
        client: Client,
        outputType: AgentOutputType,
        interactiveMode: Bool,
        configuration: AgentConfiguration,
        initialMessages: [LLMMessage]
    ) -> ConversationalAgentSession<Client> where Client.Model: Sendable {
        let tools = buildToolSet(for: outputType)

        return ConversationalAgentSession(
            client: client,
            systemPrompt: outputType.buildPrompt(interactiveMode: interactiveMode),
            tools: tools,
            interactiveMode: interactiveMode,
            configuration: configuration,
            initialMessages: initialMessages
        )
    }

    func buildToolSet(for outputType: AgentOutputType) -> ToolSet {
        let braveSearchKey = apiKeyUseCase.get(.braveSearch)

        return ToolSet {
            if outputType.requiresWebSearch {
                WebSearchTool(apiKey: braveSearchKey)
            }

            if outputType.requiresWebFetch {
                WebToolKit()
            }

            if outputType == .codeReview {
                TextAnalysisTool()
            }
        }
    }
}
