import SwiftUI

// MARK: - Provider

extension AgentSettings.Provider {

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

// MARK: - ClaudeModelOption

extension AgentSettings.ClaudeModelOption {

    var displayName: String { rawValue }

    var shortName: String {
        switch self {
        case .opus: return "Opus"
        case .sonnet: return "Sonnet"
        case .haiku: return "Haiku"
        }
    }

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

// MARK: - GPTModelOption

extension AgentSettings.GPTModelOption {

    var displayName: String { rawValue }

    var shortName: String {
        switch self {
        case .gpt4o: return "4o"
        case .gpt4oMini: return "4o mini"
        case .o1: return "o1"
        }
    }

    var icon: String {
        switch self {
        case .gpt4o: return "star.fill"
        case .gpt4oMini: return "bolt.fill"
        case .o1: return "brain"
        }
    }

    var tintColor: Color {
        switch self {
        case .gpt4o: return .green
        case .gpt4oMini: return .teal
        case .o1: return .indigo
        }
    }
}

// MARK: - GeminiModelOption

extension AgentSettings.GeminiModelOption {

    var displayName: String { rawValue }

    var shortName: String {
        switch self {
        case .pro25: return "2.5 Pro"
        case .flash25: return "2.5 Flash"
        case .flash25Lite: return "2.5 Flash-Lite"
        }
    }

    var icon: String {
        switch self {
        case .pro25: return "star.fill"
        case .flash25: return "bolt.fill"
        case .flash25Lite: return "leaf.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .pro25: return .blue
        case .flash25: return .cyan
        case .flash25Lite: return .mint
        }
    }
}
