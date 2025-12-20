import Foundation
import Security

/// Keychain操作の抽象化
public protocol KeychainService: Sendable {
    /// 値を保存
    func save(key: String, value: Data) throws

    /// 値を読み込み
    func load(key: String) -> Data?

    /// 値を削除
    func delete(key: String) throws

    /// 指定プレフィックスに一致する全ての値を削除
    func deleteAll() throws
}

public enum KeychainError: LocalizedError, Sendable {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case unexpectedData

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain保存に失敗しました (status: \(status))"
        case .deleteFailed(let status):
            return "Keychain削除に失敗しました (status: \(status))"
        case .unexpectedData:
            return "Keychainから予期しないデータ形式を取得しました"
        }
    }
}

public final class KeychainServiceImpl: KeychainService, @unchecked Sendable {

    private let serviceName: String

    public init(serviceName: String) {
        self.serviceName = serviceName
    }

    public func save(key: String, value: Data) throws {
        // 既存のアイテムを削除してから保存
        try? delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    public func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }

        return result as? Data
    }

    public func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    public func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
