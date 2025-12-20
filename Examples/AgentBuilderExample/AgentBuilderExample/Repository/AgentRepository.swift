import Foundation
import ExamplesCommon

/// エージェント設定の永続化リポジトリ
final class AgentRepository: @unchecked Sendable {
    private let storage: FileStorageService
    private let directory: URL

    init(storage: FileStorageService) {
        self.storage = storage
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.directory = documentsPath.appendingPathComponent("Agents", isDirectory: true)
    }

    func fetchAll() throws -> [Agent] {
        guard storage.exists(at: directory) else { return [] }
        let files = try storage.listFiles(in: directory, withExtension: "json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var agents: [Agent] = []
        for file in files {
            if let data = try? storage.load(from: file),
               let agent = try? decoder.decode(Agent.self, from: data) {
                agents.append(agent)
            }
        }
        return agents.sorted { $0.updatedAt > $1.updatedAt }
    }

    func fetch(id: UUID) throws -> Agent? {
        let filePath = fileURL(for: id)
        guard storage.exists(at: filePath) else { return nil }
        let data = try storage.load(from: filePath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Agent.self, from: data)
    }

    func save(_ agent: Agent) throws {
        try storage.ensureDirectory(directory)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(agent)
        try storage.save(data, to: fileURL(for: agent.id))
    }

    func delete(id: UUID) throws {
        let filePath = fileURL(for: id)
        if storage.exists(at: filePath) {
            try storage.delete(at: filePath)
        }
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }
}
