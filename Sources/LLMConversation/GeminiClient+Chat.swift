import Foundation
import LLMClient
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - GeminiClient + ChatCapableClient

extension GeminiClient: ChatCapableClient {
    /// 会話を継続し、構造化出力と会話履歴情報を取得
    ///
    /// Google Gemini API を使用して会話を継続します。
    public func chat<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: GeminiModel,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> ChatResponse<T> {
        // エンドポイントを構築
        let endpoint = URL(string: "\(baseURL)/\(model.id):generateContent?key=\(apiKey)")!

        // HTTPリクエストを構築
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // リクエストボディを構築
        let body = try buildChatRequestBody(
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
        return try handleChatResponse(data: data, httpResponse: httpResponse, model: model)
    }

    // MARK: - Private Helpers

    /// チャットリクエストボディを構築
    private func buildChatRequestBody(
        messages: [LLMMessage],
        systemPrompt: String?,
        responseSchema: JSONSchema,
        temperature: Double?,
        maxTokens: Int?
    ) throws -> GeminiChatRequestBody {
        // メッセージを変換
        var geminiContents: [GeminiChatContent] = []

        for message in messages {
            geminiContents.append(try convertToGeminiContent(message))
        }

        // システム指示
        var systemInstruction: GeminiChatSystemInstruction?
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            systemInstruction = GeminiChatSystemInstruction(
                parts: [GeminiChatPart(text: systemPrompt)]
            )
        }

        // 生成設定
        let adapter = GeminiSchemaAdapter()
        let adaptedSchema = adapter.adapt(responseSchema)
        guard let schemaData = try? adaptedSchema.toJSONData(),
              let schemaDict = try? JSONSerialization.jsonObject(with: schemaData) as? [String: Any] else {
            throw LLMError.invalidRequest("Failed to convert schema to dictionary")
        }

        let generationConfig = GeminiChatGenerationConfig(
            temperature: temperature,
            maxOutputTokens: maxTokens,
            responseMimeType: "application/json",
            responseSchema: schemaDict
        )

        return GeminiChatRequestBody(
            contents: geminiContents,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig
        )
    }

    /// LLMMessage を Gemini コンテンツ形式に変換
    ///
    /// - Throws: `LLMError.mediaNotSupported` メディアコンテンツが含まれている場合
    private func convertToGeminiContent(_ message: LLMMessage) throws -> GeminiChatContent {
        let role = message.role == .user ? "user" : "model"
        var parts: [GeminiChatPart] = []

        for content in message.contents {
            switch content {
            case .text(let text):
                parts.append(GeminiChatPart(text: text))
            case .toolUse, .toolResult:
                // チャットではツール関連は無視
                break
            case .image:
                // Chat APIではメディアコンテンツは現在サポートされていません
                throw LLMError.mediaNotSupported(mediaType: "image", provider: "Gemini Chat API")
            case .audio:
                throw LLMError.mediaNotSupported(mediaType: "audio", provider: "Gemini Chat API")
            case .video:
                throw LLMError.mediaNotSupported(mediaType: "video", provider: "Gemini Chat API")
            }
        }

        return GeminiChatContent(role: role, parts: parts)
    }

    /// レスポンスを処理
    private func handleChatResponse<T: StructuredProtocol>(
        data: Data,
        httpResponse: HTTPURLResponse,
        model: GeminiModel
    ) throws -> ChatResponse<T> {
        // エラーステータスコードの処理
        switch httpResponse.statusCode {
        case 200:
            break
        case 401, 403:
            throw LLMError.unauthorized
        case 429:
            throw LLMError.rateLimitExceeded
        case 400:
            let errorResponse = try? JSONDecoder().decode(GeminiChatErrorResponse.self, from: data)
            throw LLMError.invalidRequest(errorResponse?.error.message ?? "Bad request")
        case 404:
            let errorResponse = try? JSONDecoder().decode(GeminiChatErrorResponse.self, from: data)
            throw LLMError.modelNotFound(errorResponse?.error.message ?? "Model not found")
        case 500...599:
            let errorResponse = try? JSONDecoder().decode(GeminiChatErrorResponse.self, from: data)
            throw LLMError.serverError(httpResponse.statusCode, errorResponse?.error.message ?? "Server error")
        default:
            throw LLMError.serverError(httpResponse.statusCode, "Unexpected status code")
        }

        // 成功レスポンスをデコード
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let geminiResponse: GeminiChatResponseBody
        do {
            geminiResponse = try decoder.decode(GeminiChatResponseBody.self, from: data)
        } catch {
            throw LLMError.decodingFailed(error)
        }

        // 最初の候補からコンテンツを取得
        guard let candidate = geminiResponse.candidates.first,
              let part = candidate.content.parts.first,
              let rawText = part.text else {
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
            guard let finishReason = candidate.finishReason else { return nil }
            switch finishReason {
            case "STOP": return .endTurn
            case "MAX_TOKENS": return .maxTokens
            default: return nil
            }
        }()

        // トークン使用量を取得
        let usage = geminiResponse.usageMetadata.map {
            TokenUsage(
                inputTokens: $0.promptTokenCount,
                outputTokens: $0.candidatesTokenCount
            )
        } ?? TokenUsage(inputTokens: 0, outputTokens: 0)

        return ChatResponse(
            result: result,
            assistantMessage: .assistant(rawText),
            usage: usage,
            stopReason: stopReason,
            model: model.id,
            rawText: rawText
        )
    }
}

// MARK: - Gemini Chat Request/Response Types

/// Gemini チャットリクエストボディ
private struct GeminiChatRequestBody: Encodable {
    let contents: [GeminiChatContent]
    let systemInstruction: GeminiChatSystemInstruction?
    let generationConfig: GeminiChatGenerationConfig

    enum CodingKeys: String, CodingKey {
        case contents
        case systemInstruction = "system_instruction"
        case generationConfig = "generationConfig"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contents, forKey: .contents)
        if let systemInstruction = systemInstruction {
            try container.encode(systemInstruction, forKey: .systemInstruction)
        }
        try container.encode(generationConfig, forKey: .generationConfig)
    }
}

/// Gemini コンテンツ
private struct GeminiChatContent: Encodable {
    let role: String
    let parts: [GeminiChatPart]
}

/// Gemini パーツ
private struct GeminiChatPart: Encodable {
    let text: String?

    init(text: String) {
        self.text = text
    }
}

/// Gemini システム指示
private struct GeminiChatSystemInstruction: Encodable {
    let parts: [GeminiChatPart]
}

/// Gemini 生成設定
private struct GeminiChatGenerationConfig: Encodable {
    let temperature: Double?
    let maxOutputTokens: Int?
    let responseMimeType: String
    let responseSchema: [String: Any]

    enum CodingKeys: String, CodingKey {
        case temperature
        case maxOutputTokens
        case responseMimeType
        case responseSchema
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let temperature = temperature {
            try container.encode(temperature, forKey: .temperature)
        }
        if let maxOutputTokens = maxOutputTokens {
            try container.encode(maxOutputTokens, forKey: .maxOutputTokens)
        }
        try container.encode(responseMimeType, forKey: .responseMimeType)

        let schemaData = try JSONSerialization.data(withJSONObject: responseSchema)
        let schemaJSON = try JSONDecoder().decode(JSONValue.self, from: schemaData)
        try container.encode(schemaJSON, forKey: .responseSchema)
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

/// Gemini チャットレスポンスボディ
private struct GeminiChatResponseBody: Decodable {
    let candidates: [GeminiChatCandidate]
    let usageMetadata: GeminiChatUsageMetadata?
}

/// Gemini 候補
private struct GeminiChatCandidate: Decodable {
    let content: GeminiChatResponseContent
    let finishReason: String?
}

/// Gemini レスポンスコンテンツ
private struct GeminiChatResponseContent: Decodable {
    let parts: [GeminiChatResponsePart]
    let role: String
}

/// Gemini レスポンスパーツ
private struct GeminiChatResponsePart: Decodable {
    let text: String?
}

/// Gemini 使用量メタデータ
private struct GeminiChatUsageMetadata: Decodable {
    let promptTokenCount: Int
    let candidatesTokenCount: Int
    let totalTokenCount: Int
}

/// Gemini エラーレスポンス
private struct GeminiChatErrorResponse: Decodable {
    let error: GeminiChatError
}

/// Gemini エラー詳細
private struct GeminiChatError: Decodable {
    let code: Int
    let message: String
    let status: String
}
