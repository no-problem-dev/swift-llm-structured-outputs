import Foundation
import LLMClient

/// エージェントセッションのユースケース
struct AgentSessionUseCase: Sendable {
    private let repository: AgentSessionRepository

    init(repository: AgentSessionRepository) {
        self.repository = repository
    }

    // MARK: - Query

    /// 全てのセッションを取得
    func fetchAll() throws -> [AgentSession] {
        try repository.fetchAll()
    }

    /// IDでセッションを取得
    func fetch(id: UUID) throws -> AgentSession? {
        try repository.fetch(id: id)
    }

    /// 定義IDでセッションを取得
    func fetchByDefinition(id: UUID) throws -> [AgentSession] {
        try repository.fetchByDefinition(id: id)
    }

    /// アクティブなセッションを取得
    func fetchActive() throws -> [AgentSession] {
        try repository.fetchActive()
    }

    /// 最近のセッションを取得（最大件数指定）
    func fetchRecent(limit: Int = 10) throws -> [AgentSession] {
        let sessions = try repository.fetchAll()
        return Array(sessions.sorted { $0.updatedAt > $1.updatedAt }.prefix(limit))
    }

    // MARK: - Command

    /// 新規セッションを作成
    func create(definitionId: UUID, provider: String = "anthropic") -> AgentSession {
        AgentSession(
            definitionId: definitionId,
            provider: provider
        )
    }

    /// セッションを保存
    func save(_ session: AgentSession) throws {
        var updated = session
        updated.updatedAt = Date()
        try repository.save(updated)
    }

    /// セッションを削除
    func delete(id: UUID) throws {
        try repository.delete(id: id)
    }

    /// 定義に紐づくセッションを全て削除
    func deleteByDefinition(id: UUID) throws {
        try repository.deleteByDefinition(id: id)
    }

    /// メッセージを追加してセッションを更新
    func addMessage(_ message: LLMMessage, to session: AgentSession) throws -> AgentSession {
        var updated = session
        updated.addMessage(message)
        try repository.save(updated)
        return updated
    }

    /// セッションのステータスを更新
    func updateStatus(_ status: AgentSession.Status, for session: AgentSession) throws -> AgentSession {
        var updated = session
        updated.updateStatus(status)
        try repository.save(updated)
        return updated
    }
}
