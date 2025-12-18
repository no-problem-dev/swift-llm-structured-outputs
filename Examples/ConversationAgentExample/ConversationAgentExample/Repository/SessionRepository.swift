import Foundation

/// セッションデータの永続化を担当
protocol SessionRepository: Sendable {
    func list() async throws -> [SessionData]
    func load(id: UUID) async throws -> SessionData
    func save(_ session: SessionData) async throws
    func delete(id: UUID) async throws
}

enum SessionRepositoryError: LocalizedError {
    case sessionNotFound(UUID)
    case saveFailed(Error)
    case loadFailed(Error)
    case deleteFailed(Error)

    var errorDescription: String? {
        switch self {
        case .sessionNotFound(let id):
            return "セッションが見つかりません: \(id)"
        case .saveFailed(let error):
            return "保存に失敗しました: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "読み込みに失敗しました: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "削除に失敗しました: \(error.localizedDescription)"
        }
    }
}

final class SessionRepositoryImpl: SessionRepository, @unchecked Sendable {

    private let storage: FileStorageService
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var storageDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("ConversationSessions", isDirectory: true)
    }

    init(storage: FileStorageService = FileStorageServiceImpl()) {
        self.storage = storage

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    private func sessionFilePath(for id: UUID) -> URL {
        storageDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    func list() async throws -> [SessionData] {
        try storage.ensureDirectory(storageDirectory)

        let files: [URL]
        do {
            files = try storage.listFiles(in: storageDirectory, withExtension: "json")
        } catch {
            return []
        }

        var sessions: [SessionData] = []

        for fileURL in files {
            do {
                let data = try storage.load(from: fileURL)
                let session = try decoder.decode(SessionData.self, from: data)
                sessions.append(session)
            } catch {
                print("Warning: Failed to load session from \(fileURL.lastPathComponent): \(error)")
            }
        }

        return sessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    func load(id: UUID) async throws -> SessionData {
        let filePath = sessionFilePath(for: id)

        guard storage.exists(at: filePath) else {
            throw SessionRepositoryError.sessionNotFound(id)
        }

        do {
            let data = try storage.load(from: filePath)
            return try decoder.decode(SessionData.self, from: data)
        } catch {
            throw SessionRepositoryError.loadFailed(error)
        }
    }

    func save(_ session: SessionData) async throws {
        try storage.ensureDirectory(storageDirectory)

        let filePath = sessionFilePath(for: session.id)

        do {
            let data = try encoder.encode(session)
            try storage.save(data, to: filePath)
        } catch {
            throw SessionRepositoryError.saveFailed(error)
        }
    }

    func delete(id: UUID) async throws {
        let filePath = sessionFilePath(for: id)

        guard storage.exists(at: filePath) else {
            throw SessionRepositoryError.sessionNotFound(id)
        }

        do {
            try storage.delete(at: filePath)
        } catch {
            throw SessionRepositoryError.deleteFailed(error)
        }
    }
}
