import Foundation
import LLMClient

// MARK: - ConversationalAgentEvent

/// 会話型エージェントセッションのイベント
///
/// セッションの状態変化を監視するための非同期イベントストリームで使用されます。
/// UI 更新、ログ記録、分析などに活用できます。
///
/// ## 使用例
///
/// ```swift
/// let session = ConversationalAgentSession(client: client, tools: tools)
///
/// // イベントを監視するタスク
/// Task {
///     for await event in session.eventStream {
///         switch event {
///         case .userMessage(let msg):
///             updateUI(with: msg)
///         case .assistantMessage(let msg):
///             updateUI(with: msg)
///         case .interruptQueued(let message):
///             showInterruptNotification(message)
///         case .interruptProcessed(let message):
///             logInterrupt(message)
///         case .sessionStarted:
///             showLoadingIndicator()
///         case .sessionCompleted:
///             hideLoadingIndicator()
///         case .cleared:
///             clearUI()
///         case .error(let error):
///             showError(error)
///         }
///     }
/// }
/// ```
public enum ConversationalAgentEvent: Sendable {
    /// ユーザーメッセージが履歴に追加された
    ///
    /// `run()` の開始時または割り込みメッセージ処理時に発生します。
    case userMessage(LLMMessage)

    /// アシスタントメッセージが履歴に追加された
    ///
    /// LLM からの応答が会話履歴に追加された時に発生します。
    case assistantMessage(LLMMessage)

    /// 割り込みメッセージがキューに追加された
    ///
    /// `interrupt()` が呼ばれた時に即座に発生します。
    /// この時点ではまだ会話履歴には追加されていません。
    case interruptQueued(String)

    /// 割り込みメッセージが処理された
    ///
    /// キューに入っていた割り込みメッセージが
    /// 会話履歴に追加された時に発生します。
    case interruptProcessed(String)

    /// AI がユーザーに質問している
    ///
    /// `AskUserTool` が呼び出された時に発生します。
    /// セッションは `provideAnswer()` が呼ばれるまで一時停止します。
    case askingUser(String)

    /// ユーザーが質問に回答した
    ///
    /// `provideAnswer()` が呼ばれた時に発生します。
    case userAnswerProvided(String)

    /// セッションが開始された
    ///
    /// `run()` が呼ばれてエージェントループが開始された時に発生します。
    case sessionStarted

    /// セッションが完了した
    ///
    /// エージェントループが正常に完了した時に発生します。
    case sessionCompleted

    /// セッションがキャンセルされた
    ///
    /// `cancel()` が呼ばれてセッションがキャンセルされた時に発生します。
    /// 会話履歴は保持されます。
    case sessionCancelled

    /// 会話履歴がクリアされた
    ///
    /// `clear()` が呼ばれた時に発生します。
    case cleared

    /// エラーが発生した
    ///
    /// エージェントループ中にエラーが発生した時に発生します。
    case error(ConversationalAgentError)
}

// MARK: - ConversationalAgentError

/// 会話型エージェント固有のエラー
public enum ConversationalAgentError: Error, Sendable {
    /// 最大ステップ数を超過
    case maxStepsExceeded(steps: Int)

    /// ツールが見つからない
    case toolNotFound(name: String)

    /// ツール実行エラー
    case toolExecutionFailed(name: String, underlyingError: Error)

    /// 出力のデコードに失敗
    case outputDecodingFailed(Error)

    /// LLM エラー
    case llmError(LLMError)

    /// セッションが既に実行中
    case sessionAlreadyRunning

    /// 無効な状態
    case invalidState(String)
}

// MARK: - LocalizedError

extension ConversationalAgentError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .maxStepsExceeded(let steps):
            return "Agent exceeded maximum steps limit (\(steps))"
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        case .toolExecutionFailed(let name, let error):
            return "Tool execution failed (\(name)): \(error.localizedDescription)"
        case .outputDecodingFailed(let error):
            return "Failed to decode output: \(error.localizedDescription)"
        case .llmError(let error):
            return "LLM error: \(error.localizedDescription)"
        case .sessionAlreadyRunning:
            return "Session is already running. Wait for completion or cancel first."
        case .invalidState(let message):
            return "Invalid session state: \(message)"
        }
    }
}

// MARK: - CustomStringConvertible

extension ConversationalAgentEvent: CustomStringConvertible {
    public var description: String {
        switch self {
        case .userMessage(let msg):
            return "userMessage(role: \(msg.role))"
        case .assistantMessage(let msg):
            return "assistantMessage(role: \(msg.role))"
        case .interruptQueued(let message):
            return "interruptQueued(\(message.prefix(30))...)"
        case .interruptProcessed(let message):
            return "interruptProcessed(\(message.prefix(30))...)"
        case .askingUser(let question):
            return "askingUser(\(question.prefix(30))...)"
        case .userAnswerProvided(let answer):
            return "userAnswerProvided(\(answer.prefix(30))...)"
        case .sessionStarted:
            return "sessionStarted"
        case .sessionCompleted:
            return "sessionCompleted"
        case .sessionCancelled:
            return "sessionCancelled"
        case .cleared:
            return "cleared"
        case .error(let error):
            return "error(\(error.localizedDescription))"
        }
    }
}
