import Foundation
import LLMClient
import LLMTool
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - AnthropicClient + AgentCapableClient

extension AnthropicClient: AgentCapableClient {
    /// エージェントステップを実行
    ///
    /// Anthropic Claude API を使用してエージェントステップを実行します。
    /// ツールコールと構造化出力の両方をサポートします。
    /// リトライ設定に基づいて、レート制限やサーバーエラー時に自動リトライを行います。
    public func executeAgentStep(
        messages: [LLMMessage],
        model: ClaudeModel,
        systemPrompt: Prompt?,
        tools: ToolSet,
        toolChoice: ToolChoice?,
        responseSchema: JSONSchema?
    ) async throws -> LLMResponse {
        // HTTPリクエストを構築
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")

        // 構造化出力を使用する場合はベータヘッダーを追加
        if responseSchema != nil {
            urlRequest.setValue(Self.structuredOutputsBeta, forHTTPHeaderField: "anthropic-beta")
        }

        // リクエストボディを構築
        let body = try buildAgentRequestBody(
            model: model,
            messages: messages,
            systemPrompt: systemPrompt,
            tools: tools,
            toolChoice: toolChoice,
            responseSchema: responseSchema
        )
        urlRequest.httpBody = try JSONEncoder().encode(body)

        // リトライヘルパーを使用してリクエストを実行
        let retryHelper = AgentRetryHelper<AnthropicRateLimitExtractor>(
            configuration: retryConfiguration,
            eventHandler: retryEventHandler
        )

        return try await retryHelper.execute(
            session: session,
            request: urlRequest,
            parseError: { data, statusCode in
                try parseAgentError(data: data, statusCode: statusCode)
            },
            parseResponse: { data, _ in
                try parseAgentSuccessResponse(data: data)
            }
        )
    }

    // MARK: - Private Constants

    /// API バージョン
    private static let apiVersion = "2023-06-01"

    /// 構造化出力のベータヘッダー
    private static let structuredOutputsBeta = "structured-outputs-2025-11-13"

    /// デフォルトの最大トークン数
    private static let defaultMaxTokens = 4096

    // MARK: - Private Helpers

    /// エージェントリクエストボディを構築
    ///
    /// - Throws: `LLMError.mediaNotSupported` メディアコンテンツが含まれている場合
    private func buildAgentRequestBody(
        model: ClaudeModel,
        messages: [LLMMessage],
        systemPrompt: Prompt?,
        tools: ToolSet,
        toolChoice: ToolChoice?,
        responseSchema: JSONSchema?
    ) throws -> AnthropicAgentRequestBody {
        let anthropicMessages = try messages.map { try convertToAnthropicMessage($0) }

        // ツール設定（空の場合は nil）
        let anthropicTools: [[String: Any]]? = tools.isEmpty ? nil : tools.toAnthropicFormat()
        let anthropicToolChoice: AnthropicAgentToolChoice? = tools.isEmpty ? nil : (toolChoice.map { mapToolChoice($0) } ?? .auto)

        // 構造化出力の設定
        var outputFormat: AnthropicAgentOutputFormat?
        if let schema = responseSchema {
            outputFormat = AnthropicAgentOutputFormat(
                type: "json_schema",
                schema: schema
            )
        }

        return AnthropicAgentRequestBody(
            model: model.id,
            messages: anthropicMessages,
            system: systemPrompt?.render(),
            maxTokens: Self.defaultMaxTokens,
            temperature: nil,
            tools: anthropicTools,
            toolChoice: anthropicToolChoice,
            outputFormat: outputFormat
        )
    }

    /// LLMMessage を Anthropic メッセージ形式に変換
    ///
    /// - Throws: `LLMError.mediaNotSupported` メディアコンテンツが含まれている場合
    private func convertToAnthropicMessage(_ message: LLMMessage) throws -> AnthropicAgentMessage {
        let role = message.role == .user ? "user" : "assistant"
        var contentBlocks: [AnthropicAgentMessageContent] = []

        for content in message.contents {
            switch content {
            case .text(let text):
                contentBlocks.append(.text(text))
            case .toolUse(let id, let name, let input):
                contentBlocks.append(.toolUse(id: id, name: name, input: input))
            case .toolResult(let toolCallId, _, let resultContent, let isError):
                contentBlocks.append(.toolResult(toolUseId: toolCallId, content: resultContent, isError: isError))
            case .image:
                // Agent APIではメディアコンテンツは現在サポートされていません
                throw LLMError.mediaNotSupported(mediaType: "image", provider: "Anthropic Agent API")
            case .audio:
                throw LLMError.mediaNotSupported(mediaType: "audio", provider: "Anthropic Agent API")
            case .video:
                throw LLMError.mediaNotSupported(mediaType: "video", provider: "Anthropic Agent API")
            }
        }

        return AnthropicAgentMessage(role: role, content: contentBlocks)
    }

    /// ToolChoice を Anthropic 形式に変換
    private func mapToolChoice(_ choice: ToolChoice) -> AnthropicAgentToolChoice {
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

    /// エラーステータスコードから LLMError を生成
    private func parseAgentError(data: Data, statusCode: Int) throws -> LLMError {
        switch statusCode {
        case 401:
            return .unauthorized
        case 429:
            return .rateLimitExceeded
        case 400:
            let errorResponse = try? JSONDecoder().decode(AnthropicAgentErrorResponse.self, from: data)
            return .invalidRequest(errorResponse?.error.message ?? "Bad request")
        case 404:
            let errorResponse = try? JSONDecoder().decode(AnthropicAgentErrorResponse.self, from: data)
            return .modelNotFound(errorResponse?.error.message ?? "Model not found")
        case 500...599:
            let errorResponse = try? JSONDecoder().decode(AnthropicAgentErrorResponse.self, from: data)
            return .serverError(statusCode, errorResponse?.error.message ?? "Server error")
        default:
            return .serverError(statusCode, "Unexpected status code")
        }
    }

    /// 成功レスポンスから LLMResponse を生成
    private func parseAgentSuccessResponse(data: Data) throws -> LLMResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let anthropicResponse: AnthropicAgentResponseBody
        do {
            anthropicResponse = try decoder.decode(AnthropicAgentResponseBody.self, from: data)
        } catch {
            throw LLMError.decodingFailed(error)
        }

        return convertToLLMResponse(anthropicResponse)
    }

    /// Anthropic レスポンスから LLMResponse を生成
    private func convertToLLMResponse(_ response: AnthropicAgentResponseBody) -> LLMResponse {
        let contentBlocks: [LLMResponse.ContentBlock] = response.content.compactMap { block in
            switch block.type {
            case "text":
                return block.text.map { .text($0) }
            case "tool_use":
                guard let id = block.id, let name = block.name, let input = block.input else {
                    return nil
                }
                if let inputData = try? JSONSerialization.data(withJSONObject: input) {
                    return .toolUse(id: id, name: name, input: inputData)
                }
                return nil
            default:
                return nil
            }
        }

        let stopReason: LLMResponse.StopReason? = response.stopReason.flatMap { LLMResponse.StopReason(rawValue: $0) }

        return LLMResponse(
            content: contentBlocks,
            model: response.model,
            usage: TokenUsage(
                inputTokens: response.usage.inputTokens,
                outputTokens: response.usage.outputTokens
            ),
            stopReason: stopReason
        )
    }
}

// MARK: - Anthropic Agent Request/Response Types

/// Anthropic エージェントリクエストボディ
private struct AnthropicAgentRequestBody: Encodable {
    let model: String
    let messages: [AnthropicAgentMessage]
    let system: String?
    let maxTokens: Int
    let temperature: Double?
    let tools: [[String: Any]]?
    let toolChoice: AnthropicAgentToolChoice?
    let outputFormat: AnthropicAgentOutputFormat?

    enum CodingKeys: String, CodingKey {
        case model, messages, system, temperature, tools
        case maxTokens = "max_tokens"
        case toolChoice = "tool_choice"
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

        if let tools = tools {
            let toolDefs = tools.map { AnthropicAgentToolDef(dict: $0) }
            try container.encode(toolDefs, forKey: .tools)
        }

        if let toolChoice = toolChoice {
            try container.encode(toolChoice, forKey: .toolChoice)
        }

        if let outputFormat = outputFormat {
            try container.encode(outputFormat, forKey: .outputFormat)
        }
    }
}

/// Anthropic ツール定義
private struct AnthropicAgentToolDef: Encodable {
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
        let schemaJSON = try JSONDecoder().decode(AgentJSONValue.self, from: schemaData)
        try container.encode(schemaJSON, forKey: .inputSchema)
    }
}

/// Anthropic ツール選択値
private enum AnthropicAgentToolChoice: Encodable {
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

/// Anthropic 出力フォーマット設定
private struct AnthropicAgentOutputFormat: Encodable {
    let type: String
    let schema: JSONSchema
}

/// Anthropic メッセージ
private struct AnthropicAgentMessage: Encodable {
    let role: String
    let content: [AnthropicAgentMessageContent]
}

/// Anthropic メッセージコンテンツ
private enum AnthropicAgentMessageContent: Encodable {
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
            let inputJSON = try JSONDecoder().decode(AgentJSONValue.self, from: inputData)

            let dict: [String: AgentJSONValue] = [
                "type": .string("tool_use"),
                "id": .string(id),
                "name": .string(name),
                "input": inputJSON
            ]
            try container.encode(dict)

        case .toolResult(let toolUseId, let resultContent, let isError):
            var dict: [String: AgentJSONValue] = [
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
private enum AgentJSONValue: Codable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AgentJSONValue])
    case object([String: AgentJSONValue])

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
        } else if let array = try? container.decode([AgentJSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: AgentJSONValue].self) {
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

/// Anthropic エージェントレスポンスボディ
private struct AnthropicAgentResponseBody: Decodable {
    let id: String
    let type: String
    let role: String
    let content: [AnthropicAgentContentBlock]
    let model: String
    let stopReason: String?
    let usage: AnthropicAgentUsage
}

/// Anthropic コンテンツブロック
private struct AnthropicAgentContentBlock: Decodable {
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
        if let inputData = try? container.decodeIfPresent(AgentAnyCodable.self, forKey: .input) {
            input = inputData.value as? [String: Any]
        } else {
            input = nil
        }
    }
}

/// 任意の JSON 値をデコードするためのラッパー
private struct AgentAnyCodable: Decodable {
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
        } else if let array = try? container.decode([AgentAnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AgentAnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }
}

/// Anthropic 使用量
private struct AnthropicAgentUsage: Decodable {
    let inputTokens: Int
    let outputTokens: Int
}

/// Anthropic エラーレスポンス
private struct AnthropicAgentErrorResponse: Decodable {
    let type: String
    let error: AnthropicAgentError
}

/// Anthropic エラー詳細
private struct AnthropicAgentError: Decodable {
    let type: String
    let message: String
}
