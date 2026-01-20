import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - OpenAIClient

/// OpenAI GPT API クライアント
///
/// GPT モデルを使用して型安全な構造化出力を生成します。
/// モデル選択は `GPTModel` 型に制約されており、
/// 他のプロバイダーのモデルを誤って指定することはできません。
///
/// ## 使用例
///
/// ```swift
/// let client = OpenAIClient(apiKey: "sk-...")
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
///     model: .gpt4o
/// )
/// print(result.name)  // "山田太郎"
/// print(result.age)   // 35
///
/// // トークン使用量を取得
/// let resultWithUsage: GenerationResult<UserInfo> = try await client.generateWithUsage(
///     input: "山田太郎さんは35歳です。",
///     model: .gpt4o
/// )
/// print("Input tokens: \(resultWithUsage.usage.inputTokens)")
/// print("Output tokens: \(resultWithUsage.usage.outputTokens)")
///
/// // マルチモーダル入力
/// let result: ImageAnalysis = try await client.generate(
///     input: LLMInput("この画像を分析してください", images: [imageContent]),
///     model: .gpt4o
/// )
/// ```
///
/// ## 対応モデル
/// - `.gpt4o` - GPT-4o（最新）
/// - `.gpt4oMini` - GPT-4o mini（軽量版）
/// - `.gpt4Turbo` - GPT-4 Turbo
/// - `.gpt4` - GPT-4
/// - `.o1` - o1（推論特化）
/// - `.o3Mini` - o3 mini
public struct OpenAIClient: StructuredLLMClient {
    public typealias Model = GPTModel

    package let provider: any LLMProvider

    // MARK: - Package Access (for extension by other modules)

    /// API キー（パッケージ内の他モジュールからアクセス可能）
    package let apiKey: String

    /// エンドポイント（パッケージ内の他モジュールからアクセス可能）
    package let endpoint: URL

    /// URLSession（パッケージ内の他モジュールからアクセス可能）
    package let session: URLSession

    /// 組織 ID（パッケージ内の他モジュールからアクセス可能）
    package let organization: String?

    /// リトライ設定（パッケージ内の他モジュールからアクセス可能）
    package let retryConfiguration: RetryConfiguration

    /// リトライイベントハンドラー（パッケージ内の他モジュールからアクセス可能）
    package let retryEventHandler: RetryEventHandler?

    /// デフォルトエンドポイント
    package static let defaultEndpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    // MARK: - Initializers

    /// API キーを指定して初期化
    ///
    /// - Parameters:
    ///   - apiKey: OpenAI API キー
    ///   - organization: 組織 ID（オプション）
    ///   - endpoint: カスタムエンドポイント（オプション）
    ///   - session: カスタム URLSession（オプション）
    ///   - retryConfiguration: リトライ設定（デフォルト: 有効）
    ///   - retryEventHandler: リトライイベントハンドラー（オプション）
    public init(
        apiKey: String,
        organization: String? = nil,
        endpoint: URL? = nil,
        session: URLSession = .shared,
        retryConfiguration: RetryConfiguration = .default,
        retryEventHandler: RetryEventHandler? = nil
    ) {
        self.apiKey = apiKey
        self.organization = organization
        self.endpoint = endpoint ?? Self.defaultEndpoint
        self.session = session
        self.retryConfiguration = retryConfiguration
        self.retryEventHandler = retryEventHandler

        let baseProvider = OpenAIProvider(
            apiKey: apiKey,
            organization: organization,
            endpoint: endpoint,
            session: session
        )

        if retryConfiguration.isEnabled {
            self.provider = RetryableProvider(
                provider: baseProvider,
                extractorType: OpenAIRateLimitExtractor.self,
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
        model: GPTModel,
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
        model: GPTModel,
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
            model: .gpt(model),
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
