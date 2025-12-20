import SwiftUI

/// UseCase コンテナプロトコル
protocol UseCaseContainer: Sendable {
    var session: SessionUseCase { get }
    var conversation: ConversationUseCase { get }
    var execution: SessionExecutionUseCase { get }
    var apiKey: APIKeyUseCase { get }
}

/// アプリケーション依存関係
struct AppDependencies: UseCaseContainer, Sendable {
    let session: SessionUseCase
    let conversation: ConversationUseCase
    let execution: SessionExecutionUseCase
    let apiKey: APIKeyUseCase

    init() {
        let fileStorage = FileStorageServiceImpl()
        let keychain = KeychainServiceImpl()

        let sessionRepository = SessionRepositoryImpl(storage: fileStorage)
        let apiKeyRepository = APIKeyRepositoryImpl(keychain: keychain)

        let apiKeyUseCase = APIKeyUseCaseImpl(repository: apiKeyRepository)
        self.apiKey = apiKeyUseCase

        let agentService = AgentServiceImpl(apiKeyUseCase: apiKeyUseCase)

        self.session = SessionUseCaseImpl(repository: sessionRepository)
        self.conversation = ConversationUseCaseImpl(agentService: agentService)
        self.execution = SessionExecutionUseCaseImpl()
    }

    init(
        session: SessionUseCase,
        conversation: ConversationUseCase,
        execution: SessionExecutionUseCase,
        apiKey: APIKeyUseCase
    ) {
        self.session = session
        self.conversation = conversation
        self.execution = execution
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
