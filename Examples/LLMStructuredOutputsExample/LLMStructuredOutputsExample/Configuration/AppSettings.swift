//
//  AppSettings.swift
//  LLMStructuredOutputsExample
//
//  アプリ全体で共有される設定
//

import Foundation
import SwiftUI
import LLMStructuredOutputs

/// アプリ全体の設定を管理
///
/// `@Observable` を使用してアプリ全体で設定を共有します。
/// 設定を変更すると、すべてのデモ画面に反映されます。
/// プロバイダーとモデル選択は `UserDefaults` で永続化されます。
@Observable @MainActor
final class AppSettings {

    // MARK: - Singleton

    /// 共有インスタンス
    static let shared = AppSettings()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let selectedProvider = "selectedProvider"
        static let claudeModelOption = "claudeModelOption"
        static let gptModelOption = "gptModelOption"
        static let geminiModelOption = "geminiModelOption"
        static let temperature = "temperature"
        static let maxTokens = "maxTokens"
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

        if let geminiRaw = UserDefaults.standard.string(forKey: Keys.geminiModelOption),
           let gemini = GeminiModelOption(rawValue: geminiRaw) {
            _geminiModelOption = gemini
        }

        if UserDefaults.standard.object(forKey: Keys.temperature) != nil {
            _temperature = UserDefaults.standard.double(forKey: Keys.temperature)
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
        case gemini = "Google (Gemini)"

        var id: String { rawValue }

        /// プロバイダーの短縮名
        var shortName: String {
            switch self {
            case .anthropic: return "Claude"
            case .openai: return "GPT"
            case .gemini: return "Gemini"
            }
        }

        /// APIキーが設定されているか
        var hasAPIKey: Bool {
            switch self {
            case .anthropic: return APIKeyManager.hasAnthropicKey
            case .openai: return APIKeyManager.hasOpenAIKey
            case .gemini: return APIKeyManager.hasGeminiKey
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
        case opus = "Claude Opus 4.5（最高性能）"
        case sonnet = "Claude Sonnet 4.5（バランス型）"
        case haiku = "Claude Haiku 4.5（高速）"

        var id: String { rawValue }

        var model: ClaudeModel {
            switch self {
            case .opus: return .opus
            case .sonnet: return .sonnet
            case .haiku: return .haiku
            }
        }
    }

    /// GPT モデル選択肢
    enum GPTModelOption: String, CaseIterable, Identifiable {
        case gpt4o = "GPT-4o（マルチモーダル）"
        case gpt4oMini = "GPT-4o mini（軽量版）"
        case o1 = "o1（推論特化）"
        case o3Mini = "o3-mini（軽量推論）"

        var id: String { rawValue }

        var model: GPTModel {
            switch self {
            case .gpt4o: return .gpt4o
            case .gpt4oMini: return .gpt4oMini
            case .o1: return .o1
            case .o3Mini: return .o3Mini
            }
        }
    }

    /// Gemini モデル選択肢
    enum GeminiModelOption: String, CaseIterable, Identifiable {
        case pro25 = "Gemini 2.5 Pro（最高性能）"
        case flash25 = "Gemini 2.5 Flash（高速）"
        case flash25Lite = "Gemini 2.5 Flash-Lite（軽量）"

        var id: String { rawValue }

        var model: GeminiModel {
            switch self {
            case .pro25: return .pro25
            case .flash25: return .flash25
            case .flash25Lite: return .flash25Lite
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

    /// 選択中の Gemini モデル
    var geminiModelOption: GeminiModelOption {
        get { _geminiModelOption }
        set {
            _geminiModelOption = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.geminiModelOption)
        }
    }
    private var _geminiModelOption: GeminiModelOption = .flash25

    // MARK: - Generation Parameters

    /// Temperature（創造性パラメータ）
    /// 0.0: 決定的、1.0: ランダム
    var temperature: Double {
        get { _temperature }
        set {
            _temperature = newValue
            UserDefaults.standard.set(newValue, forKey: Keys.temperature)
        }
    }
    private var _temperature: Double = 0.7

    /// 最大トークン数
    var maxTokens: Int {
        get { _maxTokens }
        set {
            _maxTokens = newValue
            UserDefaults.standard.set(newValue, forKey: Keys.maxTokens)
        }
    }
    private var _maxTokens: Int = 1024

    // MARK: - Computed Properties

    /// 現在のプロバイダーのモデル名（表示用）
    var currentModelDisplayName: String {
        switch selectedProvider {
        case .anthropic: return claudeModelOption.rawValue
        case .openai: return gptModelOption.rawValue
        case .gemini: return geminiModelOption.rawValue
        }
    }

    /// 現在のプロバイダーが利用可能か
    var isCurrentProviderAvailable: Bool {
        selectedProvider.hasAPIKey
    }

    // MARK: - Client Factory

    /// 現在の設定で Anthropic クライアントを作成
    func createAnthropicClient() -> AnthropicClient? {
        guard let apiKey = APIKeyManager.anthropicKey else { return nil }
        return AnthropicClient(apiKey: apiKey)
    }

    /// 現在の設定で OpenAI クライアントを作成
    func createOpenAIClient() -> OpenAIClient? {
        guard let apiKey = APIKeyManager.openAIKey else { return nil }
        return OpenAIClient(apiKey: apiKey)
    }

    /// 現在の設定で Gemini クライアントを作成
    func createGeminiClient() -> GeminiClient? {
        guard let apiKey = APIKeyManager.geminiKey else { return nil }
        return GeminiClient(apiKey: apiKey)
    }
}
