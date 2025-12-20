import Foundation
import ExamplesCommon

/// エージェントセッションの永続化を担当するリポジトリ
final class AgentSessionRepository: @unchecked Sendable {
    private let storage: FileStorageService
    private let directory: URL

    init(storage: FileStorageService) {
        self.storage = storage

        // Documents/AgentSessions ディレクトリを使用
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        self.directory = documentsPath.appendingPathComponent("AgentSessions", isDirectory: true)
    }

    // MARK: - CRUD Operations

    /// 全てのセッションを取得
    func fetchAll() throws -> [AgentSession] {
        guard storage.exists(at: directory) else {
            return []
        }

        let files = try storage.listFiles(in: directory, withExtension: "json")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var sessions: [AgentSession] = []
        for file in files {
            do {
                let data = try storage.load(from: file)
                let session = try decoder.decode(AgentSession.self, from: data)
                sessions.append(session)
            } catch {
                // 読み込めないファイルはスキップ
                continue
            }
        }

        // 更新日時でソート（新しい順）
        return sessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// IDでセッションを取得
    func fetch(id: UUID) throws -> AgentSession? {
        let filePath = fileURL(for: id)
        guard storage.exists(at: filePath) else {
            return nil
        }

        let data = try storage.load(from: filePath)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(AgentSession.self, from: data)
    }

    /// 定義IDでセッションを取得
    func fetchByDefinition(id: UUID) throws -> [AgentSession] {
        let sessions = try fetchAll()
        return sessions.filter { $0.definitionId == id }
    }

    /// アクティブなセッションを取得
    func fetchActive() throws -> [AgentSession] {
        let sessions = try fetchAll()
        return sessions.filter { $0.status == .active }
    }

    /// セッションを保存
    func save(_ session: AgentSession) throws {
        try storage.ensureDirectory(directory)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(session)
        let filePath = fileURL(for: session.id)
        try storage.save(data, to: filePath)
    }

    /// セッションを削除
    func delete(id: UUID) throws {
        let filePath = fileURL(for: id)
        if storage.exists(at: filePath) {
            try storage.delete(at: filePath)
        }
    }

    /// 定義に紐づくセッションを全て削除
    func deleteByDefinition(id: UUID) throws {
        let sessions = try fetchByDefinition(id: id)
        for session in sessions {
            try delete(id: session.id)
        }
    }

    /// 複数のセッションを一括保存
    func saveAll(_ sessions: [AgentSession]) throws {
        for session in sessions {
            try save(session)
        }
    }

    // MARK: - Private

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }
}
