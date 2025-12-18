import SwiftUI
import LLMStructuredOutputs

// MARK: - Provider

extension AppState.Provider {

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

// MARK: - ClaudeModel.Preset UI Extensions

extension ClaudeModel.Preset {

    var icon: String {
        switch self {
        case .opus: return "star.fill"
        case .sonnet: return "star.leadinghalf.filled"
        case .haiku: return "bolt.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .opus: return .purple
        case .sonnet: return .blue
        case .haiku: return .green
        }
    }
}

// MARK: - GPTModel.Preset UI Extensions

extension GPTModel.Preset {

    var icon: String {
        switch self {
        case .gpt4o: return "star.fill"
        case .gpt4oMini: return "bolt.fill"
        case .o1: return "brain"
        case .o3Mini: return "brain.head.profile"
        }
    }

    var tintColor: Color {
        switch self {
        case .gpt4o: return .green
        case .gpt4oMini: return .teal
        case .o1: return .indigo
        case .o3Mini: return .purple
        }
    }
}

// MARK: - GeminiModel.Preset UI Extensions

extension GeminiModel.Preset {

    var icon: String {
        switch self {
        case .flash3: return "sparkles"
        case .pro25: return "star.fill"
        case .flash25: return "bolt.fill"
        case .flash25Lite: return "leaf.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .flash3: return .purple
        case .pro25: return .blue
        case .flash25: return .cyan
        case .flash25Lite: return .mint
        }
    }
}
