import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - AnthropicProvider

/// Anthropic Claude API プロバイダー（内部実装）
///
/// このプロバイダーは `AnthropicClient` 内部で使用されます。
/// 直接使用する場合は `AnthropicClient` を使用してください。
internal struct AnthropicProvider: LLMProvider {
    /// API エンドポイント
    private let endpoint: URL

    /// API キー
    private let apiKey: String

    /// URLSession
    private let session: URLSession

    /// API バージョン
    private static let apiVersion = "2023-06-01"

    /// 構造化出力のベータヘッダー
    private static let structuredOutputsBeta = "structured-outputs-2025-11-13"

    /// デフォルトエンドポイント
    private static let defaultEndpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    /// デフォルトの最大トークン数
    private static let defaultMaxTokens = 4096

    // MARK: - Initializers

    /// API キーを指定して初期化
    ///
    /// - Parameters:
    ///   - apiKey: Anthropic API キー
    ///   - endpoint: カスタムエンドポイント（オプション）
    ///   - session: カスタム URLSession（オプション）
    public init(
        apiKey: String,
        endpoint: URL? = nil,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint ?? Self.defaultEndpoint
        self.session = session
    }

    // MARK: - LLMProvider

    public func send(_ request: LLMRequest) async throws -> LLMResponse {
        // モデルの検証
        guard case .claude = request.model else {
            throw LLMError.modelNotSupported(model: request.model.id, provider: "Anthropic")
        }

        // HTTPリクエストを構築
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")

        // 構造化出力を使用する場合はベータヘッダーを追加
        if request.responseSchema != nil {
            urlRequest.setValue(Self.structuredOutputsBeta, forHTTPHeaderField: "anthropic-beta")
        }

        // リクエストボディを構築
        let body = try buildRequestBody(from: request)
        urlRequest.httpBody = try JSONEncoder().encode(body)

        // リクエストを送信
        let (data, response) = try await performRequest(urlRequest)

        // レスポンスを処理
        return try handleResponse(data: data, response: response)
    }

    // MARK: - Private Helpers

    /// リクエストボディを構築
    private func buildRequestBody(from request: LLMRequest) throws -> AnthropicRequestBody {
        // メッセージを変換
        let messages = request.messages.map { message in
            AnthropicMessage(
                role: message.role == .user ? "user" : "assistant",
                content: message.content
            )
        }

        // 構造化出力の設定（Anthropic APIでサポートされていない制約を除去）
        var outputFormat: AnthropicOutputFormat?
        if let schema = request.responseSchema {
            outputFormat = AnthropicOutputFormat(
                type: "json_schema",
                schema: schema.sanitizedForAnthropic()
            )
        }

        return AnthropicRequestBody(
            model: request.model.id,
            messages: messages,
            system: request.systemPrompt,
            maxTokens: request.maxTokens ?? Self.defaultMaxTokens,
            temperature: request.temperature,
            outputFormat: outputFormat
        )
    }

    /// HTTPリクエストを実行
    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw LLMError.networkError(error)
        }
    }

    /// レスポンスを処理
    private func handleResponse(data: Data, response: URLResponse) throws -> LLMResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidRequest("Invalid response type")
        }

        // エラーステータスコードの処理
        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw LLMError.unauthorized
        case 429:
            throw LLMError.rateLimitExceeded
        case 400:
            let errorResponse = try? JSONDecoder().decode(AnthropicErrorResponse.self, from: data)
            throw LLMError.invalidRequest(errorResponse?.error.message ?? "Bad request")
        case 404:
            let errorResponse = try? JSONDecoder().decode(AnthropicErrorResponse.self, from: data)
            throw LLMError.modelNotFound(errorResponse?.error.message ?? "Model not found")
        case 500...599:
            let errorResponse = try? JSONDecoder().decode(AnthropicErrorResponse.self, from: data)
            throw LLMError.serverError(httpResponse.statusCode, errorResponse?.error.message ?? "Server error")
        default:
            throw LLMError.serverError(httpResponse.statusCode, "Unexpected status code")
        }

        // 成功レスポンスをデコード
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let anthropicResponse: AnthropicResponseBody
        do {
            anthropicResponse = try decoder.decode(AnthropicResponseBody.self, from: data)
        } catch {
            throw LLMError.decodingFailed(error)
        }

        // 停止理由をチェック
        let stopReason = mapStopReason(anthropicResponse.stopReason)

        // コンテンツブロックを変換
        let contentBlocks = anthropicResponse.content.compactMap { block -> LLMResponse.ContentBlock? in
            switch block.type {
            case "text":
                return block.text.map { .text($0) }
            default:
                return nil
            }
        }

        guard !contentBlocks.isEmpty else {
            throw LLMError.emptyResponse
        }

        return LLMResponse(
            content: contentBlocks,
            model: anthropicResponse.model,
            usage: TokenUsage(
                inputTokens: anthropicResponse.usage.inputTokens,
                outputTokens: anthropicResponse.usage.outputTokens
            ),
            stopReason: stopReason
        )
    }

    /// 停止理由をマッピング
    private func mapStopReason(_ reason: String?) -> LLMResponse.StopReason? {
        guard let reason = reason else { return nil }
        return LLMResponse.StopReason(rawValue: reason)
    }
}

// MARK: - Request/Response Types

/// Anthropic API リクエストボディ
private struct AnthropicRequestBody: Encodable {
    let model: String
    let messages: [AnthropicMessage]
    let system: String?
    let maxTokens: Int
    let temperature: Double?
    let outputFormat: AnthropicOutputFormat?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case system
        case maxTokens = "max_tokens"
        case temperature
        case outputFormat = "output_format"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        if let system = system {
            try container.encode(system, forKey: .system)
        }
        try container.encode(maxTokens, forKey: .maxTokens)
        if let temperature = temperature {
            try container.encode(temperature, forKey: .temperature)
        }
        if let outputFormat = outputFormat {
            try container.encode(outputFormat, forKey: .outputFormat)
        }
    }
}

/// Anthropic メッセージ
private struct AnthropicMessage: Encodable {
    let role: String
    let content: String
}

/// Anthropic 出力フォーマット設定
private struct AnthropicOutputFormat: Encodable {
    let type: String
    let schema: JSONSchema
}

/// Anthropic API レスポンスボディ
private struct AnthropicResponseBody: Decodable {
    let id: String
    let type: String
    let role: String
    let content: [AnthropicContentBlock]
    let model: String
    let stopReason: String?
    let usage: AnthropicUsage
}

/// Anthropic コンテンツブロック
private struct AnthropicContentBlock: Decodable {
    let type: String
    let text: String?
}

/// Anthropic 使用量
private struct AnthropicUsage: Decodable {
    let inputTokens: Int
    let outputTokens: Int
}

/// Anthropic エラーレスポンス
private struct AnthropicErrorResponse: Decodable {
    let type: String
    let error: AnthropicError
}

/// Anthropic エラー詳細
private struct AnthropicError: Decodable {
    let type: String
    let message: String
}
