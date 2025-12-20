import Foundation

/// LLMプロバイダーの種別
public enum LLMProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case anthropic
    case openai
    case gemini

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI"
        case .gemini: return "Google Gemini"
        }
    }

    /// 短い表示名（Claude, GPT, Gemini）
    public var shortName: String {
        switch self {
        case .anthropic: return "Claude"
        case .openai: return "GPT"
        case .gemini: return "Gemini"
        }
    }

    /// 対応するAPIKeyType
    public var apiKeyType: APIKeyType {
        switch self {
        case .anthropic: return .anthropic
        case .openai: return .openai
        case .gemini: return .gemini
        }
    }
}
