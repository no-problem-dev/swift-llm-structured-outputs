import Foundation
import LLMClient

// MARK: - ToolCallResponse

/// ツール呼び出し計画レスポンス
///
/// LLM がどのツールをどの引数で呼び出すべきか判断した結果を表します。
/// このレスポンスは計画のみを含み、実際のツール実行は開発者が行います。
/// テキスト応答とツール呼び出し情報の両方を含む場合があります。
///
/// ## 使用例
///
/// ```swift
/// let client = AnthropicClient(apiKey: "...")
///
/// @Tool("天気を取得する")
/// struct GetWeather {
///     @ToolArgument("場所")
///     var location: String
///
///     func call() async throws -> String {
///         // 天気API呼び出し
///         return "晴れ、25度"
///     }
/// }
///
/// let tools = ToolSet {
///     GetWeather.self
/// }
///
/// // LLM にどのツールを呼ぶべきか計画させる
/// let plan = try await client.planToolCalls(
///     prompt: "東京の天気を教えて",
///     model: .sonnet,
///     tools: tools
/// )
///
/// // 計画されたツール呼び出しを実行
/// for call in plan.toolCalls {
///     let result = try await tools.execute(toolNamed: call.name, with: call.arguments)
///     print(result)
/// }
/// ```
public struct ToolCallResponse: Sendable {
    /// ツール呼び出しのリスト
    public let toolCalls: [ToolCall]

    /// テキスト応答（ある場合）
    public let text: String?

    /// トークン使用量
    public let usage: TokenUsage

    /// 停止理由
    public let stopReason: LLMResponse.StopReason?

    /// 使用されたモデル ID
    public let model: String

    /// ツール呼び出しがあるかどうか
    public var hasToolCalls: Bool {
        !toolCalls.isEmpty
    }

    // MARK: - Initializer

    /// ToolCallResponse を初期化
    ///
    /// - Parameters:
    ///   - toolCalls: ツール呼び出しのリスト
    ///   - text: テキスト応答
    ///   - usage: トークン使用量
    ///   - stopReason: 停止理由
    ///   - model: 使用されたモデル ID
    public init(
        toolCalls: [ToolCall],
        text: String?,
        usage: TokenUsage,
        stopReason: LLMResponse.StopReason?,
        model: String
    ) {
        self.toolCalls = toolCalls
        self.text = text
        self.usage = usage
        self.stopReason = stopReason
        self.model = model
    }
}
