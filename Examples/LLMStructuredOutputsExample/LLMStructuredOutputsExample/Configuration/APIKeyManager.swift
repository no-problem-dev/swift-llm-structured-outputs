//
//  APIKeyManager.swift
//  LLMStructuredOutputsExample
//
//  APIキー管理（環境変数 + UserDefaults 永続化）
//

import Foundation

/// APIキー管理
///
/// 環境変数からAPIキーを取得し、UserDefaultsに永続化します。
/// 一度設定すれば、環境変数を削除してもキーが保持されます。
///
/// ## 優先順位
/// 1. 環境変数（設定されていればUserDefaultsに保存）
/// 2. UserDefaults（永続化されたキー）
///
/// ## 設定方法
/// ### 方法A: 環境変数（初回設定時）
/// 1. Xcode で Product > Scheme > Edit Scheme を開く
/// 2. Run > Arguments タブを選択
/// 3. Environment Variables に以下を追加:
///    - `ANTHROPIC_API_KEY`: Anthropic の API キー
///    - `OPENAI_API_KEY`: OpenAI の API キー
///    - `GEMINI_API_KEY`: Google Gemini の API キー
/// 4. 一度実行すると永続化されるので、環境変数は削除してOK
///
/// ### 方法B: アプリ内設定
/// 設定画面からAPIキーを直接入力できます。
enum APIKeyManager {

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let anthropic = "com.example.llmstructuredoutputs.anthropic_api_key"
        static let openAI = "com.example.llmstructuredoutputs.openai_api_key"
        static let gemini = "com.example.llmstructuredoutputs.gemini_api_key"
    }

    // MARK: - Initialization

    /// 起動時に環境変数からUserDefaultsへ保存
    /// AppDelegateまたはApp初期化時に呼び出す
    static func syncFromEnvironment() {
        // 環境変数が設定されていればUserDefaultsに保存
        if let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !key.isEmpty {
            setAnthropicKey(key)
        }
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty {
            setOpenAIKey(key)
        }
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !key.isEmpty {
            setGeminiKey(key)
        }
    }

    // MARK: - API Keys (Read)

    /// Anthropic API キー
    static var anthropicKey: String? {
        // 環境変数を優先
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        // UserDefaultsから取得
        return UserDefaults.standard.string(forKey: Keys.anthropic)
    }

    /// OpenAI API キー
    static var openAIKey: String? {
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        return UserDefaults.standard.string(forKey: Keys.openAI)
    }

    /// Google Gemini API キー
    static var geminiKey: String? {
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        return UserDefaults.standard.string(forKey: Keys.gemini)
    }

    // MARK: - API Keys (Write)

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

    /// すべてのAPIキーをクリア
    static func clearAllKeys() {
        UserDefaults.standard.removeObject(forKey: Keys.anthropic)
        UserDefaults.standard.removeObject(forKey: Keys.openAI)
        UserDefaults.standard.removeObject(forKey: Keys.gemini)
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

    /// いずれかの API キーが設定されているか
    static var hasAnyKey: Bool {
        hasAnthropicKey || hasOpenAIKey || hasGeminiKey
    }

    // MARK: - Status

    /// 各プロバイダーのAPIキー設定状態
    struct KeyStatus {
        let anthropic: Bool
        let openAI: Bool
        let gemini: Bool

        var configuredCount: Int {
            [anthropic, openAI, gemini].filter { $0 }.count
        }
    }

    /// 現在のAPIキー設定状態を取得
    static var status: KeyStatus {
        KeyStatus(
            anthropic: hasAnthropicKey,
            openAI: hasOpenAIKey,
            gemini: hasGeminiKey
        )
    }

    // MARK: - Source Info

    /// APIキーのソースを示す（デバッグ用）
    enum KeySource {
        case environment
        case userDefaults
        case notSet
    }

    /// Anthropic APIキーのソース
    static var anthropicKeySource: KeySource {
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            return .environment
        }
        if UserDefaults.standard.string(forKey: Keys.anthropic) != nil {
            return .userDefaults
        }
        return .notSet
    }

    /// OpenAI APIキーのソース
    static var openAIKeySource: KeySource {
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
            return .environment
        }
        if UserDefaults.standard.string(forKey: Keys.openAI) != nil {
            return .userDefaults
        }
        return .notSet
    }

    /// Gemini APIキーのソース
    static var geminiKeySource: KeySource {
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty {
            return .environment
        }
        if UserDefaults.standard.string(forKey: Keys.gemini) != nil {
            return .userDefaults
        }
        return .notSet
    }
}
