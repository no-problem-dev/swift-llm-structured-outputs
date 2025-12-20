import Foundation
import LLMClient

/// エージェント管理のユースケース
struct AgentUseCase: Sendable {
    private let repository: AgentRepository

    init(repository: AgentRepository) {
        self.repository = repository
    }

    func fetchAll() throws -> [Agent] {
        try repository.fetchAll()
    }

    func fetch(id: UUID) throws -> Agent? {
        try repository.fetch(id: id)
    }

    func create(name: String, description: String? = nil) -> Agent {
        Agent(
            name: name,
            description: description,
            outputSchema: OutputSchema(name: "Output", description: nil, fields: [])
        )
    }

    func save(_ agent: Agent) throws {
        var updated = agent
        updated.updatedAt = Date()
        try repository.save(updated)
    }

    func delete(id: UUID) throws {
        try repository.delete(id: id)
    }

    func duplicate(_ agent: Agent) -> Agent {
        Agent(
            name: "\(agent.name) (コピー)",
            description: agent.description,
            outputSchema: agent.outputSchema,
            systemPrompt: agent.systemPrompt,
            enabledToolNames: agent.enabledToolNames
        )
    }
}
