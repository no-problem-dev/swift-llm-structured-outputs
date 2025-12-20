import SwiftUI
import ExamplesCommon

// MARK: - AppDependencies

/// アプリケーションの依存性を管理
struct AppDependencies: Sendable {
    let apiKey: APIKeyUseCase
    let builtType: BuiltTypeUseCase

    init() {
        // Infrastructure
        let keychain = KeychainServiceImpl(serviceName: "com.example.agentbuilderexample")
        let fileStorage = FileStorageServiceImpl()

        // Repository
        let apiKeyRepository = APIKeyRepositoryImpl(keychain: keychain)
        let builtTypeRepository = BuiltTypeRepositoryImpl(storage: fileStorage)

        // UseCase
        self.apiKey = APIKeyUseCaseImpl(repository: apiKeyRepository)
        self.builtType = BuiltTypeUseCaseImpl(repository: builtTypeRepository)
    }
}

// MARK: - Environment Key

private struct UseCaseKey: EnvironmentKey {
    static let defaultValue: AppDependencies = AppDependencies()
}

extension EnvironmentValues {
    var useCase: AppDependencies {
        get { self[UseCaseKey.self] }
        set { self[UseCaseKey.self] = newValue }
    }
}
