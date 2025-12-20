import Foundation
import ExamplesCommon

/// 出力スキーマの永続化リポジトリ
public protocol OutputSchemaRepository: Sendable {
    func save(_ schema: OutputSchema) throws
    func load(id: UUID) throws -> OutputSchema
    func loadAll() throws -> [OutputSchema]
    func delete(id: UUID) throws
    func deleteAll() throws
}

public final class OutputSchemaRepositoryImpl: OutputSchemaRepository, @unchecked Sendable {
    private let storage: FileStorageService
    private let directory: URL

    public init(storage: FileStorageService) {
        self.storage = storage
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.directory = documentsPath.appendingPathComponent("OutputSchemas", isDirectory: true)
    }

    public func save(_ schema: OutputSchema) throws {
        try storage.ensureDirectory(directory)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(schema)
        try storage.save(data, to: fileURL(for: schema.id))
    }

    public func load(id: UUID) throws -> OutputSchema {
        let data = try storage.load(from: fileURL(for: id))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(OutputSchema.self, from: data)
    }

    public func loadAll() throws -> [OutputSchema] {
        guard storage.exists(at: directory) else { return [] }
        let files = try storage.listFiles(in: directory, withExtension: "json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var schemas: [OutputSchema] = []
        for file in files {
            if let data = try? storage.load(from: file),
               let schema = try? decoder.decode(OutputSchema.self, from: data) {
                schemas.append(schema)
            }
        }
        return schemas.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func delete(id: UUID) throws {
        try storage.delete(at: fileURL(for: id))
    }

    public func deleteAll() throws {
        guard storage.exists(at: directory) else { return }
        for file in try storage.listFiles(in: directory, withExtension: "json") {
            try? storage.delete(at: file)
        }
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }
}
