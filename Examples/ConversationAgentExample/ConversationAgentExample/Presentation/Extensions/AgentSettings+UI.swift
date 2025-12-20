import SwiftUI
import LLMStructuredOutputs
import ExamplesCommon

// MARK: - LLMProvider (Local)

/// ConversationAgentExample固有のLLMProvider拡張
/// ExamplesCommonのLLMProviderとは別の型（SessionData.swift定義）
extension LLMProvider {

    var displayName: String { rawValue }

    var shortName: String {
        switch self {
        case .anthropic: return "Claude"
        case .openai: return "GPT"
        case .gemini: return "Gemini"
        }
    }

    var icon: String {
        switch self {
        case .anthropic: return "brain"
        case .openai: return "sparkles"
        case .gemini: return "diamond"
        }
    }

    var tintColor: Color {
        switch self {
        case .anthropic: return .orange
        case .openai: return .green
        case .gemini: return .blue
        }
    }
}

// NOTE: ClaudeModel.Preset, GPTModel.Preset, GeminiModel.Preset の
// UI拡張（icon, tintColor）は ExamplesCommon から提供されます
