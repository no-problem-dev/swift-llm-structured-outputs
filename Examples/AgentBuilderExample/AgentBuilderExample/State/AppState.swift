import Foundation
import ExamplesCommon
import LLMStructuredOutputs

/// アプリ全体の状態を保持
@MainActor @Observable
public final class AppState {

    // MARK: - Types

    public typealias Provider = LLMProvider

    public typealias ClaudeModelOption = ClaudeModel.Preset
    public typealias GPTModelOption = GPTModel.Preset
    public typealias GeminiModelOption = GeminiModel.Preset

    // MARK: - API Key Status

    private(set) var hasAnthropicKey: Bool = false
    private(set) var hasOpenAIKey: Bool = false
    private(set) var hasGeminiKey: Bool = false

    // MARK: - Provider & Model Selection

    private(set) var selectedProvider: Provider = .anthropic
    private(set) var claudeModelOption: ClaudeModelOption = .sonnet
    private(set) var gptModelOption: GPTModelOption = .gpt4o
    private(set) var geminiModelOption: GeminiModelOption = .flash25

    // MARK: - Agent Configuration

    private(set) var maxSteps: Int = 30
    private(set) var maxTokens: Int = 16384

    // MARK: - Built Types

    private(set) var builtTypes: [BuiltType] = []
    private(set) var selectedBuiltType: BuiltType?

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

    // MARK: - API Key Setters

    func setAnthropicKeyStatus(_ hasKey: Bool) {
        hasAnthropicKey = hasKey
    }

    func setOpenAIKeyStatus(_ hasKey: Bool) {
        hasOpenAIKey = hasKey
    }

    func setGeminiKeyStatus(_ hasKey: Bool) {
        hasGeminiKey = hasKey
    }

    // MARK: - Provider & Model Setters

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

    // MARK: - Agent Configuration Setters

    func setMaxSteps(_ value: Int) {
        maxSteps = max(1, min(50, value))
    }

    func setMaxTokens(_ value: Int) {
        maxTokens = max(1024, min(32768, value))
    }

    // MARK: - Built Types

    func setBuiltTypes(_ types: [BuiltType]) {
        builtTypes = types
    }

    func addBuiltType(_ type: BuiltType) {
        builtTypes.insert(type, at: 0)
    }

    func updateBuiltType(_ type: BuiltType) {
        guard let index = builtTypes.firstIndex(where: { $0.id == type.id }) else {
            return
        }
        builtTypes[index] = type
    }

    func deleteBuiltType(id: UUID) {
        builtTypes.removeAll { $0.id == id }
        if selectedBuiltType?.id == id {
            selectedBuiltType = nil
        }
    }

    func setSelectedBuiltType(_ type: BuiltType?) {
        selectedBuiltType = type
    }

    // MARK: - Sync

    func syncKeyStatuses(from apiKey: APIKeyUseCase) {
        hasAnthropicKey = apiKey.has(.anthropic)
        hasOpenAIKey = apiKey.has(.openai)
        hasGeminiKey = apiKey.has(.gemini)
    }
}
