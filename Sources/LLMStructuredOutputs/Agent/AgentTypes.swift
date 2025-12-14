import Foundation

// MARK: - AgentStep

/// エージェントループの各ステップを表す
///
/// AsyncSequence で返される各要素として使用されます。
///
/// ## 使用例
///
/// ```swift
/// for try await step in client.runAgent(prompt: "天気を調べて", tools: tools) {
///     switch step {
///     case .thinking(let response):
///         print("思考中: \(response.textContent ?? "")")
///     case .toolCall(let call):
///         print("ツール呼び出し: \(call.name)")
///     case .toolResult(let result):
///         print("ツール結果: \(result.content)")
///     case .finalResponse(let output):
///         print("最終結果: \(output)")
///     }
/// }
/// ```
public enum AgentStep<Output: Sendable>: Sendable {
    /// LLM が思考中（テキスト応答を生成）
    case thinking(LLMResponse)

    /// LLM がツール呼び出しを要求
    case toolCall(ToolCallInfo)

    /// ツール実行結果
    case toolResult(ToolResultInfo)

    /// エージェントループ完了、最終出力
    case finalResponse(Output)
}

// MARK: - ToolCallInfo

/// ツール呼び出し情報
public struct ToolCallInfo: Sendable {
    /// ツール呼び出しID
    public let id: String

    /// ツール名
    public let name: String

    /// ツール引数（JSON データ）
    public let input: Data

    /// ツール引数を指定の型にデコード
    public func decodeInput<T: Decodable>(as type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: input)
    }

    public init(id: String, name: String, input: Data) {
        self.id = id
        self.name = name
        self.input = input
    }
}

// MARK: - ToolResultInfo

/// ツール実行結果情報
public struct ToolResultInfo: Sendable {
    /// 対応するツール呼び出しID
    public let toolCallId: String

    /// ツール名
    public let name: String

    /// 実行結果
    public let content: String

    /// エラーかどうか
    public let isError: Bool

    public init(toolCallId: String, name: String, content: String, isError: Bool = false) {
        self.toolCallId = toolCallId
        self.name = name
        self.content = content
        self.isError = isError
    }
}

// MARK: - AgentConfiguration

/// エージェントループの設定
public struct AgentConfiguration: Sendable {
    /// 最大ステップ数（無限ループ防止）
    public let maxSteps: Int

    /// ツール実行を自動で行うか
    public let autoExecuteTools: Bool

    /// デフォルト設定
    public static let `default` = AgentConfiguration(
        maxSteps: 10,
        autoExecuteTools: true
    )

    public init(maxSteps: Int = 10, autoExecuteTools: Bool = true) {
        self.maxSteps = maxSteps
        self.autoExecuteTools = autoExecuteTools
    }
}

// MARK: - AgentError

/// エージェントループ固有のエラー
public enum AgentError: Error, Sendable {
    /// 最大ステップ数を超過
    case maxStepsExceeded(steps: Int)

    /// ツールが見つからない
    case toolNotFound(name: String)

    /// ツール実行エラー
    case toolExecutionFailed(name: String, underlyingError: Error)

    /// 無効な状態
    case invalidState(String)

    /// 出力のデコードに失敗
    case outputDecodingFailed(Error)

    /// LLMエラーをラップ
    case llmError(LLMError)
}

extension AgentError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .maxStepsExceeded(let steps):
            return "Agent exceeded maximum steps limit (\(steps))"
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        case .toolExecutionFailed(let name, let error):
            return "Tool execution failed (\(name)): \(error.localizedDescription)"
        case .invalidState(let message):
            return "Invalid agent state: \(message)"
        case .outputDecodingFailed(let error):
            return "Failed to decode output: \(error.localizedDescription)"
        case .llmError(let error):
            return "LLM error: \(error.localizedDescription)"
        }
    }
}

// MARK: - StopReason Extension

extension LLMResponse.StopReason {
    /// ツール呼び出しによる停止かどうか
    public var isToolUse: Bool {
        self == .toolUse
    }
}
