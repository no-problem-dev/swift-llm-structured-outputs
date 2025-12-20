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

    // MARK: - Agent Definitions & Sessions

    private(set) var definitions: [AgentDefinition] = []
    private(set) var sessions: [AgentSession] = []

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

    // MARK: - Agent Definitions

    func setDefinitions(_ defs: [AgentDefinition]) {
        definitions = defs
    }

    func addDefinition(_ definition: AgentDefinition) {
        definitions.insert(definition, at: 0)
    }

    func updateDefinition(_ definition: AgentDefinition) {
        guard let index = definitions.firstIndex(where: { $0.id == definition.id }) else {
            return
        }
        definitions[index] = definition
    }

    func deleteDefinition(id: UUID) {
        definitions.removeAll { $0.id == id }
        // Also remove associated sessions
        sessions.removeAll { $0.definitionId == id }
    }

    // MARK: - Agent Sessions

    func setSessions(_ sess: [AgentSession]) {
        sessions = sess
    }

    func addSession(_ session: AgentSession) {
        sessions.insert(session, at: 0)
    }

    func updateSession(_ session: AgentSession) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else {
            return
        }
        sessions[index] = session
    }

    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
    }

    /// 最近更新されたセッション（最大5件）
    var recentSessions: [AgentSession] {
        Array(sessions.sorted { $0.updatedAt > $1.updatedAt }.prefix(5))
    }

    // MARK: - Sync

    func syncKeyStatuses(from apiKey: APIKeyUseCase) {
        hasAnthropicKey = apiKey.has(.anthropic)
        hasOpenAIKey = apiKey.has(.openai)
        hasGeminiKey = apiKey.has(.gemini)
    }
}
