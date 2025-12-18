import Foundation

/// セッション管理のビジネスロジックを担当
protocol SessionUseCase: Sendable {
    func listSessions() async throws -> [SessionData]
    func loadSession(id: UUID) async throws -> SessionData
    func saveSession(_ session: SessionData) async throws
    func deleteSession(id: UUID) async throws
    func createNewSession(
        provider: LLMProvider,
        outputType: AgentOutputType,
        interactiveMode: Bool
    ) -> SessionData
}

final class SessionUseCaseImpl: SessionUseCase {

    private let repository: SessionRepository

    init(repository: SessionRepository) {
        self.repository = repository
    }

    func listSessions() async throws -> [SessionData] {
        try await repository.list()
    }

    func loadSession(id: UUID) async throws -> SessionData {
        try await repository.load(id: id)
    }

    func saveSession(_ session: SessionData) async throws {
        guard !session.steps.isEmpty else { return }
        try await repository.save(session)
    }

    func deleteSession(id: UUID) async throws {
        try await repository.delete(id: id)
    }

    func createNewSession(
        provider: LLMProvider,
        outputType: AgentOutputType = .research,
        interactiveMode: Bool = true
    ) -> SessionData {
        SessionData(
            title: "新規セッション",
            provider: provider,
            outputType: outputType,
            interactiveMode: interactiveMode
        )
    }
}
