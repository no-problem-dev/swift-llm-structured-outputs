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

    package let provider: any LLMProvider

    // MARK: - Package Access (for extension by other modules)

    /// API キー（パッケージ内の他モジュールからアクセス可能）
    package let apiKey: String

    /// ベース URL（パッケージ内の他モジュールからアクセス可能）
    package let baseURL: String

    /// URLSession（パッケージ内の他モジュールからアクセス可能）
    package let session: URLSession

    /// リトライ設定（パッケージ内の他モジュールからアクセス可能）
    package let retryConfiguration: RetryConfiguration

    /// リトライイベントハンドラー（パッケージ内の他モジュールからアクセス可能）
    package let retryEventHandler: RetryEventHandler?

    /// デフォルトベース URL
    package static let defaultBaseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    // MARK: - Initializers

    /// API キーを指定して初期化
    ///
    /// - Parameters:
    ///   - apiKey: Google AI API キー
    ///   - baseURL: カスタムベース URL（オプション）
    ///   - session: カスタム URLSession（オプション）
    ///   - retryConfiguration: リトライ設定（デフォルト: 有効）
    ///   - retryEventHandler: リトライイベントハンドラー（オプション）
    public init(
        apiKey: String,
        baseURL: String? = nil,
        session: URLSession = .shared,
        retryConfiguration: RetryConfiguration = .default,
        retryEventHandler: RetryEventHandler? = nil
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL ?? Self.defaultBaseURL
        self.session = session
        self.retryConfiguration = retryConfiguration
        self.retryEventHandler = retryEventHandler

        let baseProvider = GeminiProvider(
            apiKey: apiKey,
            baseURL: baseURL,
            session: session
        )

        if retryConfiguration.isEnabled {
            self.provider = RetryableProvider(
                provider: baseProvider,
                extractorType: GeminiRateLimitExtractor.self,
                retryPolicy: retryConfiguration.policy,
                eventHandler: retryEventHandler
            )
        } else {
            self.provider = baseProvider
        }
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

}
