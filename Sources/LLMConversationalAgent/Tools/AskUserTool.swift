import Foundation
import LLMClient
import LLMTool

// MARK: - AskUserTool

/// インタラクティブモード用の内部ツール
///
/// `interactiveMode: true` で自動追加される内部実装です。
/// セッションはこのツールの呼び出しを検出し、ユーザーの回答を待機します。
@Tool("Ask the user a question to gather additional information. Use this tool when you need clarification, lack sufficient information to proceed, or want to confirm the user's intent before taking action.", name: "ask_user")
struct AskUserTool {
    @ToolArgument("The question to ask the user. Be specific and clear about what information you need.")
    var question: String

    func call() async throws -> String {
        // セッション側で特別処理されるため、通常は呼び出されない
        return "Waiting for user response..."
    }
}
