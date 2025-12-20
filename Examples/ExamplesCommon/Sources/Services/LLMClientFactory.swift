import Foundation
import LLMStructuredOutputs

/// LLMクライアントの生成を担当するファクトリー
public struct LLMClientFactory: Sendable {

    private let apiKeyUseCase: APIKeyUseCase

    public init(apiKeyUseCase: APIKeyUseCase) {
        self.apiKeyUseCase = apiKeyUseCase
    }

    // MARK: - Client Creation

    /// Anthropic クライアントを生成
    public func createAnthropicClient() throws -> AnthropicClient {
        guard let apiKey = apiKeyUseCase.get(.anthropic) else {
            throw LLMClientFactoryError.missingAPIKey(.anthropic)
        }
        return AnthropicClient(apiKey: apiKey)
    }

    /// OpenAI クライアントを生成
    public func createOpenAIClient() throws -> OpenAIClient {
        guard let apiKey = apiKeyUseCase.get(.openai) else {
            throw LLMClientFactoryError.missingAPIKey(.openai)
        }
        return OpenAIClient(apiKey: apiKey)
    }

    /// Gemini クライアントを生成
    public func createGeminiClient() throws -> GeminiClient {
        guard let apiKey = apiKeyUseCase.get(.gemini) else {
            throw LLMClientFactoryError.missingAPIKey(.gemini)
        }
        return GeminiClient(apiKey: apiKey)
    }

    // MARK: - Convenience

    /// プロバイダーに対応するAPIキーが設定されているかチェック
    public func hasAPIKey(for provider: LLMProvider) -> Bool {
        apiKeyUseCase.has(provider.apiKeyType)
    }
}

// MARK: - Error

public enum LLMClientFactoryError: LocalizedError {
    case missingAPIKey(LLMProvider)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "\(provider.displayName) APIキーが設定されていません"
        }
    }
}
