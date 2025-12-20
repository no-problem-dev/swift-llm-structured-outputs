import SwiftUI
import ExamplesCommon

/// アプリケーションの依存性
struct AppDependencies: Sendable {
    let apiKey: APIKeyUseCase
    let outputSchema: OutputSchemaUseCase
    let agent: AgentUseCase
    let session: SessionUseCase

    init() {
        let keychain = KeychainServiceImpl(serviceName: "com.example.agentbuilderexample")
        let fileStorage = FileStorageServiceImpl()

        let apiKeyRepository = APIKeyRepositoryImpl(keychain: keychain)
        let outputSchemaRepository = OutputSchemaRepositoryImpl(storage: fileStorage)
        let agentRepository = AgentRepository(storage: fileStorage)
        let sessionRepository = SessionRepository(storage: fileStorage)

        self.apiKey = APIKeyUseCaseImpl(repository: apiKeyRepository)
        self.outputSchema = OutputSchemaUseCaseImpl(repository: outputSchemaRepository)
        self.agent = AgentUseCase(repository: agentRepository)
        self.session = SessionUseCase(repository: sessionRepository)
    }
}

private struct UseCaseKey: EnvironmentKey {
    static let defaultValue: AppDependencies = AppDependencies()
}

extension EnvironmentValues {
    var useCase: AppDependencies {
        get { self[UseCaseKey.self] }
        set { self[UseCaseKey.self] = newValue }
    }
}
