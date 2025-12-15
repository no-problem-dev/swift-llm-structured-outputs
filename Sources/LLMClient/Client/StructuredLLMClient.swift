import Foundation

// MARK: - StructuredLLMClient Protocol

/// 構造化出力をサポートする LLM クライアントの共通インターフェース
///
/// このプロトコルは、モデル型をジェネリクスで制約することで、
/// 各プロバイダーに対して適切なモデルのみを使用できることを
/// コンパイル時に保証します。
///
/// ## 使用例
///
/// ```swift
/// // Anthropic クライアント
/// let anthropic = AnthropicClient(apiKey: "sk-ant-...")
/// let result: UserInfo = try await anthropic.generate(
///     prompt: "山田太郎さんは35歳です。",
///     model: .sonnet  // ClaudeModel のみ許可
/// )
///
/// // OpenAI クライアント
/// let openai = OpenAIClient(apiKey: "sk-...")
/// let result: UserInfo = try await openai.generate(
///     prompt: "山田太郎さんは35歳です。",
///     model: .gpt4o  // GPTModel のみ許可
/// )
/// ```
public protocol StructuredLLMClient<Model>: Sendable {
    /// このクライアントで使用可能なモデル型
    associatedtype Model: Sendable

    /// 構造化出力を生成
    ///
    /// 指定された型に準拠した構造化データを LLM から取得します。
    /// 戻り値の型から自動的にスキーマが推論されます。
    ///
    /// - Parameters:
    ///   - prompt: ユーザープロンプト
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（0.0-1.0、オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 指定された型にデコードされたレスポンス
    /// - Throws: `LLMError` - API エラー、デコードエラーなど
    func generate<T: StructuredProtocol>(
        prompt: String,
        model: Model,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> T

    /// 会話履歴を含む構造化出力を生成
    ///
    /// - Parameters:
    ///   - messages: メッセージ履歴
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 指定された型にデコードされたレスポンス
    func generate<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> T
}

// MARK: - Default Implementations

extension StructuredLLMClient {
    /// 構造化出力を生成（デフォルト引数付き）
    ///
    /// - Parameters:
    ///   - prompt: ユーザープロンプト
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト（オプション、デフォルト: nil）
    ///   - temperature: 温度パラメータ（オプション、デフォルト: nil）
    ///   - maxTokens: 最大トークン数（オプション、デフォルト: nil）
    /// - Returns: 指定された型にデコードされたレスポンス
    public func generate<T: StructuredProtocol>(
        prompt: String,
        model: Model,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> T {
        try await generate(
            prompt: prompt,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    /// 会話履歴を含む構造化出力を生成（デフォルト引数付き）
    public func generate<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> T {
        try await generate(
            messages: messages,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }
}
