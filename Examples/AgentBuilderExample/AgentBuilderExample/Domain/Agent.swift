import Foundation
import LLMClient

/// エージェント設定
struct Agent: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var name: String
    var description: String?
    var outputSchema: OutputSchema
    var systemPrompt: Prompt
    var enabledToolNames: [String]
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        outputSchema: OutputSchema,
        systemPrompt: Prompt = Prompt(components: []),
        enabledToolNames: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.outputSchema = outputSchema
        self.systemPrompt = systemPrompt
        self.enabledToolNames = enabledToolNames
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var effectiveSystemPrompt: Prompt {
        systemPrompt.isEmpty ? generatedPrompt : systemPrompt
    }

    var generatedPrompt: Prompt {
        let fieldInstructions = outputSchema.fields.map { field -> PromptComponent in
            var desc = "\(field.name): \(field.type.displayName)"
            if !field.isRequired { desc += " (optional)" }
            if let fieldDesc = field.description { desc += " - \(fieldDesc)" }
            return .instruction(desc)
        }

        return Prompt {
            PromptComponent.role("構造化データを生成するアシスタント")
            PromptComponent.objective("ユーザーの要求に基づいて\(outputSchema.name)型のデータを生成する")
            if let desc = outputSchema.description {
                PromptComponent.context(desc)
            }
            fieldInstructions
            PromptComponent.important("ユーザーの要求を理解し、適切な値で各フィールドを埋めてください。")
        }
    }

    var fieldCount: Int { outputSchema.fields.count }
    var toolCount: Int { enabledToolNames.count }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Agent, rhs: Agent) -> Bool { lhs.id == rhs.id }
}

extension Agent {
    static let sample = Agent(
        name: "ユーザー情報抽出",
        description: "テキストからユーザー情報を抽出するエージェント",
        outputSchema: OutputSchema(
            name: "UserInfo",
            description: "ユーザーの基本情報",
            fields: [
                Field(name: "name", type: .string, description: "ユーザー名"),
                Field(name: "age", type: .integer, description: "年齢", isRequired: false),
                Field(name: "email", type: .string, description: "メールアドレス", isRequired: false)
            ]
        ),
        systemPrompt: Prompt {
            PromptComponent.role("データ分析の専門家")
            PromptComponent.objective("テキストからユーザー情報を抽出する")
            PromptComponent.constraint("推測はしない")
        }
    )
}
