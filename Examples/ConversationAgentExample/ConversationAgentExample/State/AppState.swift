import Foundation
import LLMStructuredOutputs

/// アプリ全体の状態を保持
@MainActor @Observable
final class AppState {

    // MARK: - Types

    /// Domain の LLMProvider を参照
    typealias Provider = LLMProvider

    typealias ClaudeModelOption = ClaudeModel.Preset
    typealias GPTModelOption = GPTModel.Preset
    typealias GeminiModelOption = GeminiModel.Preset

    // MARK: - API Key Status

    private(set) var hasAnthropicKey: Bool = false
    private(set) var hasOpenAIKey: Bool = false
    private(set) var hasGeminiKey: Bool = false
    private(set) var hasBraveSearchKey: Bool = false

    // MARK: - Provider & Model Selection

    private(set) var selectedProvider: Provider = .anthropic
    private(set) var claudeModelOption: ClaudeModelOption = .sonnet
    private(set) var gptModelOption: GPTModelOption = .gpt4o
    private(set) var geminiModelOption: GeminiModelOption = .flash25

    // MARK: - Agent Configuration

    private(set) var maxSteps: Int = 10
    private(set) var maxTokens: Int = 16384

    // MARK: - Computed Properties

    var hasAnyLLMKey: Bool {
        hasAnthropicKey || hasOpenAIKey || hasGeminiKey
    }

    var currentModelDisplayName: String {
        switch selectedProvider {
        case .anthropic: claudeModelOption.shortName
        case .openai: gptModelOption.shortName
        case .gemini: geminiModelOption.shortName
        }
    }

    var isCurrentProviderAvailable: Bool {
        switch selectedProvider {
        case .anthropic: hasAnthropicKey
        case .openai: hasOpenAIKey
        case .gemini: hasGeminiKey
        }
    }

    // MARK: - Setters

    func setAnthropicKeyStatus(_ hasKey: Bool) {
        hasAnthropicKey = hasKey
    }

    func setOpenAIKeyStatus(_ hasKey: Bool) {
        hasOpenAIKey = hasKey
    }

    func setGeminiKeyStatus(_ hasKey: Bool) {
        hasGeminiKey = hasKey
    }

    func setBraveSearchKeyStatus(_ hasKey: Bool) {
        hasBraveSearchKey = hasKey
    }

    func setSelectedProvider(_ provider: Provider) {
        selectedProvider = provider
    }

    func setClaudeModelOption(_ option: ClaudeModelOption) {
        claudeModelOption = option
    }

    func setGPTModelOption(_ option: GPTModelOption) {
        gptModelOption = option
    }

    func setGeminiModelOption(_ option: GeminiModelOption) {
        geminiModelOption = option
    }

    func setMaxSteps(_ value: Int) {
        maxSteps = max(1, min(20, value))
    }

    func setMaxTokens(_ value: Int) {
        maxTokens = max(1024, min(32768, value))
    }

    // MARK: - Sync

    func syncKeyStatuses(from apiKey: APIKeyUseCase) {
        hasAnthropicKey = apiKey.has(.anthropic)
        hasOpenAIKey = apiKey.has(.openai)
        hasGeminiKey = apiKey.has(.gemini)
        hasBraveSearchKey = apiKey.has(.braveSearch)
    }
}
