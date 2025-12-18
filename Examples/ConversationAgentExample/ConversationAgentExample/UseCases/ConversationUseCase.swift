import Foundation
import LLMAgent
import LLMStructuredOutputs
import LLMToolkits

/// 会話実行のビジネスロジックを担当
protocol ConversationUseCase: Sendable {
    /// ジェネリックなセッション作成
    func createSession<Client: AgentCapableClient>(
        client: Client,
        outputType: AgentOutputType,
        interactiveMode: Bool,
        configuration: AgentConfiguration
    ) -> ConversationalAgentSession<Client> where Client.Model: Sendable

    /// プロバイダーに応じたクライアントを作成
    func createAnthropicClient(apiKey: String) -> AnthropicClient
    func createOpenAIClient(apiKey: String) -> OpenAIClient
    func createGeminiClient(apiKey: String) -> GeminiClient
}

final class ConversationUseCaseImpl: ConversationUseCase {

    private let agentService: AgentService

    init(agentService: AgentService) {
        self.agentService = agentService
    }

    func createSession<Client: AgentCapableClient>(
        client: Client,
        outputType: AgentOutputType,
        interactiveMode: Bool,
        configuration: AgentConfiguration
    ) -> ConversationalAgentSession<Client> where Client.Model: Sendable {
        agentService.createSession(
            client: client,
            outputType: outputType,
            interactiveMode: interactiveMode,
            configuration: configuration
        )
    }

    func createAnthropicClient(apiKey: String) -> AnthropicClient {
        AnthropicClient(apiKey: apiKey)
    }

    func createOpenAIClient(apiKey: String) -> OpenAIClient {
        OpenAIClient(apiKey: apiKey)
    }

    func createGeminiClient(apiKey: String) -> GeminiClient {
        GeminiClient(apiKey: apiKey)
    }
}
