import Foundation
import ExamplesCommon
import LLMStructuredOutputs

/// アプリ全体の状態
@MainActor @Observable
public final class AppState {
    public typealias Provider = LLMProvider
    public typealias ClaudeModelOption = ClaudeModel.Preset
    public typealias GPTModelOption = GPTModel.Preset
    public typealias GeminiModelOption = GeminiModel.Preset

    // API Key Status
    private(set) var hasAnthropicKey: Bool = false
    private(set) var hasOpenAIKey: Bool = false
    private(set) var hasGeminiKey: Bool = false

    // Provider & Model Selection
    private(set) var selectedProvider: Provider = .anthropic
    private(set) var claudeModelOption: ClaudeModelOption = .sonnet
    private(set) var gptModelOption: GPTModelOption = .gpt4o
    private(set) var geminiModelOption: GeminiModelOption = .flash25

    // Agent Configuration
    private(set) var maxSteps: Int = 30
    private(set) var maxTokens: Int = 16384

    // Output Schemas
    private(set) var outputSchemas: [OutputSchema] = []
    private(set) var selectedOutputSchema: OutputSchema?

    // Agents & Sessions
    private(set) var agents: [Agent] = []
    private(set) var sessions: [Session] = []

    // Computed Properties
    var hasAnyLLMKey: Bool { hasAnthropicKey || hasOpenAIKey || hasGeminiKey }

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

    var recentSessions: [Session] {
        Array(sessions.sorted { $0.updatedAt > $1.updatedAt }.prefix(5))
    }

    // API Key Setters
    func setAnthropicKeyStatus(_ hasKey: Bool) { hasAnthropicKey = hasKey }
    func setOpenAIKeyStatus(_ hasKey: Bool) { hasOpenAIKey = hasKey }
    func setGeminiKeyStatus(_ hasKey: Bool) { hasGeminiKey = hasKey }

    // Provider & Model Setters
    func setSelectedProvider(_ provider: Provider) { selectedProvider = provider }
    func setClaudeModelOption(_ option: ClaudeModelOption) { claudeModelOption = option }
    func setGPTModelOption(_ option: GPTModelOption) { gptModelOption = option }
    func setGeminiModelOption(_ option: GeminiModelOption) { geminiModelOption = option }

    // Agent Configuration Setters
    func setMaxSteps(_ value: Int) { maxSteps = max(1, min(50, value)) }
    func setMaxTokens(_ value: Int) { maxTokens = max(1024, min(32768, value)) }

    // Output Schemas
    func setOutputSchemas(_ schemas: [OutputSchema]) { outputSchemas = schemas }
    func addOutputSchema(_ schema: OutputSchema) { outputSchemas.insert(schema, at: 0) }
    func updateOutputSchema(_ schema: OutputSchema) {
        guard let index = outputSchemas.firstIndex(where: { $0.id == schema.id }) else { return }
        outputSchemas[index] = schema
    }
    func deleteOutputSchema(id: UUID) {
        outputSchemas.removeAll { $0.id == id }
        if selectedOutputSchema?.id == id { selectedOutputSchema = nil }
    }
    func setSelectedOutputSchema(_ schema: OutputSchema?) { selectedOutputSchema = schema }

    // Agents
    func setAgents(_ list: [Agent]) { agents = list }
    func addAgent(_ agent: Agent) { agents.insert(agent, at: 0) }
    func updateAgent(_ agent: Agent) {
        guard let index = agents.firstIndex(where: { $0.id == agent.id }) else { return }
        agents[index] = agent
    }
    func deleteAgent(id: UUID) {
        agents.removeAll { $0.id == id }
        sessions.removeAll { $0.agentId == id }
    }

    // Sessions
    func setSessions(_ list: [Session]) { sessions = list }
    func addSession(_ session: Session) { sessions.insert(session, at: 0) }
    func updateSession(_ session: Session) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions[index] = session
    }
    func deleteSession(id: UUID) { sessions.removeAll { $0.id == id } }

    // Sync
    func syncKeyStatuses(from apiKey: APIKeyUseCase) {
        hasAnthropicKey = apiKey.has(.anthropic)
        hasOpenAIKey = apiKey.has(.openai)
        hasGeminiKey = apiKey.has(.gemini)
    }
}
