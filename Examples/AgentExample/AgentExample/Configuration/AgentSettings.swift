//
//  AgentSettings.swift
//  AgentExample
//
//  エージェント設定管理
//

import Foundation
import SwiftUI
import LLMStructuredOutputs

/// エージェント設定を管理
///
/// `@Observable` を使用してアプリ全体で設定を共有します。
/// プロバイダーとモデル選択は `UserDefaults` で永続化されます。
@Observable @MainActor
final class AgentSettings {

    // MARK: - Singleton

    static let shared = AgentSettings()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let selectedProvider = "agentexample.selectedProvider"
        static let claudeModelOption = "agentexample.claudeModelOption"
        static let gptModelOption = "agentexample.gptModelOption"
        static let maxSteps = "agentexample.maxSteps"
        static let maxTokens = "agentexample.maxTokens"
    }

    private init() {
        // UserDefaultsから復元
        if let providerRaw = UserDefaults.standard.string(forKey: Keys.selectedProvider),
           let provider = Provider(rawValue: providerRaw) {
            _selectedProvider = provider
        }

        if let claudeRaw = UserDefaults.standard.string(forKey: Keys.claudeModelOption),
           let claude = ClaudeModelOption(rawValue: claudeRaw) {
            _claudeModelOption = claude
        }

        if let gptRaw = UserDefaults.standard.string(forKey: Keys.gptModelOption),
           let gpt = GPTModelOption(rawValue: gptRaw) {
            _gptModelOption = gpt
        }

        if UserDefaults.standard.object(forKey: Keys.maxSteps) != nil {
            _maxSteps = UserDefaults.standard.integer(forKey: Keys.maxSteps)
        }

        if UserDefaults.standard.object(forKey: Keys.maxTokens) != nil {
            _maxTokens = UserDefaults.standard.integer(forKey: Keys.maxTokens)
        }
    }

    // MARK: - Provider Selection

    /// 利用可能なプロバイダー
    enum Provider: String, CaseIterable, Identifiable {
        case anthropic = "Anthropic (Claude)"
        case openai = "OpenAI (GPT)"

        var id: String { rawValue }

        var shortName: String {
            switch self {
            case .anthropic: return "Claude"
            case .openai: return "GPT"
            }
        }

        var hasAPIKey: Bool {
            switch self {
            case .anthropic: return APIKeyManager.hasAnthropicKey
            case .openai: return APIKeyManager.hasOpenAIKey
            }
        }
    }

    /// 選択中のプロバイダー
    var selectedProvider: Provider {
        get { _selectedProvider }
        set {
            _selectedProvider = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.selectedProvider)
        }
    }
    private var _selectedProvider: Provider = .anthropic

    // MARK: - Model Selection

    /// Claude モデル選択肢
    enum ClaudeModelOption: String, CaseIterable, Identifiable {
        case sonnet = "Claude Sonnet 4.5（バランス型）"
        case opus = "Claude Opus 4.5（最高性能）"
        case haiku = "Claude Haiku 4.5（高速）"

        var id: String { rawValue }

        var model: ClaudeModel {
            switch self {
            case .opus: return .opus
            case .sonnet: return .sonnet
            case .haiku: return .haiku
            }
        }

        var shortName: String {
            switch self {
            case .opus: return "Opus"
            case .sonnet: return "Sonnet"
            case .haiku: return "Haiku"
            }
        }
    }

    /// GPT モデル選択肢
    enum GPTModelOption: String, CaseIterable, Identifiable {
        case gpt4o = "GPT-4o（マルチモーダル）"
        case gpt4oMini = "GPT-4o mini（軽量版）"
        case o1 = "o1（推論特化）"

        var id: String { rawValue }

        var model: GPTModel {
            switch self {
            case .gpt4o: return .gpt4o
            case .gpt4oMini: return .gpt4oMini
            case .o1: return .o1
            }
        }

        var shortName: String {
            switch self {
            case .gpt4o: return "4o"
            case .gpt4oMini: return "4o mini"
            case .o1: return "o1"
            }
        }
    }

    /// 選択中の Claude モデル
    var claudeModelOption: ClaudeModelOption {
        get { _claudeModelOption }
        set {
            _claudeModelOption = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.claudeModelOption)
        }
    }
    private var _claudeModelOption: ClaudeModelOption = .sonnet

    /// 選択中の GPT モデル
    var gptModelOption: GPTModelOption {
        get { _gptModelOption }
        set {
            _gptModelOption = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.gptModelOption)
        }
    }
    private var _gptModelOption: GPTModelOption = .gpt4o

    // MARK: - Agent Configuration

    /// エージェントの最大ステップ数
    var maxSteps: Int {
        get { _maxSteps }
        set {
            _maxSteps = max(1, min(20, newValue))
            UserDefaults.standard.set(_maxSteps, forKey: Keys.maxSteps)
        }
    }
    private var _maxSteps: Int = 10

    /// 最大出力トークン数
    var maxTokens: Int {
        get { _maxTokens }
        set {
            _maxTokens = max(1024, min(32768, newValue))
            UserDefaults.standard.set(_maxTokens, forKey: Keys.maxTokens)
        }
    }
    private var _maxTokens: Int = 16384

    // MARK: - Computed Properties

    /// 現在のプロバイダーのモデル名（表示用）
    var currentModelDisplayName: String {
        switch selectedProvider {
        case .anthropic: return claudeModelOption.shortName
        case .openai: return gptModelOption.shortName
        }
    }

    /// 現在のプロバイダーが利用可能か
    var isCurrentProviderAvailable: Bool {
        selectedProvider.hasAPIKey
    }

    /// Brave Search が利用可能か
    var isBraveSearchAvailable: Bool {
        APIKeyManager.hasBraveSearchKey
    }

    // MARK: - Client Factory

    /// Anthropic クライアントを作成
    func createAnthropicClient() -> AnthropicClient? {
        guard let apiKey = APIKeyManager.anthropicKey else { return nil }
        return AnthropicClient(apiKey: apiKey)
    }

    /// OpenAI クライアントを作成
    func createOpenAIClient() -> OpenAIClient? {
        guard let apiKey = APIKeyManager.openAIKey else { return nil }
        return OpenAIClient(apiKey: apiKey)
    }

    /// AgentConfiguration を作成
    func createAgentConfiguration() -> AgentConfiguration {
        AgentConfiguration(maxSteps: maxSteps, autoExecuteTools: true)
    }
}
