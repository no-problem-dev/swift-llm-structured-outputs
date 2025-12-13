import Foundation

// MARK: - OpenAIProvider

/// OpenAI GPT API プロバイダー（内部実装）
///
/// このプロバイダーは `OpenAIClient` 内部で使用されます。
/// 直接使用する場合は `OpenAIClient` を使用してください。
internal struct OpenAIProvider: LLMProvider {
    /// API エンドポイント
    private let endpoint: URL

    /// API キー
    private let apiKey: String

    /// URLSession
    private let session: URLSession

    /// 組織 ID（オプション）
    private let organization: String?

    /// デフォルトエンドポイント
    private static let defaultEndpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    /// デフォルトの最大トークン数
    private static let defaultMaxTokens = 4096

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
        self.apiKey = apiKey
        self.organization = organization
        self.endpoint = endpoint ?? Self.defaultEndpoint
        self.session = session
    }

    // MARK: - LLMProvider

    public func send(_ request: LLMRequest) async throws -> LLMResponse {
        // モデルの検証
        guard case .gpt = request.model else {
            throw LLMError.modelNotSupported(model: request.model.id, provider: "OpenAI")
        }

        // HTTPリクエストを構築
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        if let org = organization {
            urlRequest.setValue(org, forHTTPHeaderField: "OpenAI-Organization")
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
    private func buildRequestBody(from request: LLMRequest) throws -> OpenAIRequestBody {
        // メッセージを変換
        var messages: [OpenAIMessage] = []

        // システムプロンプト
        if let systemPrompt = request.systemPrompt {
            messages.append(OpenAIMessage(
                role: "system",
                content: systemPrompt
            ))
        }

        // ユーザー/アシスタントメッセージ
        for message in request.messages {
            messages.append(OpenAIMessage(
                role: message.role == .user ? "user" : "assistant",
                content: message.content
            ))
        }

        // 構造化出力の設定
        var responseFormat: OpenAIResponseFormat?
        if let schema = request.responseSchema {
            responseFormat = OpenAIResponseFormat(
                type: "json_schema",
                jsonSchema: OpenAIJSONSchemaWrapper(
                    name: "response",
                    strict: true,
                    schema: schema
                )
            )
        }

        return OpenAIRequestBody(
            model: request.model.id,
            messages: messages,
            maxCompletionTokens: request.maxTokens ?? Self.defaultMaxTokens,
            temperature: request.temperature,
            responseFormat: responseFormat
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
            let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data)
            throw LLMError.invalidRequest(errorResponse?.error.message ?? "Bad request")
        case 404:
            let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data)
            throw LLMError.modelNotFound(errorResponse?.error.message ?? "Model not found")
        case 500...599:
            let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data)
            throw LLMError.serverError(httpResponse.statusCode, errorResponse?.error.message ?? "Server error")
        default:
            throw LLMError.serverError(httpResponse.statusCode, "Unexpected status code")
        }

        // 成功レスポンスをデコード
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let openAIResponse: OpenAIResponseBody
        do {
            openAIResponse = try decoder.decode(OpenAIResponseBody.self, from: data)
        } catch {
            throw LLMError.decodingFailed(error)
        }

        // 最初の選択肢を取得
        guard let choice = openAIResponse.choices.first else {
            throw LLMError.emptyResponse
        }

        // 停止理由をマッピング
        let stopReason = mapStopReason(choice.finishReason)

        // コンテンツを取得
        guard let content = choice.message.content else {
            throw LLMError.emptyResponse
        }

        return LLMResponse(
            content: [.text(content)],
            model: openAIResponse.model,
            usage: TokenUsage(
                inputTokens: openAIResponse.usage.promptTokens,
                outputTokens: openAIResponse.usage.completionTokens
            ),
            stopReason: stopReason
        )
    }

    /// 停止理由をマッピング
    private func mapStopReason(_ reason: String?) -> LLMResponse.StopReason? {
        guard let reason = reason else { return nil }
        switch reason {
        case "stop":
            return .endTurn
        case "length":
            return .maxTokens
        default:
            return nil
        }
    }
}

// MARK: - Request/Response Types

/// OpenAI API リクエストボディ
private struct OpenAIRequestBody: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let maxCompletionTokens: Int
    let temperature: Double?
    let responseFormat: OpenAIResponseFormat?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxCompletionTokens = "max_completion_tokens"
        case temperature
        case responseFormat = "response_format"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encode(maxCompletionTokens, forKey: .maxCompletionTokens)
        if let temperature = temperature {
            try container.encode(temperature, forKey: .temperature)
        }
        if let responseFormat = responseFormat {
            try container.encode(responseFormat, forKey: .responseFormat)
        }
    }
}

/// OpenAI メッセージ
private struct OpenAIMessage: Encodable {
    let role: String
    let content: String
}

/// OpenAI レスポンスフォーマット設定
private struct OpenAIResponseFormat: Encodable {
    let type: String
    let jsonSchema: OpenAIJSONSchemaWrapper

    enum CodingKeys: String, CodingKey {
        case type
        case jsonSchema = "json_schema"
    }
}

/// JSON Schema ラッパー
private struct OpenAIJSONSchemaWrapper: Encodable {
    let name: String
    let strict: Bool
    let schema: JSONSchema
}

/// OpenAI API レスポンスボディ
private struct OpenAIResponseBody: Decodable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage
}

/// OpenAI 選択肢
private struct OpenAIChoice: Decodable {
    let index: Int
    let message: OpenAIResponseMessage
    let finishReason: String?
}

/// OpenAI レスポンスメッセージ
private struct OpenAIResponseMessage: Decodable {
    let role: String
    let content: String?
}

/// OpenAI 使用量
private struct OpenAIUsage: Decodable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}

/// OpenAI エラーレスポンス
private struct OpenAIErrorResponse: Decodable {
    let error: OpenAIError
}

/// OpenAI エラー詳細
private struct OpenAIError: Decodable {
    let message: String
    let type: String
    let param: String?
    let code: String?
}
