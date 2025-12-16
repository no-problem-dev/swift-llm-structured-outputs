import Foundation
import LLMClient
import LLMTool

// MARK: - AskUserTool

/// ユーザーに質問して追加情報を得るためのツール
///
/// このツールが有効な場合、AI はユーザーに質問できるようになります。
/// AI がこのツールを呼び出すと、セッションは一時停止し、
/// `reply(_:)` が呼ばれるまでユーザーの回答を待ちます。
///
/// ## 推奨: interactiveMode を使用
///
/// ```swift
/// // interactiveMode: true で AskUserTool が自動追加される
/// let session = ConversationalAgentSession(
///     client: client,
///     systemPrompt: Prompt {
///         "あなたはリサーチアシスタントです。"
///         "情報が不足している場合は、ask_user ツールでユーザーに質問してください。"
///     },
///     tools: ToolSet {
///         WebSearchTool()
///     },
///     interactiveMode: true  // ← AskUserTool が自動追加される
/// )
/// ```
///
/// ## ストリームの処理例
///
/// ```swift
/// for try await step in session.run("調査して", model: .sonnet) {
///     switch step {
///     case .awaitingUserInput(let question):
///         // UI でユーザー入力を待つ
///         let answer = await showInputDialog(question)
///         await session.reply(answer)
///     case .finalResponse(let report):
///         showReport(report)
///     default:
///         break
///     }
/// }
/// ```
///
/// ## 自動モード vs 対話モード
///
/// - **自動モード** (`interactiveMode: false`): AI は質問せずに最後まで実行
/// - **対話モード** (`interactiveMode: true`): AI は必要に応じて質問できる
@Tool("Ask the user a question to gather additional information. Use this tool when you need clarification, lack sufficient information to proceed, or want to confirm the user's intent before taking action.", name: "ask_user")
public struct AskUserTool {
    @ToolArgument("The question to ask the user. Be specific and clear about what information you need.")
    public var question: String

    /// ツール実行
    ///
    /// - Note: このメソッドは `ConversationalAgentSession` によって直接呼び出されません。
    ///         Session は `AskUserTool` を検出すると、`provideAnswer()` を通じて
    ///         ユーザーの回答を取得し、その回答をツール結果として使用します。
    public func call() async throws -> String {
        // このメソッドは Session 側で特別処理されるため、
        // 通常は呼び出されません。
        // 万が一呼び出された場合のフォールバック
        return "Waiting for user response..."
    }
}
