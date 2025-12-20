import Foundation
import ExamplesCommon

// MARK: - BuiltTypeRepository

/// 型定義の永続化リポジトリ
public protocol BuiltTypeRepository: Sendable {
    /// 型定義を保存
    func save(_ type: BuiltType) throws

    /// 型定義を読み込み
    func load(id: UUID) throws -> BuiltType

    /// 全ての型定義を読み込み
    func loadAll() throws -> [BuiltType]

    /// 型定義を削除
    func delete(id: UUID) throws

    /// 全ての型定義を削除
    func deleteAll() throws
}

// MARK: - BuiltTypeRepositoryImpl

public final class BuiltTypeRepositoryImpl: BuiltTypeRepository, @unchecked Sendable {

    private let storage: FileStorageService
    private let directory: URL

    public init(storage: FileStorageService) {
        self.storage = storage

        // Documents/BuiltTypes ディレクトリを使用
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        self.directory = documentsPath.appendingPathComponent("BuiltTypes", isDirectory: true)
    }

    public func save(_ type: BuiltType) throws {
        try storage.ensureDirectory(directory)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(type)
        let filePath = fileURL(for: type.id)
        try storage.save(data, to: filePath)
    }

    public func load(id: UUID) throws -> BuiltType {
        let filePath = fileURL(for: id)
        let data = try storage.load(from: filePath)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(BuiltType.self, from: data)
    }

    public func loadAll() throws -> [BuiltType] {
        guard storage.exists(at: directory) else {
            return []
        }

        let files = try storage.listFiles(in: directory, withExtension: "json")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var types: [BuiltType] = []
        for file in files {
            do {
                let data = try storage.load(from: file)
                let builtType = try decoder.decode(BuiltType.self, from: data)
                types.append(builtType)
            } catch {
                // 読み込めないファイルはスキップ
                continue
            }
        }

        // 更新日時でソート（新しい順）
        return types.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func delete(id: UUID) throws {
        let filePath = fileURL(for: id)
        try storage.delete(at: filePath)
    }

    public func deleteAll() throws {
        guard storage.exists(at: directory) else {
            return
        }

        let files = try storage.listFiles(in: directory, withExtension: "json")
        for file in files {
            try? storage.delete(at: file)
        }
    }

    // MARK: - Private

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }
}
