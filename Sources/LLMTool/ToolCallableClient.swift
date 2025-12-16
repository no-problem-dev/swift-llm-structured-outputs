import Foundation
import LLMClient

// MARK: - ToolCallableClient Protocol

/// ツールコール機能を持つ LLM クライアントのプロトコル
///
/// `StructuredLLMClient` を拡張し、ツールコール機能を追加します。
/// 各プロバイダー（Anthropic, OpenAI, Gemini）はこのプロトコルに適合することで
/// ツールコール機能を利用可能にします。
///
/// ## 使用例
///
/// ```swift
/// let client = AnthropicClient(apiKey: "sk-ant-...")
///
/// @Tool("天気を取得する")
/// struct GetWeather: LLMTool {
///     @ToolArgument("場所")
///     var location: String
///
///     func call() async throws -> String {
///         return "晴れ"
///     }
/// }
///
/// let tools = ToolSet {
///     GetWeather()
/// }
///
/// let response = try await client.planToolCalls(
///     prompt: "東京の天気は？",
///     model: .sonnet,
///     tools: tools
/// )
/// ```
public protocol ToolCallableClient: StructuredLLMClient {
    /// ツール呼び出しを計画する（単一プロンプト）
    ///
    /// LLM にツールを提供し、どのツールをどの引数で呼び出すべきかを判断させます。
    /// このメソッドはツールの選択と引数の決定のみを行い、実際のツール実行は行いません。
    ///
    /// - Parameters:
    ///   - prompt: ユーザープロンプト
    ///   - model: 使用するモデル
    ///   - tools: 使用可能なツールセット
    ///   - toolChoice: ツール選択の設定（オプション）
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: ツール呼び出し計画を含むレスポンス
    func planToolCalls(
        prompt: String,
        model: Model,
        tools: ToolSet,
        toolChoice: ToolChoice?,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> ToolCallResponse

    /// ツール呼び出しを計画する（会話履歴付き）
    ///
    /// - Parameters:
    ///   - messages: メッセージ履歴
    ///   - model: 使用するモデル
    ///   - tools: 使用可能なツールセット
    ///   - toolChoice: ツール選択の設定（オプション）
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: ツール呼び出し計画を含むレスポンス
    func planToolCalls(
        messages: [LLMMessage],
        model: Model,
        tools: ToolSet,
        toolChoice: ToolChoice?,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> ToolCallResponse
}

// MARK: - Default Implementations

extension ToolCallableClient {
    /// 単一プロンプトから会話履歴形式に変換するデフォルト実装
    public func planToolCalls(
        prompt: String,
        model: Model,
        tools: ToolSet,
        toolChoice: ToolChoice? = nil,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> ToolCallResponse {
        try await planToolCalls(
            messages: [.user(prompt)],
            model: model,
            tools: tools,
            toolChoice: toolChoice,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }
}
