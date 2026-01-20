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
///     input: "山田太郎さんは35歳です。",
///     model: .sonnet  // ClaudeModel のみ許可
/// )
///
/// // マルチモーダル入力
/// let result: ImageAnalysis = try await anthropic.generate(
///     input: LLMInput("この画像を分析してください", images: [imageContent]),
///     model: .sonnet
/// )
///
/// // トークン使用量を取得
/// let resultWithUsage: GenerationResult<UserInfo> = try await anthropic.generateWithUsage(
///     input: "山田太郎さんは35歳です。",
///     model: .sonnet
/// )
/// print("Input tokens: \(resultWithUsage.usage.inputTokens)")
/// print("Output tokens: \(resultWithUsage.usage.outputTokens)")
/// ```
public protocol StructuredLLMClient<Model>: Sendable {
    /// このクライアントで使用可能なモデル型
    associatedtype Model: Sendable

    /// 構造化出力を生成（メタデータ付き）
    ///
    /// 指定された型に準拠した構造化データを LLM から取得します。
    /// トークン使用量などのメタデータも含まれます。
    ///
    /// - Parameters:
    ///   - input: LLM 入力（テキスト、画像、音声、動画を含む）
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（0.0-1.0、オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 構造化出力とメタデータを含む GenerationResult
    /// - Throws: `LLMError` - API エラー、デコードエラーなど
    func generateWithUsage<T: StructuredProtocol>(
        input: LLMInput,
        model: Model,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> GenerationResult<T>

    /// 会話履歴を含む構造化出力を生成（メタデータ付き）
    ///
    /// - Parameters:
    ///   - messages: メッセージ履歴
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 構造化出力とメタデータを含む GenerationResult
    func generateWithUsage<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> GenerationResult<T>
}

// MARK: - Default Implementations

extension StructuredLLMClient {
    // MARK: - generateWithUsage with default arguments

    /// 構造化出力を生成（メタデータ付き、デフォルト引数付き）
    ///
    /// - Parameters:
    ///   - input: LLM 入力
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト（オプション、デフォルト: nil）
    ///   - temperature: 温度パラメータ（オプション、デフォルト: nil）
    ///   - maxTokens: 最大トークン数（オプション、デフォルト: nil）
    /// - Returns: 構造化出力とメタデータを含む GenerationResult
    public func generateWithUsage<T: StructuredProtocol>(
        input: LLMInput,
        model: Model,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> GenerationResult<T> {
        try await generateWithUsage(
            input: input,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    /// 会話履歴を含む構造化出力を生成（メタデータ付き、デフォルト引数付き）
    public func generateWithUsage<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> GenerationResult<T> {
        try await generateWithUsage(
            messages: messages,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    /// 構造化システムプロンプトを使用して出力を生成（メタデータ付き）
    ///
    /// - Parameters:
    ///   - input: LLM 入力
    ///   - model: 使用するモデル
    ///   - systemPrompt: 構造化システムプロンプト
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 構造化出力とメタデータを含む GenerationResult
    public func generateWithUsage<T: StructuredProtocol>(
        input: LLMInput,
        model: Model,
        systemPrompt: Prompt,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> GenerationResult<T> {
        try await generateWithUsage(
            input: input,
            model: model,
            systemPrompt: systemPrompt.render(),
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    // MARK: - generate (result only, delegates to generateWithUsage)

    /// 構造化出力を生成
    ///
    /// 指定された型に準拠した構造化データを LLM から取得します。
    /// 戻り値の型から自動的にスキーマが推論されます。
    ///
    /// - Parameters:
    ///   - input: LLM 入力（テキスト、画像、音声、動画を含む）
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（0.0-1.0、オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 指定された型にデコードされたレスポンス
    /// - Throws: `LLMError` - API エラー、デコードエラーなど
    public func generate<T: StructuredProtocol>(
        input: LLMInput,
        model: Model,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> T {
        let result: GenerationResult<T> = try await generateWithUsage(
            input: input,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
        return result.result
    }

    /// 会話履歴を含む構造化出力を生成
    ///
    /// - Parameters:
    ///   - messages: メッセージ履歴
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 指定された型にデコードされたレスポンス
    public func generate<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> T {
        let result: GenerationResult<T> = try await generateWithUsage(
            messages: messages,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
        return result.result
    }

    /// 構造化システムプロンプトを使用して出力を生成
    ///
    /// ユーザー入力とシステムプロンプトの両方に Prompt DSL を使用できます。
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// let systemPrompt = Prompt {
    ///     PromptComponent.role("データ分析の専門家")
    ///     PromptComponent.behavior("正確性を最優先する")
    /// }
    ///
    /// let result: UserInfo = try await client.generate(
    ///     input: "山田太郎さんは35歳です",
    ///     model: .sonnet,
    ///     systemPrompt: systemPrompt
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - input: LLM 入力
    ///   - model: 使用するモデル
    ///   - systemPrompt: 構造化システムプロンプト
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 指定された型にデコードされたレスポンス
    /// - Throws: `LLMError` - API エラー、デコードエラーなど
    public func generate<T: StructuredProtocol>(
        input: LLMInput,
        model: Model,
        systemPrompt: Prompt,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> T {
        try await generate(
            input: input,
            model: model,
            systemPrompt: systemPrompt.render(),
            temperature: temperature,
            maxTokens: maxTokens
        )
    }
}
