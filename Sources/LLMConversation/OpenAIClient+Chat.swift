import Foundation
import LLMClient
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - OpenAIClient + ChatCapableClient

extension OpenAIClient: ChatCapableClient {
    /// 会話を継続し、構造化出力と会話履歴情報を取得
    ///
    /// OpenAI GPT API を使用して会話を継続します。
    public func chat<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: GPTModel,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> ChatResponse<T> {
        // HTTPリクエストを構築
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if let organization = organization {
            urlRequest.setValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }

        // リクエストボディを構築
        let body = try buildChatRequestBody(
            model: model,
            messages: messages,
            systemPrompt: systemPrompt,
            responseSchema: T.jsonSchema,
            temperature: temperature,
            maxTokens: maxTokens
        )
        urlRequest.httpBody = try JSONEncoder().encode(body)

        // リクエストを送信
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidRequest("Invalid response type")
        }

        // レスポンスを処理
        return try handleChatResponse(data: data, httpResponse: httpResponse)
    }

    // MARK: - Private Helpers

    /// チャットリクエストボディを構築
    private func buildChatRequestBody(
        model: GPTModel,
        messages: [LLMMessage],
        systemPrompt: String?,
        responseSchema: JSONSchema,
        temperature: Double?,
        maxTokens: Int?
    ) throws -> OpenAIChatRequestBody {
        var openAIMessages: [OpenAIChatMessage] = []

        // システムプロンプトを先頭に追加
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            openAIMessages.append(OpenAIChatMessage(role: "system", content: systemPrompt))
        }

        // メッセージを変換
        for message in messages {
            openAIMessages.append(convertToOpenAIMessage(message))
        }

        // レスポンスフォーマットを構築
        let adapter = OpenAISchemaAdapter()
        let adaptedSchema = adapter.adapt(responseSchema)
        guard let schemaData = try? adaptedSchema.toJSONData(),
              let schemaDict = try? JSONSerialization.jsonObject(with: schemaData) as? [String: Any] else {
            throw LLMError.invalidRequest("Failed to convert schema to dictionary")
        }

        let responseFormat = OpenAIChatResponseFormat(
            type: "json_schema",
            jsonSchema: OpenAIChatJSONSchema(
                name: "response",
                strict: true,
                schema: schemaDict
            )
        )

        return OpenAIChatRequestBody(
            model: model.id,
            messages: openAIMessages,
            temperature: temperature,
            maxTokens: maxTokens,
            responseFormat: responseFormat
        )
    }

    /// LLMMessage を OpenAI メッセージ形式に変換
    private func convertToOpenAIMessage(_ message: LLMMessage) -> OpenAIChatMessage {
        let role = message.role == .user ? "user" : "assistant"

        // 最初のテキストコンテンツを取得
        let text = message.contents.compactMap { content -> String? in
            if case .text(let text) = content {
                return text
            }
            return nil
        }.first ?? ""

        return OpenAIChatMessage(role: role, content: text)
    }

    /// レスポンスを処理
    private func handleChatResponse<T: StructuredProtocol>(
        data: Data,
        httpResponse: HTTPURLResponse
    ) throws -> ChatResponse<T> {
        // エラーステータスコードの処理
        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw LLMError.unauthorized
        case 429:
            throw LLMError.rateLimitExceeded
        case 400:
            let errorResponse = try? JSONDecoder().decode(OpenAIChatErrorResponse.self, from: data)
            throw LLMError.invalidRequest(errorResponse?.error.message ?? "Bad request")
        case 404:
            let errorResponse = try? JSONDecoder().decode(OpenAIChatErrorResponse.self, from: data)
            throw LLMError.modelNotFound(errorResponse?.error.message ?? "Model not found")
        case 500...599:
            let errorResponse = try? JSONDecoder().decode(OpenAIChatErrorResponse.self, from: data)
            throw LLMError.serverError(httpResponse.statusCode, errorResponse?.error.message ?? "Server error")
        default:
            throw LLMError.serverError(httpResponse.statusCode, "Unexpected status code")
        }

        // 成功レスポンスをデコード
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let openAIResponse: OpenAIChatResponseBody
        do {
            openAIResponse = try decoder.decode(OpenAIChatResponseBody.self, from: data)
        } catch {
            throw LLMError.decodingFailed(error)
        }

        // 最初の選択肢からコンテンツを取得
        guard let choice = openAIResponse.choices.first,
              let rawText = choice.message.content else {
            throw LLMError.emptyResponse
        }

        // 構造化出力をデコード
        guard let jsonData = rawText.data(using: .utf8) else {
            throw LLMError.invalidEncoding
        }

        let resultDecoder = JSONDecoder()
        resultDecoder.keyDecodingStrategy = .convertFromSnakeCase

        let result: T
        do {
            result = try resultDecoder.decode(T.self, from: jsonData)
        } catch {
            throw LLMError.decodingFailed(error)
        }

        let stopReason: LLMResponse.StopReason? = {
            guard let finishReason = choice.finishReason else { return nil }
            switch finishReason {
            case "stop": return .endTurn
            case "length": return .maxTokens
            case "tool_calls": return .toolUse
            default: return nil
            }
        }()

        return ChatResponse(
            result: result,
            assistantMessage: .assistant(rawText),
            usage: TokenUsage(
                inputTokens: openAIResponse.usage.promptTokens,
                outputTokens: openAIResponse.usage.completionTokens
            ),
            stopReason: stopReason,
            model: openAIResponse.model,
            rawText: rawText
        )
    }
}

// MARK: - OpenAI Chat Request/Response Types

/// OpenAI チャットリクエストボディ
private struct OpenAIChatRequestBody: Encodable {
    let model: String
    let messages: [OpenAIChatMessage]
    let temperature: Double?
    let maxTokens: Int?
    let responseFormat: OpenAIChatResponseFormat

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
        case responseFormat = "response_format"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        if let temperature = temperature {
            try container.encode(temperature, forKey: .temperature)
        }
        if let maxTokens = maxTokens {
            try container.encode(maxTokens, forKey: .maxTokens)
        }
        try container.encode(responseFormat, forKey: .responseFormat)
    }
}

/// OpenAI メッセージ
private struct OpenAIChatMessage: Encodable {
    let role: String
    let content: String
}

/// OpenAI レスポンスフォーマット
private struct OpenAIChatResponseFormat: Encodable {
    let type: String
    let jsonSchema: OpenAIChatJSONSchema

    enum CodingKeys: String, CodingKey {
        case type
        case jsonSchema = "json_schema"
    }
}

/// OpenAI JSON スキーマ
private struct OpenAIChatJSONSchema: Encodable {
    let name: String
    let strict: Bool
    let schema: [String: Any]

    enum CodingKeys: String, CodingKey {
        case name, strict, schema
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(strict, forKey: .strict)
        let schemaData = try JSONSerialization.data(withJSONObject: schema)
        let schemaJSON = try JSONDecoder().decode(JSONValue.self, from: schemaData)
        try container.encode(schemaJSON, forKey: .schema)
    }
}

/// JSON 値の汎用エンコード/デコード用
private enum JSONValue: Codable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

/// OpenAI チャットレスポンスボディ
private struct OpenAIChatResponseBody: Decodable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAIChatChoice]
    let usage: OpenAIChatUsage
}

/// OpenAI 選択肢
private struct OpenAIChatChoice: Decodable {
    let index: Int
    let message: OpenAIChatResponseMessage
    let finishReason: String?
}

/// OpenAI レスポンスメッセージ
private struct OpenAIChatResponseMessage: Decodable {
    let role: String
    let content: String?
}

/// OpenAI 使用量
private struct OpenAIChatUsage: Decodable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}

/// OpenAI エラーレスポンス
private struct OpenAIChatErrorResponse: Decodable {
    let error: OpenAIChatError
}

/// OpenAI エラー詳細
private struct OpenAIChatError: Decodable {
    let message: String
    let type: String?
    let code: String?
}
