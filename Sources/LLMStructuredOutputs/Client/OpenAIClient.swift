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
///     prompt: "山田太郎さんは35歳です。",
///     model: .gpt4o
/// )
/// print(result.name)  // "山田太郎"
/// print(result.age)   // 35
/// ```
///
/// ## 対応モデル
/// - `.gpt4o` - GPT-4o（最新）
/// - `.gpt4oMini` - GPT-4o mini（軽量版）
/// - `.gpt4Turbo` - GPT-4 Turbo
/// - `.gpt4` - GPT-4
/// - `.o1` - o1（推論特化）
/// - `.o1Mini` - o1 mini
public struct OpenAIClient: StructuredLLMClient {
    public typealias Model = GPTModel

    private let provider: OpenAIProvider

    // MARK: - Initializers

    /// API キーを指定して初期化
    ///
    /// - Parameters:
    ///   - apiKey: OpenAI API キー
    ///   - organization: 組織 ID（オプション）
    ///   - endpoint: カスタムエンドポイント（オプション）
    ///   - session: カスタム URLSession（オプション）
    public init(
        apiKey: String,
        organization: String? = nil,
        endpoint: URL? = nil,
        session: URLSession = .shared
    ) {
        self.provider = OpenAIProvider(
            apiKey: apiKey,
            organization: organization,
            endpoint: endpoint,
            session: session
        )
    }

    // MARK: - StructuredLLMClient

    public func generate<T: StructuredProtocol>(
        prompt: String,
        model: GPTModel,
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
        model: GPTModel,
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
            model: .gpt(model),
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

    // MARK: - Chat Methods

    public func chat<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: GPTModel,
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
            model: .gpt(model),
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
