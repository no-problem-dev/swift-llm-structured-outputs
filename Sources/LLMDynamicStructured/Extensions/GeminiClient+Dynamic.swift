import Foundation
import LLMClient

// MARK: - GeminiClient + DynamicStructured

extension GeminiClient {
    /// DynamicStructured を使用して構造化出力を生成
    ///
    /// ランタイムで定義された構造に基づいて、LLM から構造化データを取得します。
    ///
    /// - Parameters:
    ///   - prompt: ユーザープロンプト
    ///   - model: 使用する Gemini モデル
    ///   - output: 出力の構造定義
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 構造化された結果
    /// - Throws: `LLMError` または `DynamicStructuredResultError`
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// let userInfo = DynamicStructured("UserInfo") {
    ///     JSONSchema.string(description: "ユーザー名")
    ///         .named("name")
    ///     JSONSchema.integer(description: "年齢", minimum: 0)
    ///         .named("age")
    ///         .optional()
    /// }
    ///
    /// let result = try await client.generate(
    ///     prompt: "田中太郎さん（35歳）の情報を抽出",
    ///     model: .flash25,
    ///     output: userInfo
    /// )
    ///
    /// print(result.string("name"))  // Optional("田中太郎")
    /// print(result.int("age"))      // Optional(35)
    /// ```
    public func generate(
        prompt: String,
        model: GeminiModel,
        output: DynamicStructured,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> DynamicStructuredResult {
        try await generate(
            messages: [.user(prompt)],
            model: model,
            output: output,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    /// 会話履歴を含む DynamicStructured による構造化出力生成
    ///
    /// - Parameters:
    ///   - messages: メッセージ履歴
    ///   - model: 使用する Gemini モデル
    ///   - output: 出力の構造定義
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 構造化された結果
    public func generate(
        messages: [LLMMessage],
        model: GeminiModel,
        output: DynamicStructured,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> DynamicStructuredResult {
        let schema = output.toJSONSchema()

        // スキーマ情報を含むシステムプロンプトを構築
        let enhancedSystemPrompt = buildSystemPrompt(
            base: systemPrompt,
            schema: schema
        )

        let request = LLMRequest(
            model: .gemini(model),
            messages: messages,
            systemPrompt: enhancedSystemPrompt,
            responseSchema: schema,
            temperature: temperature,
            maxTokens: maxTokens
        )

        let response = try await provider.send(request)
        return try decodeResponse(response)
    }

    // MARK: - Private Helpers

    /// システムプロンプトにスキーマ情報を付加
    private func buildSystemPrompt(base: String?, schema: JSONSchema) -> String {
        var parts: [String] = []

        if let base = base {
            parts.append(base)
        }

        // スキーマの説明を追加
        if let description = schema.description {
            parts.append("出力形式: \(description)")
        }

        return parts.isEmpty ? "" : parts.joined(separator: "\n\n")
    }

    /// レスポンスをデコード
    private func decodeResponse(_ response: LLMResponse) throws -> DynamicStructuredResult {
        guard let text = response.content.first?.text else {
            throw LLMError.emptyResponse
        }

        return try DynamicStructuredResult(from: text)
    }
}
