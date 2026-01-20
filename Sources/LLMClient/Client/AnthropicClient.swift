import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - AnthropicClient

/// Anthropic Claude API クライアント
///
/// Claude モデルを使用して型安全な構造化出力を生成します。
/// モデル選択は `ClaudeModel` 型に制約されており、
/// 他のプロバイダーのモデルを誤って指定することはできません。
///
/// ## 使用例
///
/// ```swift
/// let client = AnthropicClient(apiKey: "sk-ant-...")
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
///     input: "山田太郎さんは35歳です。",
///     model: .sonnet
/// )
/// print(result.name)  // "山田太郎"
/// print(result.age)   // 35
///
/// // トークン使用量を取得
/// let resultWithUsage: GenerationResult<UserInfo> = try await client.generateWithUsage(
///     input: "山田太郎さんは35歳です。",
///     model: .sonnet
/// )
/// print("Input tokens: \(resultWithUsage.usage.inputTokens)")
/// print("Output tokens: \(resultWithUsage.usage.outputTokens)")
///
/// // マルチモーダル入力
/// let result: ImageAnalysis = try await client.generate(
///     input: LLMInput("この画像を分析してください", images: [imageContent]),
///     model: .sonnet
/// )
/// ```
///
/// ## 対応モデル
/// - `.opus` - Claude Opus 4.5（最高性能）
/// - `.sonnet` - Claude Sonnet 4.5（バランス型）
/// - `.haiku` - Claude Haiku 4.5（高速・低コスト）
/// - `.opus4_1` - Claude Opus 4.1
public struct AnthropicClient: StructuredLLMClient {
    public typealias Model = ClaudeModel

    package let provider: any LLMProvider

    // MARK: - Package Access (for extension by other modules)

    /// API キー
    package let apiKey: String

    /// エンドポイント URL
    package let endpoint: URL

    /// URLSession
    package let session: URLSession

    /// リトライ設定
    package let retryConfiguration: RetryConfiguration

    /// リトライイベントハンドラー
    package let retryEventHandler: RetryEventHandler?

    /// デフォルトエンドポイント
    package static let defaultEndpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    // MARK: - Initializers

    /// API キーを指定して初期化
    ///
    /// - Parameters:
    ///   - apiKey: Anthropic API キー
    ///   - endpoint: カスタムエンドポイント（オプション）
    ///   - session: カスタム URLSession（オプション）
    ///   - retryConfiguration: リトライ設定（デフォルト: 有効）
    ///   - retryEventHandler: リトライイベントハンドラー（オプション）
    public init(
        apiKey: String,
        endpoint: URL? = nil,
        session: URLSession = .shared,
        retryConfiguration: RetryConfiguration = .default,
        retryEventHandler: RetryEventHandler? = nil
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint ?? Self.defaultEndpoint
        self.session = session
        self.retryConfiguration = retryConfiguration
        self.retryEventHandler = retryEventHandler

        let baseProvider = AnthropicProvider(
            apiKey: apiKey,
            endpoint: endpoint,
            session: session
        )

        if retryConfiguration.isEnabled {
            self.provider = RetryableProvider(
                provider: baseProvider,
                extractorType: AnthropicRateLimitExtractor.self,
                retryPolicy: retryConfiguration.policy,
                eventHandler: retryEventHandler
            )
        } else {
            self.provider = baseProvider
        }
    }

    // MARK: - StructuredLLMClient

    public func generateWithUsage<T: StructuredProtocol>(
        input: LLMInput,
        model: ClaudeModel,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> GenerationResult<T> {
        try await generateWithUsage(
            messages: [input.toLLMMessage()],
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    public func generateWithUsage<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: ClaudeModel,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> GenerationResult<T> {
        // スキーマ情報を含むシステムプロンプトを構築
        let enhancedSystemPrompt = buildSystemPrompt(
            base: systemPrompt,
            schema: T.jsonSchema
        )

        let request = LLMRequest(
            model: .claude(model),
            messages: messages,
            systemPrompt: enhancedSystemPrompt,
            responseSchema: T.jsonSchema,
            temperature: temperature,
            maxTokens: maxTokens
        )

        let response = try await provider.send(request)
        return try decodeResponse(response, model: model.id)
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
    private func decodeResponse<T: StructuredProtocol>(_ response: LLMResponse, model: String) throws -> GenerationResult<T> {
        guard let text = response.content.first?.text else {
            throw LLMError.emptyResponse
        }

        guard let data = text.data(using: .utf8) else {
            throw LLMError.invalidEncoding
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            let result = try decoder.decode(T.self, from: data)
            return GenerationResult(
                result: result,
                usage: response.usage,
                model: model,
                rawText: text,
                stopReason: response.stopReason
            )
        } catch {
            throw LLMError.decodingFailed(error)
        }
    }
}
