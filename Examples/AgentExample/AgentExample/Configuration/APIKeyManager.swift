//
//  APIKeyManager.swift
//  AgentExample
//
//  APIキー管理（LLM + 外部API）
//

import Foundation

/// APIキー管理
///
/// 環境変数からAPIキーを取得し、UserDefaultsに永続化します。
/// 一度設定すれば、環境変数を削除してもキーが保持されます。
///
/// ## 設定方法
/// ### 方法A: 環境変数（初回設定時）
/// 1. Xcode で Product > Scheme > Edit Scheme を開く
/// 2. Run > Arguments タブを選択
/// 3. Environment Variables に追加:
///    - `ANTHROPIC_API_KEY`: Anthropic の API キー
///    - `OPENAI_API_KEY`: OpenAI の API キー
///    - `BRAVE_SEARCH_API_KEY`: Brave Search の API キー（任意）
///
/// ### 方法B: アプリ内設定
/// 設定画面からAPIキーを直接入力できます。
enum APIKeyManager {

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let anthropic = "com.example.agentexample.anthropic_api_key"
        static let openAI = "com.example.agentexample.openai_api_key"
        static let gemini = "com.example.agentexample.gemini_api_key"
        static let braveSearch = "com.example.agentexample.brave_search_api_key"
    }

    // MARK: - Initialization

    /// 起動時に環境変数からUserDefaultsへ保存
    static func syncFromEnvironment() {
        if let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !key.isEmpty {
            setAnthropicKey(key)
        }
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty {
            setOpenAIKey(key)
        }
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !key.isEmpty {
            setGeminiKey(key)
        }
        if let key = ProcessInfo.processInfo.environment["BRAVE_SEARCH_API_KEY"], !key.isEmpty {
            setBraveSearchKey(key)
        }
    }

    // MARK: - LLM API Keys (Read)

    /// Anthropic API キー
    static var anthropicKey: String? {
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        return UserDefaults.standard.string(forKey: Keys.anthropic)
    }

    /// OpenAI API キー
    static var openAIKey: String? {
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        return UserDefaults.standard.string(forKey: Keys.openAI)
    }

    /// Gemini API キー
    static var geminiKey: String? {
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        return UserDefaults.standard.string(forKey: Keys.gemini)
    }

    // MARK: - External API Keys (Read)

    /// Brave Search API キー
    static var braveSearchKey: String? {
        if let envKey = ProcessInfo.processInfo.environment["BRAVE_SEARCH_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        return UserDefaults.standard.string(forKey: Keys.braveSearch)
    }

    // MARK: - LLM API Keys (Write)

    /// Anthropic API キーを保存
    static func setAnthropicKey(_ key: String?) {
        if let key = key, !key.isEmpty {
            UserDefaults.standard.set(key, forKey: Keys.anthropic)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.anthropic)
        }
    }

    /// OpenAI API キーを保存
    static func setOpenAIKey(_ key: String?) {
        if let key = key, !key.isEmpty {
            UserDefaults.standard.set(key, forKey: Keys.openAI)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.openAI)
        }
    }

    /// Gemini API キーを保存
    static func setGeminiKey(_ key: String?) {
        if let key = key, !key.isEmpty {
            UserDefaults.standard.set(key, forKey: Keys.gemini)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.gemini)
        }
    }

    // MARK: - External API Keys (Write)

    /// Brave Search API キーを保存
    static func setBraveSearchKey(_ key: String?) {
        if let key = key, !key.isEmpty {
            UserDefaults.standard.set(key, forKey: Keys.braveSearch)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.braveSearch)
        }
    }

    /// すべてのAPIキーをクリア
    static func clearAllKeys() {
        UserDefaults.standard.removeObject(forKey: Keys.anthropic)
        UserDefaults.standard.removeObject(forKey: Keys.openAI)
        UserDefaults.standard.removeObject(forKey: Keys.gemini)
        UserDefaults.standard.removeObject(forKey: Keys.braveSearch)
    }

    // MARK: - Validation

    /// Anthropic API キーが設定されているか
    static var hasAnthropicKey: Bool {
        guard let key = anthropicKey else { return false }
        return !key.isEmpty
    }

    /// OpenAI API キーが設定されているか
    static var hasOpenAIKey: Bool {
        guard let key = openAIKey else { return false }
        return !key.isEmpty
    }

    /// Gemini API キーが設定されているか
    static var hasGeminiKey: Bool {
        guard let key = geminiKey else { return false }
        return !key.isEmpty
    }

    /// Brave Search API キーが設定されているか
    static var hasBraveSearchKey: Bool {
        guard let key = braveSearchKey else { return false }
        return !key.isEmpty
    }

    /// いずれかの LLM API キーが設定されているか
    static var hasAnyLLMKey: Bool {
        hasAnthropicKey || hasOpenAIKey || hasGeminiKey
    }

    // MARK: - Status

    /// 各APIキーの設定状態
    struct KeyStatus {
        let anthropic: Bool
        let openAI: Bool
        let gemini: Bool
        let braveSearch: Bool

        var llmConfiguredCount: Int {
            [anthropic, openAI, gemini].filter { $0 }.count
        }
    }

    /// 現在のAPIキー設定状態を取得
    static var status: KeyStatus {
        KeyStatus(
            anthropic: hasAnthropicKey,
            openAI: hasOpenAIKey,
            gemini: hasGeminiKey,
            braveSearch: hasBraveSearchKey
        )
    }
}
