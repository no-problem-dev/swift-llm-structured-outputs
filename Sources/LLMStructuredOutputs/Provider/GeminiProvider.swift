import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - GeminiProvider

/// Google Gemini API プロバイダー（内部実装）
///
/// このプロバイダーは `GeminiClient` 内部で使用されます。
/// 直接使用する場合は `GeminiClient` を使用してください。
internal struct GeminiProvider: LLMProvider, RetryableProviderProtocol {
    /// API キー
    private let apiKey: String

    /// URLSession
    private let session: URLSession

    /// ベース URL
    private let baseURL: String

    /// デフォルトベース URL
    private static let defaultBaseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    /// デフォルトの最大トークン数
    private static let defaultMaxTokens = 4096

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
        self.apiKey = apiKey
        self.baseURL = baseURL ?? Self.defaultBaseURL
        self.session = session
    }

    // MARK: - LLMProvider

    func send(_ request: LLMRequest) async throws -> LLMResponse {
        let (response, _) = try await sendWithResponse(request)
        return response
    }

    // MARK: - RetryableProviderProtocol

    func sendWithResponse(_ request: LLMRequest) async throws -> (LLMResponse, HTTPURLResponse) {
        // モデルの検証
        guard case .gemini = request.model else {
            throw LLMError.modelNotSupported(model: request.model.id, provider: "Gemini")
        }

        // エンドポイントを構築
        let endpoint = URL(string: "\(baseURL)/\(request.model.id):generateContent?key=\(apiKey)")!

        // HTTPリクエストを構築
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // リクエストボディを構築
        let body = try buildRequestBody(from: request)
        urlRequest.httpBody = try JSONEncoder().encode(body)

        // リクエストを送信
        let (data, response) = try await performRequest(urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidRequest("Invalid response type")
        }

        // レスポンスを処理
        let llmResponse = try handleResponse(data: data, httpResponse: httpResponse, model: request.model.id)
        return (llmResponse, httpResponse)
    }

    // MARK: - Private Helpers

    /// リクエストボディを構築
    private func buildRequestBody(from request: LLMRequest) throws -> GeminiRequestBody {
        // コンテンツを構築
        var contents: [GeminiContent] = []

        for message in request.messages {
            contents.append(contentsOf: convertToGeminiContents(message))
        }

        // システムインストラクション
        var systemInstruction: GeminiContent?
        if let systemPrompt = request.systemPrompt {
            systemInstruction = GeminiContent(
                role: "user",
                parts: [GeminiPart(text: systemPrompt)]
            )
        }

        // 生成設定
        var generationConfig = GeminiGenerationConfig(
            maxOutputTokens: request.maxTokens ?? Self.defaultMaxTokens,
            temperature: request.temperature
        )

        // 構造化出力の設定
        if let schema = request.responseSchema {
            // Gemini用にスキーマをサニタイズ
            // - additionalProperties を除去（一部APIバージョンで未サポート）
            let sanitizedSchema = schema.sanitizedForGemini()
            generationConfig.responseMimeType = "application/json"
            generationConfig.responseSchema = sanitizedSchema
        }

        // ツール設定
        var tools: [GeminiTool]?
        var toolConfig: GeminiToolConfig?

        if let toolSet = request.tools, !toolSet.isEmpty {
            let geminiFormat = toolSet.toGeminiFormat()
            let declarations = geminiFormat.map { GeminiFunctionDeclaration(dict: $0) }
            tools = [GeminiTool(functionDeclarations: declarations)]

            if let choice = request.toolChoice {
                toolConfig = mapToolChoice(choice)
            }
        }

        return GeminiRequestBody(
            contents: contents,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            tools: tools,
            toolConfig: toolConfig
        )
    }

    /// ToolChoice を Gemini 形式に変換
    private func mapToolChoice(_ choice: ToolChoice) -> GeminiToolConfig {
        switch choice {
        case .auto:
            return GeminiToolConfig(
                functionCallingConfig: GeminiFunctionCallingConfig(mode: "AUTO", allowedFunctionNames: nil)
            )
        case .none:
            return GeminiToolConfig(
                functionCallingConfig: GeminiFunctionCallingConfig(mode: "NONE", allowedFunctionNames: nil)
            )
        case .required:
            return GeminiToolConfig(
                functionCallingConfig: GeminiFunctionCallingConfig(mode: "ANY", allowedFunctionNames: nil)
            )
        case .tool(let name):
            return GeminiToolConfig(
                functionCallingConfig: GeminiFunctionCallingConfig(mode: "ANY", allowedFunctionNames: [name])
            )
        }
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
    private func handleResponse(data: Data, httpResponse: HTTPURLResponse, model: String) throws -> LLMResponse {
        // レート制限情報を抽出
        let rateLimitInfo = GeminiRateLimitExtractor.extractRateLimitInfo(from: httpResponse)

        // エラーステータスコードの処理
        switch httpResponse.statusCode {
        case 200:
            break
        case 401, 403:
            throw LLMError.unauthorized
        case 429:
            // レート制限情報付きでエラーを投げる
            throw RateLimitAwareError(
                underlyingError: .rateLimitExceeded,
                rateLimitInfo: rateLimitInfo,
                statusCode: 429
            )
        case 400:
            let errorResponse = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data)
            throw LLMError.invalidRequest(errorResponse?.error.message ?? "Bad request")
        case 404:
            let errorResponse = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data)
            throw LLMError.modelNotFound(errorResponse?.error.message ?? "Model not found")
        case 500...599:
            let errorResponse = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data)
            // サーバーエラーもレート制限情報を含める（リトライ時に参照できるように）
            throw RateLimitAwareError(
                underlyingError: .serverError(httpResponse.statusCode, errorResponse?.error.message ?? "Server error"),
                rateLimitInfo: rateLimitInfo,
                statusCode: httpResponse.statusCode
            )
        default:
            throw LLMError.serverError(httpResponse.statusCode, "Unexpected status code")
        }

        // 成功レスポンスをデコード
        let decoder = JSONDecoder()

        let geminiResponse: GeminiResponseBody
        do {
            geminiResponse = try decoder.decode(GeminiResponseBody.self, from: data)
        } catch {
            throw LLMError.decodingFailed(error)
        }

        // 最初の候補を取得
        guard let candidate = geminiResponse.candidates?.first else {
            // コンテンツがブロックされた可能性をチェック
            if let promptFeedback = geminiResponse.promptFeedback,
               let blockReason = promptFeedback.blockReason {
                throw LLMError.contentBlocked(reason: blockReason)
            }
            throw LLMError.emptyResponse
        }

        // 停止理由をマッピング
        let stopReason = mapStopReason(candidate.finishReason)

        // コンテンツブロックを構築
        var contentBlocks: [LLMResponse.ContentBlock] = []

        if let content = candidate.content {
            for part in content.parts {
                // テキストコンテンツ
                if let text = part.text {
                    contentBlocks.append(.text(text))
                }
                // 関数呼び出し
                if let functionCall = part.functionCall {
                    if let argsData = try? JSONSerialization.data(withJSONObject: functionCall.args ?? [:]) {
                        contentBlocks.append(.toolUse(
                            id: UUID().uuidString, // Gemini はIDを返さないので生成
                            name: functionCall.name,
                            input: argsData
                        ))
                    }
                }
            }
        }

        // tool_use の場合は空でもOK
        guard !contentBlocks.isEmpty || stopReason == .toolUse else {
            throw LLMError.emptyResponse
        }

        // 使用量を取得（Gemini は usageMetadata で返す）
        let usage: TokenUsage
        if let usageMetadata = geminiResponse.usageMetadata {
            usage = TokenUsage(
                inputTokens: usageMetadata.promptTokenCount ?? 0,
                outputTokens: usageMetadata.candidatesTokenCount ?? 0
            )
        } else {
            usage = TokenUsage(inputTokens: 0, outputTokens: 0)
        }

        return LLMResponse(
            content: contentBlocks,
            model: model,
            usage: usage,
            stopReason: stopReason
        )
    }

    /// 停止理由をマッピング
    private func mapStopReason(_ reason: String?) -> LLMResponse.StopReason? {
        guard let reason = reason else { return nil }
        switch reason {
        case "STOP":
            return .endTurn
        case "MAX_TOKENS":
            return .maxTokens
        case "SAFETY":
            return nil // contentBlocked として扱う
        default:
            return nil
        }
    }

    /// LLMMessage を Gemini コンテンツ形式に変換
    ///
    /// Gemini APIでは:
    /// - テキストメッセージ: role="user"|"model", parts=[{text: "..."}]
    /// - ツール呼び出し: role="model", parts=[{functionCall: {name, args}}]
    /// - ツール結果: role="user", parts=[{functionResponse: {name, response}}]
    private func convertToGeminiContents(_ message: LLMMessage) -> [GeminiContent] {
        let role = message.role == .user ? "user" : "model"
        var parts: [GeminiPart] = []
        var toolResultParts: [GeminiPart] = []

        for content in message.contents {
            switch content {
            case .text(let text):
                parts.append(GeminiPart(text: text))

            case .toolUse(_, let name, let input):
                // ツール呼び出し（モデルからの応答）
                // inputをJSON辞書に変換
                let args: [String: Any]?
                if let argsDict = try? JSONSerialization.jsonObject(with: input) as? [String: Any] {
                    args = argsDict
                } else {
                    args = nil
                }
                let functionCall = GeminiFunctionCall(name: name, args: args)
                parts.append(GeminiPart(functionCall: functionCall))

            case .toolResult(_, let name, let resultContent, _):
                // ツール結果（ユーザーからの応答）
                // Gemini APIではfunctionResponseにはnameが必須
                let responseDict: [String: Any] = ["result": resultContent]
                let functionResponse = GeminiFunctionResponse(name: name, response: responseDict)
                toolResultParts.append(GeminiPart(functionResponse: functionResponse))
            }
        }

        var contents: [GeminiContent] = []

        // 通常のパーツ（テキストとツール呼び出し）
        if !parts.isEmpty {
            contents.append(GeminiContent(role: role, parts: parts))
        }

        // ツール結果は常にuserロールで送信
        if !toolResultParts.isEmpty {
            contents.append(GeminiContent(role: "user", parts: toolResultParts))
        }

        return contents
    }
}

// MARK: - Request/Response Types

/// Gemini API リクエストボディ
private struct GeminiRequestBody: Encodable {
    let contents: [GeminiContent]
    let systemInstruction: GeminiContent?
    let generationConfig: GeminiGenerationConfig
    let tools: [GeminiTool]?
    let toolConfig: GeminiToolConfig?
}

/// Gemini ツール
private struct GeminiTool: Encodable {
    let functionDeclarations: [GeminiFunctionDeclaration]
}

/// Gemini 関数宣言
private struct GeminiFunctionDeclaration: Encodable {
    let name: String
    let description: String
    let parameters: [String: Any]

    init(dict: [String: Any]) {
        self.name = dict["name"] as? String ?? ""
        self.description = dict["description"] as? String ?? ""
        self.parameters = dict["parameters"] as? [String: Any] ?? [:]
    }

    enum CodingKeys: String, CodingKey {
        case name, description, parameters
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        // parameters を JSON として手動エンコード
        let paramsData = try JSONSerialization.data(withJSONObject: parameters)
        let paramsJSON = try JSONDecoder().decode(GeminiJSONValue.self, from: paramsData)
        try container.encode(paramsJSON, forKey: .parameters)
    }
}

/// Gemini ツール設定
private struct GeminiToolConfig: Encodable {
    let functionCallingConfig: GeminiFunctionCallingConfig
}

/// Gemini 関数呼び出し設定
private struct GeminiFunctionCallingConfig: Encodable {
    let mode: String
    let allowedFunctionNames: [String]?
}

/// JSON 値の汎用エンコード用
private enum GeminiJSONValue: Codable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([GeminiJSONValue])
    case object([String: GeminiJSONValue])

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
        } else if let array = try? container.decode([GeminiJSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: GeminiJSONValue].self) {
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

/// Gemini コンテンツ
private struct GeminiContent: Codable {
    let role: String
    let parts: [GeminiPart]
}

/// Gemini パーツ
private struct GeminiPart: Codable {
    let text: String?
    let functionCall: GeminiFunctionCall?
    let functionResponse: GeminiFunctionResponse?

    init(text: String) {
        self.text = text
        self.functionCall = nil
        self.functionResponse = nil
    }

    init(functionCall: GeminiFunctionCall) {
        self.text = nil
        self.functionCall = functionCall
        self.functionResponse = nil
    }

    init(functionResponse: GeminiFunctionResponse) {
        self.text = nil
        self.functionCall = nil
        self.functionResponse = functionResponse
    }
}

/// Gemini 関数呼び出し
private struct GeminiFunctionCall: Codable {
    let name: String
    let args: [String: Any]?

    enum CodingKeys: String, CodingKey {
        case name, args
    }

    init(name: String, args: [String: Any]?) {
        self.name = name
        self.args = args
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        // args は任意の JSON なので手動でデコード
        if let argsJSON = try? container.decodeIfPresent(GeminiAnyCodable.self, forKey: .args) {
            args = argsJSON.value as? [String: Any]
        } else {
            args = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        if let args = args {
            let argsData = try JSONSerialization.data(withJSONObject: args)
            let argsJSON = try JSONDecoder().decode(GeminiJSONValue.self, from: argsData)
            try container.encode(argsJSON, forKey: .args)
        }
    }
}

/// Gemini 関数レスポンス（ツール実行結果）
private struct GeminiFunctionResponse: Codable {
    let name: String
    let response: [String: Any]

    enum CodingKeys: String, CodingKey {
        case name, response
    }

    init(name: String, response: [String: Any]) {
        self.name = name
        self.response = response
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        if let responseJSON = try? container.decode(GeminiAnyCodable.self, forKey: .response) {
            response = responseJSON.value as? [String: Any] ?? [:]
        } else {
            response = [:]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        let responseData = try JSONSerialization.data(withJSONObject: response)
        let responseJSON = try JSONDecoder().decode(GeminiJSONValue.self, from: responseData)
        try container.encode(responseJSON, forKey: .response)
    }
}

/// 任意の JSON 値をデコードするためのラッパー
private struct GeminiAnyCodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([GeminiAnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: GeminiAnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }
}

/// Gemini 生成設定
private struct GeminiGenerationConfig: Encodable {
    var maxOutputTokens: Int
    var temperature: Double?
    var responseMimeType: String?
    var responseSchema: JSONSchema?
}

/// Gemini API レスポンスボディ
private struct GeminiResponseBody: Decodable {
    let candidates: [GeminiCandidate]?
    let promptFeedback: GeminiPromptFeedback?
    let usageMetadata: GeminiUsageMetadata?
}

/// Gemini 候補
private struct GeminiCandidate: Decodable {
    let content: GeminiContent?
    let finishReason: String?
    let safetyRatings: [GeminiSafetyRating]?
}

/// Gemini プロンプトフィードバック
private struct GeminiPromptFeedback: Decodable {
    let blockReason: String?
    let safetyRatings: [GeminiSafetyRating]?
}

/// Gemini 安全性評価
private struct GeminiSafetyRating: Decodable {
    let category: String
    let probability: String
}

/// Gemini 使用量メタデータ
private struct GeminiUsageMetadata: Decodable {
    let promptTokenCount: Int?
    let candidatesTokenCount: Int?
    let totalTokenCount: Int?
}

/// Gemini エラーレスポンス
private struct GeminiErrorResponse: Decodable {
    let error: GeminiError
}

/// Gemini エラー詳細
private struct GeminiError: Decodable {
    let code: Int
    let message: String
    let status: String
}
