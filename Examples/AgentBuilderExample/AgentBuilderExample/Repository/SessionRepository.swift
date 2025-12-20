import Foundation
import ExamplesCommon

/// セッションの永続化リポジトリ
final class SessionRepository: @unchecked Sendable {
    private let storage: FileStorageService
    private let directory: URL

    init(storage: FileStorageService) {
        self.storage = storage
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.directory = documentsPath.appendingPathComponent("Sessions", isDirectory: true)
    }

    func fetchAll() throws -> [Session] {
        guard storage.exists(at: directory) else { return [] }
        let files = try storage.listFiles(in: directory, withExtension: "json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var sessions: [Session] = []
        for file in files {
            if let data = try? storage.load(from: file),
               let session = try? decoder.decode(Session.self, from: data) {
                sessions.append(session)
            }
        }
        return sessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    func fetch(id: UUID) throws -> Session? {
        let filePath = fileURL(for: id)
        guard storage.exists(at: filePath) else { return nil }
        let data = try storage.load(from: filePath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Session.self, from: data)
    }

    func fetchByAgent(id: UUID) throws -> [Session] {
        try fetchAll().filter { $0.agentId == id }
    }

    func save(_ session: Session) throws {
        try storage.ensureDirectory(directory)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)
        try storage.save(data, to: fileURL(for: session.id))
    }

    func delete(id: UUID) throws {
        let filePath = fileURL(for: id)
        if storage.exists(at: filePath) {
            try storage.delete(at: filePath)
        }
    }

    func deleteByAgent(id: UUID) throws {
        for session in try fetchByAgent(id: id) {
            try delete(id: session.id)
        }
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }
}
