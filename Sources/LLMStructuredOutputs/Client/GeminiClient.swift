import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - GeminiClient

/// Google Gemini API クライアント
///
/// Gemini モデルを使用して型安全な構造化出力を生成します。
/// モデル選択は `GeminiModel` 型に制約されており、
/// 他のプロバイダーのモデルを誤って指定することはできません。
///
/// ## 使用例
///
/// ```swift
/// let client = GeminiClient(apiKey: "...")
///
/// @Structured("ユーザー情報")
/// struct UserInfo {
///     @StructuredField("ユーザー名")
///     var name: String
///     @StructuredField("年齢", .minimum(0))
///     var age: Int
/// }
///
/// // 戻り値の型から自動的にスキーマが推論される
/// let result: UserInfo = try await client.generate(
///     prompt: "山田太郎さんは35歳です。",
///     model: .flash25
/// )
/// print(result.name)  // "山田太郎"
/// print(result.age)   // 35
/// ```
///
/// ## 対応モデル
/// - `.pro25` - Gemini 2.5 Pro
/// - `.flash25` - Gemini 2.5 Flash
/// - `.flash20` - Gemini 2.0 Flash
/// - `.pro15` - Gemini 1.5 Pro
/// - `.flash15` - Gemini 1.5 Flash
public struct GeminiClient: StructuredLLMClient {
    public typealias Model = GeminiModel

    private let provider: GeminiProvider

    // MARK: - Initializers

    /// API キーを指定して初期化
    ///
    /// - Parameters:
    ///   - apiKey: Google AI API キー
    ///   - baseURL: カスタムベース URL（オプション）
    ///   - session: カスタム URLSession（オプション）
    public init(
        apiKey: String,
        baseURL: String? = nil,
        session: URLSession = .shared
    ) {
        self.provider = GeminiProvider(
            apiKey: apiKey,
            baseURL: baseURL,
            session: session
        )
    }

    // MARK: - StructuredLLMClient

    public func generate<T: StructuredProtocol>(
        prompt: String,
        model: GeminiModel,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> T {
        try await generate(
            messages: [.user(prompt)],
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    public func generate<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: GeminiModel,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> T {
        // スキーマ情報を含むシステムプロンプトを構築
        let enhancedSystemPrompt = buildSystemPrompt(
            base: systemPrompt,
            schema: T.jsonSchema
        )

        let request = LLMRequest(
            model: .gemini(model),
            messages: messages,
            systemPrompt: enhancedSystemPrompt,
            responseSchema: T.jsonSchema,
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
    private func decodeResponse<T: StructuredProtocol>(_ response: LLMResponse) throws -> T {
        guard let text = response.content.first?.text else {
            throw LLMError.emptyResponse
        }

        guard let data = text.data(using: .utf8) else {
            throw LLMError.invalidEncoding
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw LLMError.decodingFailed(error)
        }
    }

    // MARK: - Tool Methods

    /// ツール呼び出しを計画する
    ///
    /// LLM にツールを提供し、どのツールをどの引数で呼び出すべきかを判断させます。
    /// このメソッドはツールの選択と引数の決定のみを行い、実際のツール実行は行いません。
    /// 返された `ToolCallResponse` の `toolCalls` を使用して、
    /// 開発者側でツールを実行する必要があります。
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// @Tool("天気を取得する")
    /// struct GetWeather {
    ///     @ToolArgument("場所")
    ///     var location: String
    ///
    ///     func call() async throws -> String {
    ///         return "晴れ"
    ///     }
    /// }
    ///
    /// let tools = ToolSet {
    ///     GetWeather.self
    /// }
    ///
    /// // LLM がどのツールを呼ぶべきか計画する
    /// let plan = try await client.planToolCalls(
    ///     prompt: "東京の天気は？",
    ///     model: .flash25,
    ///     tools: tools
    /// )
    ///
    /// // 計画されたツール呼び出しを実行
    /// for call in plan.toolCalls {
    ///     let result = try await tools.execute(toolNamed: call.name, with: call.arguments)
    ///     print(result)
    /// }
    /// ```
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
    public func planToolCalls(
        prompt: String,
        model: GeminiModel,
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

    /// 会話履歴を含むツール呼び出し計画リクエスト
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
    public func planToolCalls(
        messages: [LLMMessage],
        model: GeminiModel,
        tools: ToolSet,
        toolChoice: ToolChoice? = nil,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> ToolCallResponse {
        let request = LLMRequest(
            model: .gemini(model),
            messages: messages,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens,
            tools: tools,
            toolChoice: toolChoice
        )

        let response = try await provider.send(request)
        return parseToolCallResponse(response)
    }

    /// LLMResponse からツール呼び出しレスポンスを生成
    private func parseToolCallResponse(_ response: LLMResponse) -> ToolCallResponse {
        var toolCalls: [ToolCall] = []
        var textContent: String?

        for block in response.content {
            switch block {
            case .text(let text):
                textContent = text
            case .toolUse(let id, let name, let input):
                toolCalls.append(ToolCall(id: id, name: name, arguments: input))
            }
        }

        return ToolCallResponse(
            toolCalls: toolCalls,
            text: textContent,
            usage: response.usage,
            stopReason: response.stopReason,
            model: response.model
        )
    }

    // MARK: - Chat Methods

    public func chat<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: GeminiModel,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> ChatResponse<T> {
        // スキーマ情報を含むシステムプロンプトを構築
        let enhancedSystemPrompt = buildSystemPrompt(
            base: systemPrompt,
            schema: T.jsonSchema
        )

        let request = LLMRequest(
            model: .gemini(model),
            messages: messages,
            systemPrompt: enhancedSystemPrompt,
            responseSchema: T.jsonSchema,
            temperature: temperature,
            maxTokens: maxTokens
        )

        let response = try await provider.send(request)

        // 生テキストを取得
        guard let rawText = response.content.first?.text else {
            throw LLMError.emptyResponse
        }

        // デコード
        guard let data = rawText.data(using: .utf8) else {
            throw LLMError.invalidEncoding
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let result: T
        do {
            result = try decoder.decode(T.self, from: data)
        } catch {
            throw LLMError.decodingFailed(error)
        }

        return ChatResponse(
            result: result,
            assistantMessage: .assistant(rawText),
            usage: response.usage,
            stopReason: response.stopReason,
            model: response.model,
            rawText: rawText
        )
    }
}
