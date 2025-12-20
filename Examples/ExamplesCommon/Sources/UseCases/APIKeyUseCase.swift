import Foundation

/// APIキー管理のユースケース
public protocol APIKeyUseCase: Sendable {
    /// キーを取得
    func get(_ keyType: APIKeyType) -> String?

    /// キーを保存
    func set(_ keyType: APIKeyType, value: String?) throws

    /// 全キーを削除
    func deleteAll() throws

    /// 環境変数からKeychainへ同期
    func syncFromEnvironment()

    /// キーが存在するか
    func has(_ keyType: APIKeyType) -> Bool

    /// いずれかのLLMキーが存在するか
    var hasAnyLLMKey: Bool { get }
}

public final class APIKeyUseCaseImpl: APIKeyUseCase, Sendable {

    private let repository: APIKeyRepository

    public init(repository: APIKeyRepository) {
        self.repository = repository
    }

    public func get(_ keyType: APIKeyType) -> String? {
        repository.get(keyType)
    }

    public func set(_ keyType: APIKeyType, value: String?) throws {
        try repository.set(keyType, value: value)
    }

    public func deleteAll() throws {
        try repository.deleteAll()
    }

    public func syncFromEnvironment() {
        repository.syncFromEnvironment()
    }

    public func has(_ keyType: APIKeyType) -> Bool {
        repository.has(keyType)
    }

    public var hasAnyLLMKey: Bool {
        repository.hasAnyLLMKey
    }
}
