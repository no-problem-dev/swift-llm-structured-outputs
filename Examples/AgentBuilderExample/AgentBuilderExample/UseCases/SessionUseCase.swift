import Foundation
import LLMClient

/// セッション管理のユースケース
struct SessionUseCase: Sendable {
    private let repository: SessionRepository

    init(repository: SessionRepository) {
        self.repository = repository
    }

    func fetchAll() throws -> [Session] {
        try repository.fetchAll()
    }

    func fetch(id: UUID) throws -> Session? {
        try repository.fetch(id: id)
    }

    func fetchByAgent(id: UUID) throws -> [Session] {
        try repository.fetchByAgent(id: id)
    }

    func fetchRecent(limit: Int = 10) throws -> [Session] {
        Array(try repository.fetchAll().sorted { $0.updatedAt > $1.updatedAt }.prefix(limit))
    }

    func create(agentId: UUID, provider: String = "anthropic") -> Session {
        Session(agentId: agentId, provider: provider)
    }

    func save(_ session: Session) throws {
        var updated = session
        updated.updatedAt = Date()
        try repository.save(updated)
    }

    func delete(id: UUID) throws {
        try repository.delete(id: id)
    }

    func deleteByAgent(id: UUID) throws {
        try repository.deleteByAgent(id: id)
    }

    func addMessage(_ message: LLMMessage, to session: Session) throws -> Session {
        var updated = session
        updated.addMessage(message)
        try repository.save(updated)
        return updated
    }

    func updateStatus(_ status: Session.Status, for session: Session) throws -> Session {
        var updated = session
        updated.updateStatus(status)
        try repository.save(updated)
        return updated
    }
}
