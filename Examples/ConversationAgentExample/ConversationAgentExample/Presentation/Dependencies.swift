import SwiftUI

/// UseCase コンテナプロトコル
protocol UseCaseContainer: Sendable {
    var session: SessionUseCase { get }
    var conversation: ConversationUseCase { get }
    var apiKey: APIKeyUseCase { get }
}

/// アプリケーション依存関係
struct AppDependencies: UseCaseContainer, Sendable {
    let session: SessionUseCase
    let conversation: ConversationUseCase
    let apiKey: APIKeyUseCase

    init() {
        // Infrastructure
        let fileStorage = FileStorageServiceImpl()
        let keychain = KeychainServiceImpl()

        // Repository
        let sessionRepository = SessionRepositoryImpl(storage: fileStorage)
        let apiKeyRepository = APIKeyRepositoryImpl(keychain: keychain)

        // UseCase (APIKey first - needed by AgentService)
        let apiKeyUseCase = APIKeyUseCaseImpl(repository: apiKeyRepository)
        self.apiKey = apiKeyUseCase

        // Service (depends on APIKeyUseCase)
        let agentService = AgentServiceImpl(apiKeyUseCase: apiKeyUseCase)

        // UseCase
        self.session = SessionUseCaseImpl(repository: sessionRepository)
        self.conversation = ConversationUseCaseImpl(agentService: agentService)
    }

    init(
        session: SessionUseCase,
        conversation: ConversationUseCase,
        apiKey: APIKeyUseCase
    ) {
        self.session = session
        self.conversation = conversation
        self.apiKey = apiKey
    }
}

// MARK: - Environment Keys

private struct UseCaseKey: EnvironmentKey {
    static let defaultValue: any UseCaseContainer = AppDependencies()
}

// MARK: - EnvironmentValues Extension

extension EnvironmentValues {
    var useCase: any UseCaseContainer {
        get { self[UseCaseKey.self] }
        set { self[UseCaseKey.self] = newValue }
    }
}
