import Foundation

// MARK: - StructuredLLMClient Prompt Extensions

extension StructuredLLMClient {

    // MARK: - Generate with Prompt

    /// 構造化プロンプトを使用して出力を生成
    ///
    /// DSL で構築した `Prompt` を使用して、型安全な構造化出力を生成します。
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// let prompt = Prompt {
    ///     PromptComponent.role("データ分析の専門家")
    ///     PromptComponent.objective("ユーザー情報を抽出する")
    ///     PromptComponent.instruction("名前は敬称を除いて抽出")
    ///     PromptComponent.constraint("推測はしない")
    /// }
    ///
    /// let result: UserInfo = try await client.generate(
    ///     prompt: prompt,
    ///     model: .sonnet
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - prompt: 構造化プロンプト
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 指定された型にデコードされたレスポンス
    /// - Throws: `LLMError` - API エラー、デコードエラーなど
    public func generate<T: StructuredProtocol>(
        prompt: Prompt,
        model: Model,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> T {
        try await generate(
            prompt: prompt.render(),
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    /// 構造化プロンプトと構造化システムプロンプトを使用して出力を生成
    ///
    /// ユーザープロンプトとシステムプロンプトの両方に DSL を使用できます。
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// let systemPrompt = Prompt {
    ///     PromptComponent.role("データ分析の専門家")
    ///     PromptComponent.behavior("正確性を最優先する")
    /// }
    ///
    /// let userPrompt = Prompt {
    ///     PromptComponent.objective("ユーザー情報を抽出する")
    ///     PromptComponent.context("山田太郎さんは35歳です")
    /// }
    ///
    /// let result: UserInfo = try await client.generate(
    ///     prompt: userPrompt,
    ///     model: .sonnet,
    ///     systemPrompt: systemPrompt
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - prompt: 構造化ユーザープロンプト
    ///   - model: 使用するモデル
    ///   - systemPrompt: 構造化システムプロンプト
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 指定された型にデコードされたレスポンス
    /// - Throws: `LLMError` - API エラー、デコードエラーなど
    public func generate<T: StructuredProtocol>(
        prompt: Prompt,
        model: Model,
        systemPrompt: Prompt,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> T {
        try await generate(
            prompt: prompt.render(),
            model: model,
            systemPrompt: systemPrompt.render(),
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    // MARK: - Chat with Prompt

    /// 構造化プロンプトを使用して会話を開始
    ///
    /// - Parameters:
    ///   - prompt: 構造化プロンプト
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 構造化出力と会話継続情報を含む `ChatResponse`
    /// - Throws: `LLMError` - API エラー、デコードエラーなど
    public func chat<T: StructuredProtocol>(
        prompt: Prompt,
        model: Model,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> ChatResponse<T> {
        try await chat(
            prompt: prompt.render(),
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    /// 構造化プロンプトと構造化システムプロンプトを使用して会話を開始
    ///
    /// - Parameters:
    ///   - prompt: 構造化ユーザープロンプト
    ///   - model: 使用するモデル
    ///   - systemPrompt: 構造化システムプロンプト
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 構造化出力と会話継続情報を含む `ChatResponse`
    /// - Throws: `LLMError` - API エラー、デコードエラーなど
    public func chat<T: StructuredProtocol>(
        prompt: Prompt,
        model: Model,
        systemPrompt: Prompt,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> ChatResponse<T> {
        try await chat(
            prompt: prompt.render(),
            model: model,
            systemPrompt: systemPrompt.render(),
            temperature: temperature,
            maxTokens: maxTokens
        )
    }
}
