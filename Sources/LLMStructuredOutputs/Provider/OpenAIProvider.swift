import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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
                content: systemPrompt,
                toolCallId: nil,
                toolCalls: nil
            ))
        }

        // ユーザー/アシスタントメッセージ
        for message in request.messages {
            messages.append(contentsOf: convertToOpenAIMessages(message))
        }

        // 構造化出力の設定
        var responseFormat: OpenAIResponseFormat?
        if let schema = request.responseSchema {
            // OpenAI用にスキーマをサニタイズ
            // - additionalProperties: false を設定
            // - required 配列にすべてのプロパティを含める
            let sanitizedSchema = schema.sanitizedForOpenAI()
            responseFormat = OpenAIResponseFormat(
                type: "json_schema",
                jsonSchema: OpenAIJSONSchemaWrapper(
                    name: "response",
                    strict: true,
                    schema: sanitizedSchema
                )
            )
        }

        // ツール設定
        let tools = request.tools?.toOpenAIFormat().map { OpenAIToolDef(dict: $0) }
        let toolChoice = request.toolChoice.map { mapToolChoice($0) }

        return OpenAIRequestBody(
            model: request.model.id,
            messages: messages,
            maxCompletionTokens: request.maxTokens ?? Self.defaultMaxTokens,
            temperature: request.temperature,
            responseFormat: responseFormat,
            tools: tools,
            toolChoice: toolChoice
        )
    }

    /// ToolChoice を OpenAI 形式に変換
    private func mapToolChoice(_ choice: ToolChoice) -> OpenAIToolChoice {
        switch choice {
        case .auto:
            return .auto
        case .none:
            return .none
        case .required:
            return .required
        case .tool(let name):
            return .function(name)
        }
    }

    /// LLMMessage を OpenAI メッセージ形式に変換
    ///
    /// OpenAI では:
    /// - テキストメッセージ: `{"role": "user"|"assistant", "content": "..."}`
    /// - ツール呼び出し: `{"role": "assistant", "tool_calls": [...]}`
    /// - ツール結果: `{"role": "tool", "tool_call_id": "...", "content": "..."}`
    private func convertToOpenAIMessages(_ message: LLMMessage) -> [OpenAIMessage] {
        var result: [OpenAIMessage] = []

        // ツール結果を持つ場合、各結果を個別の tool メッセージとして送信
        // OpenAI APIではnameは不要（tool_call_idで関連付け）
        let toolResults = message.toolResults
        if !toolResults.isEmpty {
            for toolResult in toolResults {
                result.append(OpenAIMessage(
                    role: "tool",
                    content: toolResult.content,  // (toolCallId, name, content, isError)
                    toolCallId: toolResult.toolCallId,
                    toolCalls: nil
                ))
            }
            return result
        }

        // ツール呼び出しを持つ場合
        let toolUses = message.toolUses
        if !toolUses.isEmpty {
            let toolCalls = toolUses.map { toolUse -> OpenAIMessageToolCall in
                let argumentsString: String
                if let str = String(data: toolUse.input, encoding: .utf8) {
                    argumentsString = str
                } else {
                    argumentsString = "{}"
                }
                return OpenAIMessageToolCall(
                    id: toolUse.id,
                    type: "function",
                    function: OpenAIMessageToolCallFunction(
                        name: toolUse.name,
                        arguments: argumentsString
                    )
                )
            }
            result.append(OpenAIMessage(
                role: "assistant",
                content: message.content.isEmpty ? nil : message.content,
                toolCallId: nil,
                toolCalls: toolCalls
            ))
            return result
        }

        // 通常のテキストメッセージ
        let role = message.role == .user ? "user" : "assistant"
        result.append(OpenAIMessage(
            role: role,
            content: message.content,
            toolCallId: nil,
            toolCalls: nil
        ))
        return result
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

        // コンテンツブロックを構築
        var contentBlocks: [LLMResponse.ContentBlock] = []

        // テキストコンテンツ
        if let content = choice.message.content {
            contentBlocks.append(.text(content))
        }

        // ツール呼び出し
        if let toolCalls = choice.message.toolCalls {
            for toolCall in toolCalls {
                if toolCall.type == "function",
                   let argumentsData = toolCall.function.arguments.data(using: .utf8) {
                    contentBlocks.append(.toolUse(
                        id: toolCall.id,
                        name: toolCall.function.name,
                        input: argumentsData
                    ))
                }
            }
        }

        // tool_calls の場合は空でもOK
        guard !contentBlocks.isEmpty || stopReason == .toolUse else {
            throw LLMError.emptyResponse
        }

        return LLMResponse(
            content: contentBlocks,
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
        case "tool_calls":
            return .toolUse
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
    let tools: [OpenAIToolDef]?
    let toolChoice: OpenAIToolChoice?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxCompletionTokens = "max_completion_tokens"
        case temperature
        case responseFormat = "response_format"
        case tools
        case toolChoice = "tool_choice"
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
        if let tools = tools {
            try container.encode(tools, forKey: .tools)
        }
        if let toolChoice = toolChoice {
            try container.encode(toolChoice, forKey: .toolChoice)
        }
    }
}

/// OpenAI ツール定義
private struct OpenAIToolDef: Encodable {
    let type: String
    let function: OpenAIFunctionDef

    init(dict: [String: Any]) {
        self.type = dict["type"] as? String ?? "function"
        if let funcDict = dict["function"] as? [String: Any] {
            self.function = OpenAIFunctionDef(dict: funcDict)
        } else {
            self.function = OpenAIFunctionDef(dict: [:])
        }
    }
}

/// OpenAI 関数定義
private struct OpenAIFunctionDef: Encodable {
    let name: String
    let description: String
    let strict: Bool
    let parameters: [String: Any]

    init(dict: [String: Any]) {
        self.name = dict["name"] as? String ?? ""
        self.description = dict["description"] as? String ?? ""
        self.strict = dict["strict"] as? Bool ?? true
        self.parameters = dict["parameters"] as? [String: Any] ?? [:]
    }

    enum CodingKeys: String, CodingKey {
        case name, description, strict, parameters
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(strict, forKey: .strict)
        // parameters を JSON として手動エンコード
        let paramsData = try JSONSerialization.data(withJSONObject: parameters)
        let paramsJSON = try JSONDecoder().decode(OpenAIJSONValue.self, from: paramsData)
        try container.encode(paramsJSON, forKey: .parameters)
    }
}

/// OpenAI ツール選択
private enum OpenAIToolChoice: Encodable {
    case auto
    case none
    case required
    case function(String)

    private struct FunctionChoice: Encodable {
        let type: String
        let function: FunctionName

        struct FunctionName: Encodable {
            let name: String
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .auto:
            try container.encode("auto")
        case .none:
            try container.encode("none")
        case .required:
            try container.encode("required")
        case .function(let name):
            try container.encode(FunctionChoice(type: "function", function: .init(name: name)))
        }
    }
}

/// JSON 値の汎用エンコード用
private enum OpenAIJSONValue: Codable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([OpenAIJSONValue])
    case object([String: OpenAIJSONValue])

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
        } else if let array = try? container.decode([OpenAIJSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: OpenAIJSONValue].self) {
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

/// OpenAI メッセージ
private struct OpenAIMessage: Encodable {
    let role: String
    let content: String?
    let toolCallId: String?
    let toolCalls: [OpenAIMessageToolCall]?

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCallId = "tool_call_id"
        case toolCalls = "tool_calls"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)

        // content は nil でない場合のみエンコード
        if let content = content {
            try container.encode(content, forKey: .content)
        }

        // tool_call_id は tool role の場合のみ
        if let toolCallId = toolCallId {
            try container.encode(toolCallId, forKey: .toolCallId)
        }

        // tool_calls は assistant の場合のみ
        if let toolCalls = toolCalls {
            try container.encode(toolCalls, forKey: .toolCalls)
        }
    }
}

/// OpenAI メッセージ内のツール呼び出し
private struct OpenAIMessageToolCall: Encodable {
    let id: String
    let type: String
    let function: OpenAIMessageToolCallFunction
}

/// OpenAI メッセージ内のツール呼び出し関数
private struct OpenAIMessageToolCallFunction: Encodable {
    let name: String
    let arguments: String
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
    let toolCalls: [OpenAIToolCall]?
}

/// OpenAI ツール呼び出し
private struct OpenAIToolCall: Decodable {
    let id: String
    let type: String
    let function: OpenAIToolCallFunction
}

/// OpenAI ツール呼び出し関数
private struct OpenAIToolCallFunction: Decodable {
    let name: String
    let arguments: String
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
