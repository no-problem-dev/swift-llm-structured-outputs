import Foundation

// MARK: - LLMProvider

/// LLMプロバイダー
enum LLMProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case anthropic = "Anthropic (Claude)"
    case openai = "OpenAI (GPT)"
    case gemini = "Google (Gemini)"

    var id: String { rawValue }
}

// MARK: - SessionData

/// セッションデータ
///
/// 会話セッションの永続化用データモデル
struct SessionData: Identifiable, Codable, Sendable {
    let id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var provider: LLMProvider
    var outputType: AgentOutputType
    var interactiveMode: Bool
    var steps: [ConversationStepInfo]
    var result: String?

    /// 新規セッションを作成
    init(
        title: String = "新規セッション",
        provider: LLMProvider = .anthropic,
        outputType: AgentOutputType = .research,
        interactiveMode: Bool = true
    ) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.provider = provider
        self.outputType = outputType
        self.interactiveMode = interactiveMode
        self.steps = []
        self.result = nil
    }

    /// 既存データから復元
    init(
        id: UUID,
        title: String,
        createdAt: Date,
        updatedAt: Date,
        provider: LLMProvider,
        outputType: AgentOutputType,
        interactiveMode: Bool,
        steps: [ConversationStepInfo],
        result: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.provider = provider
        self.outputType = outputType
        self.interactiveMode = interactiveMode
        self.steps = steps
        self.result = result
    }
}

// MARK: - SessionData Helpers

extension SessionData {
    /// ステップを追加して更新日時を更新
    mutating func addStep(_ step: ConversationStepInfo) {
        steps.append(step)
        updatedAt = Date()
    }

    /// 最初のユーザーメッセージからタイトルを自動生成
    mutating func updateTitleFromFirstMessage() {
        guard title == "新規セッション" else { return }

        if let firstUserMessage = steps.first(where: { $0.type == .userMessage }) {
            let content = firstUserMessage.content
            // 最大30文字に制限
            if content.count > 30 {
                title = String(content.prefix(30)) + "..."
            } else {
                title = content
            }
        }
    }

    /// セッションの表示用サマリー
    var summary: String {
        let stepCount = steps.count
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .abbreviated
        let relativeTime = formatter.localizedString(for: updatedAt, relativeTo: Date())
        return "\(stepCount)ステップ • \(relativeTime)"
    }
}
