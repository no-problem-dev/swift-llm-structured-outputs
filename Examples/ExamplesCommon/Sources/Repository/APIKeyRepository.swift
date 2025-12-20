import Foundation

/// APIキーの種別
public enum APIKeyType: String, CaseIterable, Sendable {
    case anthropic
    case openai
    case gemini
    case braveSearch

    /// 環境変数のキー名
    public var environmentKey: String {
        switch self {
        case .anthropic: return "ANTHROPIC_API_KEY"
        case .openai: return "OPENAI_API_KEY"
        case .gemini: return "GEMINI_API_KEY"
        case .braveSearch: return "BRAVE_SEARCH_API_KEY"
        }
    }

    /// Keychainのキー名
    public var keychainKey: String {
        "api_key_\(rawValue)"
    }

    /// LLMプロバイダー用キーかどうか
    public var isLLMKey: Bool {
        switch self {
        case .anthropic, .openai, .gemini: return true
        case .braveSearch: return false
        }
    }
}

/// APIキー管理リポジトリ
public protocol APIKeyRepository: Sendable {
    /// キーを取得（環境変数優先）
    func get(_ keyType: APIKeyType) -> String?

    /// キーを保存
    func set(_ keyType: APIKeyType, value: String?) throws

    /// キーを削除
    func delete(_ keyType: APIKeyType) throws

    /// 全キーを削除
    func deleteAll() throws

    /// 環境変数からKeychainへ同期
    func syncFromEnvironment()

    /// キーが存在するか
    func has(_ keyType: APIKeyType) -> Bool

    /// いずれかのLLMキーが存在するか
    var hasAnyLLMKey: Bool { get }
}

public final class APIKeyRepositoryImpl: APIKeyRepository, Sendable {

    private let keychain: KeychainService

    public init(keychain: KeychainService) {
        self.keychain = keychain
    }

    public func get(_ keyType: APIKeyType) -> String? {
        // 1. 環境変数を優先
        if let envValue = ProcessInfo.processInfo.environment[keyType.environmentKey],
           !envValue.isEmpty {
            return envValue
        }

        // 2. Keychainから取得
        guard let data = keychain.load(key: keyType.keychainKey),
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            return nil
        }

        return value
    }

    public func set(_ keyType: APIKeyType, value: String?) throws {
        if let value = value, !value.isEmpty {
            guard let data = value.data(using: .utf8) else { return }
            try keychain.save(key: keyType.keychainKey, value: data)
        } else {
            try keychain.delete(key: keyType.keychainKey)
        }
    }

    public func delete(_ keyType: APIKeyType) throws {
        try keychain.delete(key: keyType.keychainKey)
    }

    public func deleteAll() throws {
        try keychain.deleteAll()
    }

    public func syncFromEnvironment() {
        for keyType in APIKeyType.allCases {
            if let envValue = ProcessInfo.processInfo.environment[keyType.environmentKey],
               !envValue.isEmpty {
                try? set(keyType, value: envValue)
            }
        }
    }

    public func has(_ keyType: APIKeyType) -> Bool {
        get(keyType) != nil
    }

    public var hasAnyLLMKey: Bool {
        APIKeyType.allCases.filter(\.isLLMKey).contains { has($0) }
    }
}
