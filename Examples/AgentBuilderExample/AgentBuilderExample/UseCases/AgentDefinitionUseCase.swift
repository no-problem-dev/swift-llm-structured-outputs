import Foundation
import LLMClient

/// エージェント定義のユースケース
struct AgentDefinitionUseCase: Sendable {
    private let repository: AgentDefinitionRepository

    init(repository: AgentDefinitionRepository) {
        self.repository = repository
    }

    // MARK: - Query

    /// 全ての定義を取得
    func fetchAll() throws -> [AgentDefinition] {
        try repository.fetchAll()
    }

    /// IDで定義を取得
    func fetch(id: UUID) throws -> AgentDefinition? {
        try repository.fetch(id: id)
    }

    // MARK: - Command

    /// 新規定義を作成
    func create(name: String, description: String? = nil) -> AgentDefinition {
        AgentDefinition(
            name: name,
            description: description,
            outputType: BuiltType(name: "Output", description: nil, fields: [])
        )
    }

    /// 定義を保存
    func save(_ definition: AgentDefinition) throws {
        var updated = definition
        updated.updatedAt = Date()
        try repository.save(updated)
    }

    /// 定義を削除
    func delete(id: UUID) throws {
        try repository.delete(id: id)
    }

    /// 定義を複製
    func duplicate(_ definition: AgentDefinition) -> AgentDefinition {
        AgentDefinition(
            name: "\(definition.name) (コピー)",
            description: definition.description,
            outputType: definition.outputType,
            systemPrompt: definition.systemPrompt,
            enabledToolNames: definition.enabledToolNames
        )
    }
}
