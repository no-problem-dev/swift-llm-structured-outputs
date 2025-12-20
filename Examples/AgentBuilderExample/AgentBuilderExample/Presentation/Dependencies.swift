import SwiftUI
import ExamplesCommon

// MARK: - AppDependencies

/// アプリケーションの依存性を管理
struct AppDependencies: Sendable {
    let apiKey: APIKeyUseCase
    let builtType: BuiltTypeUseCase
    let definition: AgentDefinitionUseCase
    let session: AgentSessionUseCase

    init() {
        // Infrastructure
        let keychain = KeychainServiceImpl(serviceName: "com.example.agentbuilderexample")
        let fileStorage = FileStorageServiceImpl()

        // Repository
        let apiKeyRepository = APIKeyRepositoryImpl(keychain: keychain)
        let builtTypeRepository = BuiltTypeRepositoryImpl(storage: fileStorage)
        let definitionRepository = AgentDefinitionRepository(storage: fileStorage)
        let sessionRepository = AgentSessionRepository(storage: fileStorage)

        // UseCase
        self.apiKey = APIKeyUseCaseImpl(repository: apiKeyRepository)
        self.builtType = BuiltTypeUseCaseImpl(repository: builtTypeRepository)
        self.definition = AgentDefinitionUseCase(repository: definitionRepository)
        self.session = AgentSessionUseCase(repository: sessionRepository)
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
