import Foundation
import LLMClient
import LLMTool

/// エージェント定義
///
/// エージェントの振る舞いを定義する設定。
/// 出力型、システムプロンプト、使用可能なツールを含む。
struct AgentDefinition: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var name: String
    var description: String?

    /// 出力型の定義
    var outputType: BuiltType

    /// システムプロンプト（Prompt型を直接使用）
    var systemPrompt: Prompt

    /// 有効なツール名（ToolSetは実行ロジックを含むためシリアライズ不可）
    var enabledToolNames: [String]

    /// 作成日時
    let createdAt: Date

    /// 更新日時
    var updatedAt: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        outputType: BuiltType,
        systemPrompt: Prompt = Prompt(components: []),
        enabledToolNames: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.outputType = outputType
        self.systemPrompt = systemPrompt
        self.enabledToolNames = enabledToolNames
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Computed Properties

    /// 有効なシステムプロンプト（カスタムまたはデフォルト）
    var effectiveSystemPrompt: Prompt {
        systemPrompt.isEmpty ? generatedPrompt : systemPrompt
    }

    /// デフォルトのシステムプロンプトを生成
    var generatedPrompt: Prompt {
        // フィールドの説明を事前に生成
        let fieldInstructions = outputType.fields.map { field -> PromptComponent in
            var desc = "\(field.name): \(field.fieldType.displayName)"
            if !field.isRequired {
                desc += " (optional)"
            }
            if let fieldDesc = field.description {
                desc += " - \(fieldDesc)"
            }
            return .instruction(desc)
        }

        return Prompt {
            PromptComponent.role("構造化データを生成するアシスタント")
            PromptComponent.objective("ユーザーの要求に基づいて\(outputType.name)型のデータを生成する")

            if let desc = outputType.description {
                PromptComponent.context(desc)
            }

            fieldInstructions

            PromptComponent.important("ユーザーの要求を理解し、適切な値で各フィールドを埋めてください。")
        }
    }

    /// フィールド数のサマリー
    var fieldsSummary: String {
        let count = outputType.fields.count
        return "\(count) field\(count == 1 ? "" : "s")"
    }

    /// ツール数のサマリー
    var toolsSummary: String {
        let count = enabledToolNames.count
        return "\(count) tool\(count == 1 ? "" : "s")"
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AgentDefinition, rhs: AgentDefinition) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sample Data

extension AgentDefinition {
    static let sample = AgentDefinition(
        name: "ユーザー情報抽出",
        description: "テキストからユーザー情報を抽出するエージェント",
        outputType: BuiltType(
            name: "UserInfo",
            description: "ユーザーの基本情報",
            fields: [
                BuiltField(name: "name", fieldType: .string, description: "ユーザー名"),
                BuiltField(name: "age", fieldType: .integer, description: "年齢", isRequired: false),
                BuiltField(name: "email", fieldType: .string, description: "メールアドレス", isRequired: false)
            ]
        ),
        systemPrompt: Prompt {
            PromptComponent.role("データ分析の専門家")
            PromptComponent.objective("テキストからユーザー情報を抽出する")
            PromptComponent.constraint("推測はしない")
        }
    )
}
