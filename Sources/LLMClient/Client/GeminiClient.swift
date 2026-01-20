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
///     input: "山田太郎さんは35歳です。",
///     model: .flash25
/// )
/// print(result.name)  // "山田太郎"
/// print(result.age)   // 35
///
/// // トークン使用量を取得
/// let resultWithUsage: GenerationResult<UserInfo> = try await client.generateWithUsage(
///     input: "山田太郎さんは35歳です。",
///     model: .flash3
/// )
/// print("Input tokens: \(resultWithUsage.usage.inputTokens)")
/// print("Output tokens: \(resultWithUsage.usage.outputTokens)")
///
/// // マルチモーダル入力
/// let result: ImageAnalysis = try await client.generate(
///     input: LLMInput("この画像を分析してください", images: [imageContent]),
///     model: .flash25
/// )
/// ```
///
/// ## 対応モデル
/// - `.flash3` - Gemini 3 Flash（最新・最高性能）
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

    public func generateWithUsage<T: StructuredProtocol>(
        input: LLMInput,
        model: GeminiModel,
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
        model: GeminiModel,
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
            model: .gemini(model),
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

        // マークダウンコードブロックからJSONを抽出
        let jsonText = extractJSON(from: text)

        guard let data = jsonText.data(using: .utf8) else {
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
                rawText: jsonText,
                stopReason: response.stopReason
            )
        } catch {
            throw LLMError.decodingFailed(error)
        }
    }

    /// テキストからJSONを抽出
    ///
    /// マークダウンコードブロック（```json ... ``` または ``` ... ```）で
    /// ラップされている場合は中身を抽出し、そうでなければそのまま返す。
    private func extractJSON(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // ```json で始まる場合
        if trimmed.hasPrefix("```json") {
            let content = trimmed.dropFirst(7) // "```json" を除去
            if let endIndex = content.range(of: "```", options: .backwards) {
                return String(content[content.startIndex..<endIndex.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // ``` で始まる場合（言語指定なし）
        if trimmed.hasPrefix("```") {
            let content = trimmed.dropFirst(3) // "```" を除去
            // 最初の改行まで（言語名の可能性）をスキップ
            let afterLang: Substring
            if let newlineIndex = content.firstIndex(of: "\n") {
                afterLang = content[content.index(after: newlineIndex)...]
            } else {
                afterLang = content
            }
            if let endIndex = afterLang.range(of: "```", options: .backwards) {
                return String(afterLang[afterLang.startIndex..<endIndex.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // コードブロックなし、そのまま返す
        return trimmed
    }

}
