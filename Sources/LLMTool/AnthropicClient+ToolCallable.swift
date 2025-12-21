import Foundation
import LLMClient
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - AnthropicClient + ToolCallableClient

extension AnthropicClient: ToolCallableClient {
    /// ツール呼び出しを計画する（会話履歴付き）
    ///
    /// Anthropic Claude API を使用してツール呼び出しを計画します。
    public func planToolCalls(
        messages: [LLMMessage],
        model: ClaudeModel,
        tools: ToolSet,
        toolChoice: ToolChoice?,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> ToolCallResponse {
        // HTTPリクエストを構築
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")

        // リクエストボディを構築
        let body = try buildToolRequestBody(
            model: model,
            messages: messages,
            tools: tools,
            toolChoice: toolChoice,
            systemPrompt: systemPrompt,
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
        return try handleToolResponse(data: data, httpResponse: httpResponse)
    }

    // MARK: - Private Constants

    /// API バージョン
    private static let apiVersion = "2023-06-01"

    /// デフォルトの最大トークン数
    private static let defaultMaxTokens = 4096

    // MARK: - Private Helpers

    /// ツールリクエストボディを構築
    ///
    /// - Throws: `LLMError.mediaNotSupported` メディアコンテンツが含まれている場合
    private func buildToolRequestBody(
        model: ClaudeModel,
        messages: [LLMMessage],
        tools: ToolSet,
        toolChoice: ToolChoice?,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) throws -> AnthropicToolRequestBody {
        let anthropicMessages = try messages.map { try convertToAnthropicMessage($0) }
        let anthropicTools = tools.toAnthropicFormat()
        let anthropicToolChoice = toolChoice.map { mapToolChoice($0) }

        return AnthropicToolRequestBody(
            model: model.id,
            messages: anthropicMessages,
            system: systemPrompt,
            maxTokens: maxTokens ?? Self.defaultMaxTokens,
            temperature: temperature,
            tools: anthropicTools,
            toolChoice: anthropicToolChoice
        )
    }

    /// LLMMessage を Anthropic メッセージ形式に変換
    ///
    /// - Throws: `LLMError.mediaNotSupported` メディアコンテンツが含まれている場合
    private func convertToAnthropicMessage(_ message: LLMMessage) throws -> AnthropicToolMessage {
        let role = message.role == .user ? "user" : "assistant"
        var contentBlocks: [AnthropicToolMessageContent] = []

        for content in message.contents {
            switch content {
            case .text(let text):
                contentBlocks.append(.text(text))
            case .toolUse(let id, let name, let input):
                contentBlocks.append(.toolUse(id: id, name: name, input: input))
            case .toolResult(let toolCallId, _, let resultContent, let isError):
                contentBlocks.append(.toolResult(toolUseId: toolCallId, content: resultContent, isError: isError))
            case .image:
                // Tool APIではメディアコンテンツは現在サポートされていません
                throw LLMError.mediaNotSupported(mediaType: "image", provider: "Anthropic Tool API")
            case .audio:
                throw LLMError.mediaNotSupported(mediaType: "audio", provider: "Anthropic Tool API")
            case .video:
                throw LLMError.mediaNotSupported(mediaType: "video", provider: "Anthropic Tool API")
            }
        }

        return AnthropicToolMessage(role: role, content: contentBlocks)
    }

    /// ToolChoice を Anthropic 形式に変換
    private func mapToolChoice(_ choice: ToolChoice) -> AnthropicToolChoiceValue {
        switch choice {
        case .auto:
            return .auto
        case .none:
            return .none
        case .required:
            return .any
        case .tool(let name):
            return .tool(name)
        }
    }

    /// レスポンスを処理
    private func handleToolResponse(data: Data, httpResponse: HTTPURLResponse) throws -> ToolCallResponse {
        // エラーステータスコードの処理
        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw LLMError.unauthorized
        case 429:
            throw LLMError.rateLimitExceeded
        case 400:
            let errorResponse = try? JSONDecoder().decode(AnthropicToolErrorResponse.self, from: data)
            throw LLMError.invalidRequest(errorResponse?.error.message ?? "Bad request")
        case 404:
            let errorResponse = try? JSONDecoder().decode(AnthropicToolErrorResponse.self, from: data)
            throw LLMError.modelNotFound(errorResponse?.error.message ?? "Model not found")
        case 500...599:
            let errorResponse = try? JSONDecoder().decode(AnthropicToolErrorResponse.self, from: data)
            throw LLMError.serverError(httpResponse.statusCode, errorResponse?.error.message ?? "Server error")
        default:
            throw LLMError.serverError(httpResponse.statusCode, "Unexpected status code")
        }

        // 成功レスポンスをデコード
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let anthropicResponse: AnthropicToolResponseBody
        do {
            anthropicResponse = try decoder.decode(AnthropicToolResponseBody.self, from: data)
        } catch {
            throw LLMError.decodingFailed(error)
        }

        // ToolCallResponse に変換
        return parseToolCallResponse(anthropicResponse)
    }

    /// Anthropic レスポンスから ToolCallResponse を生成
    private func parseToolCallResponse(_ response: AnthropicToolResponseBody) -> ToolCallResponse {
        var toolCalls: [ToolCall] = []
        var textContent: String?

        for block in response.content {
            switch block.type {
            case "text":
                textContent = block.text
            case "tool_use":
                if let id = block.id, let name = block.name, let input = block.input {
                    if let inputData = try? JSONSerialization.data(withJSONObject: input) {
                        toolCalls.append(ToolCall(id: id, name: name, arguments: inputData))
                    }
                }
            default:
                break
            }
        }

        let stopReason: LLMResponse.StopReason? = response.stopReason.flatMap { LLMResponse.StopReason(rawValue: $0) }

        return ToolCallResponse(
            toolCalls: toolCalls,
            text: textContent,
            usage: TokenUsage(
                inputTokens: response.usage.inputTokens,
                outputTokens: response.usage.outputTokens
            ),
            stopReason: stopReason,
            model: response.model
        )
    }
}

// MARK: - Anthropic Tool Request/Response Types

/// Anthropic ツールリクエストボディ
private struct AnthropicToolRequestBody: Encodable {
    let model: String
    let messages: [AnthropicToolMessage]
    let system: String?
    let maxTokens: Int
    let temperature: Double?
    let tools: [[String: Any]]
    let toolChoice: AnthropicToolChoiceValue?

    enum CodingKeys: String, CodingKey {
        case model, messages, system, temperature, tools
        case maxTokens = "max_tokens"
        case toolChoice = "tool_choice"
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

        // tools を直接エンコード
        let toolDefs = tools.map { AnthropicToolDef(dict: $0) }
        try container.encode(toolDefs, forKey: .tools)

        if let toolChoice = toolChoice {
            try container.encode(toolChoice, forKey: .toolChoice)
        }
    }
}

/// Anthropic ツール定義
private struct AnthropicToolDef: Encodable {
    let name: String
    let description: String
    let inputSchema: [String: Any]

    init(dict: [String: Any]) {
        self.name = dict["name"] as? String ?? ""
        self.description = dict["description"] as? String ?? ""
        self.inputSchema = dict["input_schema"] as? [String: Any] ?? [:]
    }

    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        let schemaData = try JSONSerialization.data(withJSONObject: inputSchema)
        let schemaJSON = try JSONDecoder().decode(JSONValue.self, from: schemaData)
        try container.encode(schemaJSON, forKey: .inputSchema)
    }
}

/// Anthropic ツール選択値
private enum AnthropicToolChoiceValue: Encodable {
    case auto
    case any
    case none
    case tool(String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .auto:
            try container.encode(["type": "auto"])
        case .any:
            try container.encode(["type": "any"])
        case .none:
            try container.encode(["type": "auto"])
        case .tool(let name):
            try container.encode(["type": "tool", "name": name])
        }
    }
}

/// Anthropic メッセージ
private struct AnthropicToolMessage: Encodable {
    let role: String
    let content: [AnthropicToolMessageContent]
}

/// Anthropic メッセージコンテンツ
private enum AnthropicToolMessageContent: Encodable {
    case text(String)
    case toolUse(id: String, name: String, input: Data)
    case toolResult(toolUseId: String, content: String, isError: Bool)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .text(let text):
            try container.encode(["type": "text", "text": text])

        case .toolUse(let id, let name, let input):
            let inputDict: [String: Any]
            if let dict = try? JSONSerialization.jsonObject(with: input) as? [String: Any] {
                inputDict = dict
            } else {
                inputDict = [:]
            }
            let inputData = try JSONSerialization.data(withJSONObject: inputDict)
            let inputJSON = try JSONDecoder().decode(JSONValue.self, from: inputData)

            let dict: [String: JSONValue] = [
                "type": .string("tool_use"),
                "id": .string(id),
                "name": .string(name),
                "input": inputJSON
            ]
            try container.encode(dict)

        case .toolResult(let toolUseId, let resultContent, let isError):
            var dict: [String: JSONValue] = [
                "type": .string("tool_result"),
                "tool_use_id": .string(toolUseId),
                "content": .string(resultContent)
            ]
            if isError {
                dict["is_error"] = .bool(true)
            }
            try container.encode(dict)
        }
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

/// Anthropic ツールレスポンスボディ
private struct AnthropicToolResponseBody: Decodable {
    let id: String
    let type: String
    let role: String
    let content: [AnthropicToolContentBlock]
    let model: String
    let stopReason: String?
    let usage: AnthropicToolUsage
}

/// Anthropic コンテンツブロック
private struct AnthropicToolContentBlock: Decodable {
    let type: String
    let text: String?
    let id: String?
    let name: String?
    let input: [String: Any]?

    enum CodingKeys: String, CodingKey {
        case type, text, id, name, input
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        if let inputData = try? container.decodeIfPresent(AnyCodable.self, forKey: .input) {
            input = inputData.value as? [String: Any]
        } else {
            input = nil
        }
    }
}

/// 任意の JSON 値をデコードするためのラッパー
private struct AnyCodable: Decodable {
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
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }
}

/// Anthropic 使用量
private struct AnthropicToolUsage: Decodable {
    let inputTokens: Int
    let outputTokens: Int
}

/// Anthropic エラーレスポンス
private struct AnthropicToolErrorResponse: Decodable {
    let type: String
    let error: AnthropicToolError
}

/// Anthropic エラー詳細
private struct AnthropicToolError: Decodable {
    let type: String
    let message: String
}
