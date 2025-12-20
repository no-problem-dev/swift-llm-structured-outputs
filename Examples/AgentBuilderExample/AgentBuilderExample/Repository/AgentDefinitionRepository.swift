import Foundation
import ExamplesCommon

/// エージェント定義の永続化を担当するリポジトリ
final class AgentDefinitionRepository: @unchecked Sendable {
    private let storage: FileStorageService
    private let directory: URL

    init(storage: FileStorageService) {
        self.storage = storage

        // Documents/AgentDefinitions ディレクトリを使用
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        self.directory = documentsPath.appendingPathComponent("AgentDefinitions", isDirectory: true)
    }

    // MARK: - CRUD Operations

    /// 全ての定義を取得
    func fetchAll() throws -> [AgentDefinition] {
        guard storage.exists(at: directory) else {
            return []
        }

        let files = try storage.listFiles(in: directory, withExtension: "json")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var definitions: [AgentDefinition] = []
        for file in files {
            do {
                let data = try storage.load(from: file)
                let definition = try decoder.decode(AgentDefinition.self, from: data)
                definitions.append(definition)
            } catch {
                // 読み込めないファイルはスキップ
                continue
            }
        }

        // 更新日時でソート（新しい順）
        return definitions.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// IDで定義を取得
    func fetch(id: UUID) throws -> AgentDefinition? {
        let filePath = fileURL(for: id)
        guard storage.exists(at: filePath) else {
            return nil
        }

        let data = try storage.load(from: filePath)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(AgentDefinition.self, from: data)
    }

    /// 定義を保存
    func save(_ definition: AgentDefinition) throws {
        try storage.ensureDirectory(directory)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(definition)
        let filePath = fileURL(for: definition.id)
        try storage.save(data, to: filePath)
    }

    /// 定義を削除
    func delete(id: UUID) throws {
        let filePath = fileURL(for: id)
        if storage.exists(at: filePath) {
            try storage.delete(at: filePath)
        }
    }

    /// 複数の定義を一括保存
    func saveAll(_ definitions: [AgentDefinition]) throws {
        for definition in definitions {
            try save(definition)
        }
    }

    // MARK: - Private

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }
}
