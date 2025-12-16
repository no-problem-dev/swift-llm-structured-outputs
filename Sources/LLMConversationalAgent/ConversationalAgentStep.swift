import Foundation
import LLMClient
import LLMTool

// MARK: - ConversationalAgentStep

/// 会話型エージェントループの各ステップを表す
///
/// `ConversationalAgentSession` から返される各要素として使用されます。
/// 通常の `AgentStep` に加えて、ユーザー割り込みやテキスト応答をサポートします。
///
/// ## 使用例
///
/// ```swift
/// for try await step in session.run("天気を調べて", model: .sonnet, outputType: WeatherReport.self) {
///     switch step {
///     case .userMessage(let message):
///         print("👤 ユーザー: \(message)")
///     case .thinking(let response):
///         print("🤔 思考中: \(response.text ?? "")")
///     case .toolCall(let call):
///         print("🔧 ツール呼び出し: \(call.name)")
///     case .toolResult(let result):
///         print("📄 ツール結果: \(result.output)")
///     case .interrupted(let message):
///         print("⚡ 割り込み: \(message)")
///     case .textResponse(let text):
///         print("💬 テキスト応答: \(text)")
///     case .finalResponse(let output):
///         print("✅ 最終結果: \(output)")
///     }
/// }
/// ```
public enum ConversationalAgentStep<Output: Sendable>: Sendable {
    /// ユーザーメッセージが送信された
    ///
    /// セッションの `run()` 開始時、または割り込みメッセージが処理された時に発生します。
    case userMessage(String)

    /// LLM が思考中（テキスト応答を生成）
    ///
    /// ツール呼び出しを決定する前の LLM の応答を含みます。
    case thinking(LLMResponse)

    /// LLM がツール呼び出しを要求
    ///
    /// ツールの名前、ID、引数を含みます。
    case toolCall(ToolCall)

    /// ツール実行結果
    ///
    /// ツール実行後の結果を含みます。
    case toolResult(ToolResponse)

    /// ユーザー割り込みが発生
    ///
    /// `session.interrupt()` で送信された割り込みメッセージが処理された時に発生します。
    /// 割り込みメッセージは次の LLM 呼び出し前に会話履歴に追加されます。
    case interrupted(String)

    /// テキスト応答（構造化出力なし）
    ///
    /// LLM がツール呼び出しなしでテキスト応答を返した場合に発生します。
    /// 構造化出力へのデコードが不要な場合に使用されます。
    case textResponse(String)

    /// エージェントループ完了、最終構造化出力
    ///
    /// LLM が最終的な構造化出力を生成した場合に発生します。
    case finalResponse(Output)
}

// MARK: - Convenience Properties

extension ConversationalAgentStep {
    /// ステップがユーザー関連かどうか
    public var isUserRelated: Bool {
        switch self {
        case .userMessage, .interrupted:
            return true
        default:
            return false
        }
    }

    /// ステップがツール関連かどうか
    public var isToolRelated: Bool {
        switch self {
        case .toolCall, .toolResult:
            return true
        default:
            return false
        }
    }

    /// ステップが最終応答かどうか
    public var isFinalStep: Bool {
        switch self {
        case .textResponse, .finalResponse:
            return true
        default:
            return false
        }
    }
}

// MARK: - CustomStringConvertible

extension ConversationalAgentStep: CustomStringConvertible {
    public var description: String {
        switch self {
        case .userMessage(let message):
            return "userMessage(\(message.prefix(50))...)"
        case .thinking(let response):
            let text = response.content.compactMap { block -> String? in
                if case .text(let value) = block { return value }
                return nil
            }.joined()
            return "thinking(\(text.prefix(50))...)"
        case .toolCall(let call):
            return "toolCall(\(call.name))"
        case .toolResult(let result):
            return "toolResult(\(result.name): \(result.output.prefix(50))...)"
        case .interrupted(let message):
            return "interrupted(\(message.prefix(50))...)"
        case .textResponse(let text):
            return "textResponse(\(text.prefix(50))...)"
        case .finalResponse(let output):
            return "finalResponse(\(output))"
        }
    }
}
