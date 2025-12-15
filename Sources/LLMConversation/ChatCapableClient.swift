import Foundation
import LLMClient

// MARK: - ChatCapableClient Protocol

/// 会話継続機能を持つ LLM クライアントのプロトコル
///
/// `StructuredLLMClient` を拡張し、会話継続に必要なメタ情報を
/// 含むレスポンスを返す機能を追加します。
/// 各プロバイダー（Anthropic, OpenAI, Gemini）はこのプロトコルに適合することで
/// 会話継続機能を利用可能にします。
///
/// ## 基本的な LLM 動作との違い
///
/// - `generate`: 単発のデータ取得（結果のみを返す）
/// - `chat`: 会話の継続性を提供（結果 + 履歴に追加するメッセージを返す）
///
/// ## 使用例
///
/// ```swift
/// let client = AnthropicClient(apiKey: "...")
/// var history: [LLMMessage] = []
///
/// // 最初の質問
/// history.append(.user("日本の首都は？"))
/// let response1: ChatResponse<CityInfo> = try await client.chat(
///     messages: history,
///     model: .sonnet
/// )
/// print(response1.result.name)  // "東京"
///
/// // アシスタント応答を履歴に追加
/// history.append(response1.assistantMessage)
///
/// // 続けて質問
/// history.append(.user("その都市の人口は？"))
/// let response2: ChatResponse<PopulationInfo> = try await client.chat(
///     messages: history,
///     model: .sonnet
/// )
/// ```
public protocol ChatCapableClient: StructuredLLMClient {
    /// 会話を継続し、構造化出力と会話履歴情報を取得
    ///
    /// このメソッドは `generate` と異なり、構造化出力に加えて
    /// 会話を継続するために必要なメタ情報を `ChatResponse` として返します。
    ///
    /// - Parameters:
    ///   - messages: メッセージ履歴
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 構造化出力と会話継続情報を含む `ChatResponse`
    func chat<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> ChatResponse<T>
}

// MARK: - Default Implementations

extension ChatCapableClient {
    /// 会話を継続（デフォルト引数付き）
    public func chat<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> ChatResponse<T> {
        try await chat(
            messages: messages,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    /// 単一プロンプトから会話を開始
    ///
    /// 会話履歴なしで新しい会話を開始するための便利メソッド。
    ///
    /// - Parameters:
    ///   - prompt: ユーザープロンプト
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 構造化出力と会話継続情報を含む `ChatResponse`
    public func chat<T: StructuredProtocol>(
        prompt: String,
        model: Model,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> ChatResponse<T> {
        try await chat(
            messages: [.user(prompt)],
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }
}
