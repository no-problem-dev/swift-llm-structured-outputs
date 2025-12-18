import Foundation
import LLMClient

// MARK: - ConversationalAgentError

/// 会話型エージェントセッション固有のエラー
public enum ConversationalAgentError: Error, Sendable {
    /// セッションが既に実行中
    case sessionAlreadyRunning

    /// 最大ステップ数を超過
    case maxStepsExceeded(steps: Int)

    /// ツールが見つからない
    case toolNotFound(name: String)

    /// ツール実行エラー
    case toolExecutionFailed(name: String, underlyingError: String)

    /// 無効な状態
    case invalidState(String)

    /// 出力のデコードに失敗
    case outputDecodingFailed(Error)

    /// LLMエラーをラップ
    case llmError(LLMError)
}

// MARK: - LocalizedError

extension ConversationalAgentError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .sessionAlreadyRunning:
            return "Session is already running"
        case .maxStepsExceeded(let steps):
            return "Agent exceeded maximum steps limit (\(steps))"
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        case .toolExecutionFailed(let name, let error):
            return "Tool execution failed (\(name)): \(error)"
        case .invalidState(let message):
            return "Invalid session state: \(message)"
        case .outputDecodingFailed(let error):
            return "Failed to decode output: \(error.localizedDescription)"
        case .llmError(let error):
            return "LLM error: \(error.localizedDescription)"
        }
    }
}
