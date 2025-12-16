import Foundation

/// セッションストレージプロトコル
protocol SessionStorage: Sendable {
    /// 全セッションの一覧を取得
    func listSessions() async throws -> [SessionData]

    /// セッションを読み込み
    func load(id: UUID) async throws -> SessionData

    /// セッションを保存
    func save(_ session: SessionData) async throws

    /// セッションを削除
    func delete(id: UUID) async throws
}

// MARK: - SessionStorageError

enum SessionStorageError: LocalizedError {
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

// MARK: - JSONFileSessionStorage

/// JSON ファイルベースのセッションストレージ
///
/// セッションを `~/Documents/ConversationSessions/` に JSON 形式で保存します。
final class JSONFileSessionStorage: SessionStorage, @unchecked Sendable {
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// ストレージディレクトリ
    private var storageDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("ConversationSessions", isDirectory: true)
    }

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    /// ストレージディレクトリを確保
    private func ensureStorageDirectory() throws {
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }
    }

    /// セッションファイルのパスを取得
    private func sessionFilePath(for id: UUID) -> URL {
        storageDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    // MARK: - SessionStorage

    func listSessions() async throws -> [SessionData] {
        try ensureStorageDirectory()

        let contents = try fileManager.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )

        var sessions: [SessionData] = []

        for fileURL in contents where fileURL.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: fileURL)
                let session = try decoder.decode(SessionData.self, from: data)
                sessions.append(session)
            } catch {
                // 読み込めないファイルはスキップ
                print("Warning: Failed to load session from \(fileURL.lastPathComponent): \(error)")
            }
        }

        // 更新日時の降順でソート
        return sessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    func load(id: UUID) async throws -> SessionData {
        let filePath = sessionFilePath(for: id)

        guard fileManager.fileExists(atPath: filePath.path) else {
            throw SessionStorageError.sessionNotFound(id)
        }

        do {
            let data = try Data(contentsOf: filePath)
            return try decoder.decode(SessionData.self, from: data)
        } catch {
            throw SessionStorageError.loadFailed(error)
        }
    }

    func save(_ session: SessionData) async throws {
        try ensureStorageDirectory()

        let filePath = sessionFilePath(for: session.id)

        do {
            let data = try encoder.encode(session)
            try data.write(to: filePath, options: .atomic)
        } catch {
            throw SessionStorageError.saveFailed(error)
        }
    }

    func delete(id: UUID) async throws {
        let filePath = sessionFilePath(for: id)

        guard fileManager.fileExists(atPath: filePath.path) else {
            throw SessionStorageError.sessionNotFound(id)
        }

        do {
            try fileManager.removeItem(at: filePath)
        } catch {
            throw SessionStorageError.deleteFailed(error)
        }
    }
}
