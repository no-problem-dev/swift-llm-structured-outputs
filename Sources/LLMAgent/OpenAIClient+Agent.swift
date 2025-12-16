import Foundation
import LLMClient
import LLMTool
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - OpenAIClient + AgentCapableClient

extension OpenAIClient: AgentCapableClient {
    /// エージェントステップを実行
    ///
    /// OpenAI GPT API を使用してエージェントステップを実行します。
    /// ツールコールと構造化出力の両方をサポートします。
    /// リトライ設定に基づいて、レート制限やサーバーエラー時に自動リトライを行います。
    public func executeAgentStep(
        messages: [LLMMessage],
        model: GPTModel,
        systemPrompt: Prompt?,
        tools: ToolSet,
        toolChoice: ToolChoice?,
        responseSchema: JSONSchema?
    ) async throws -> LLMResponse {
        // HTTPリクエストを構築
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        if let org = organization {
            urlRequest.setValue(org, forHTTPHeaderField: "OpenAI-Organization")
        }

        // リクエストボディを構築
        let body = buildAgentRequestBody(
            model: model,
            messages: messages,
            systemPrompt: systemPrompt,
            tools: tools,
            toolChoice: toolChoice,
            responseSchema: responseSchema
        )
        urlRequest.httpBody = try JSONEncoder().encode(body)

        // リトライヘルパーを使用してリクエストを実行
        let retryHelper = AgentRetryHelper<OpenAIRateLimitExtractor>(
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

    /// デフォルトの最大トークン数
    private static let defaultMaxTokens = 4096

    // MARK: - Private Helpers

    /// エージェントリクエストボディを構築
    private func buildAgentRequestBody(
        model: GPTModel,
        messages: [LLMMessage],
        systemPrompt: Prompt?,
        tools: ToolSet,
        toolChoice: ToolChoice?,
        responseSchema: JSONSchema?
    ) -> OpenAIAgentRequestBody {
        var openAIMessages: [OpenAIAgentMessage] = []

        // システムプロンプト
        if let prompt = systemPrompt {
            openAIMessages.append(OpenAIAgentMessage(
                role: "system",
                content: prompt.render(),
                toolCallId: nil,
                toolCalls: nil
            ))
        }

        // ユーザー/アシスタントメッセージ
        for message in messages {
            openAIMessages.append(contentsOf: convertToOpenAIMessage(message))
        }

        // ツール設定（空の場合は nil）
        let openAITools: [OpenAIAgentToolDef]? = tools.isEmpty ? nil : tools.toOpenAIFormat().map { OpenAIAgentToolDef(dict: $0) }
        let openAIToolChoice: OpenAIAgentToolChoice? = tools.isEmpty ? nil : (toolChoice.map { mapToolChoice($0) } ?? .auto)

        // 構造化出力の設定
        var responseFormat: OpenAIAgentResponseFormat?
        if let schema = responseSchema {
            let adapter = OpenAISchemaAdapter()
            responseFormat = OpenAIAgentResponseFormat(
                type: "json_schema",
                jsonSchema: OpenAIAgentJSONSchemaWrapper(
                    name: "response",
                    strict: true,
                    schema: adapter.adapt(schema)
                )
            )
        }

        return OpenAIAgentRequestBody(
            model: model.id,
            messages: openAIMessages,
            maxCompletionTokens: Self.defaultMaxTokens,
            temperature: nil,
            tools: openAITools,
            toolChoice: openAIToolChoice,
            responseFormat: responseFormat
        )
    }

    /// LLMMessage を OpenAI メッセージ形式に変換
    private func convertToOpenAIMessage(_ message: LLMMessage) -> [OpenAIAgentMessage] {
        var result: [OpenAIAgentMessage] = []

        // ツール結果を持つ場合、各結果を個別の tool メッセージとして送信
        let toolResults = message.toolResults
        if !toolResults.isEmpty {
            for toolResult in toolResults {
                result.append(OpenAIAgentMessage(
                    role: "tool",
                    content: toolResult.content,
                    toolCallId: toolResult.toolCallId,
                    toolCalls: nil
                ))
            }
            return result
        }

        // ツール呼び出しを持つ場合
        let toolUses = message.toolUses
        if !toolUses.isEmpty {
            let toolCalls = toolUses.map { toolUse -> OpenAIAgentMessageToolCall in
                let argumentsString: String
                if let str = String(data: toolUse.input, encoding: .utf8) {
                    argumentsString = str
                } else {
                    argumentsString = "{}"
                }
                return OpenAIAgentMessageToolCall(
                    id: toolUse.id,
                    type: "function",
                    function: OpenAIAgentMessageFunction(
                        name: toolUse.name,
                        arguments: argumentsString
                    )
                )
            }
            result.append(OpenAIAgentMessage(
                role: "assistant",
                content: message.content.isEmpty ? nil : message.content,
                toolCallId: nil,
                toolCalls: toolCalls
            ))
            return result
        }

        // 通常のテキストメッセージ
        let role = message.role == .user ? "user" : "assistant"
        result.append(OpenAIAgentMessage(
            role: role,
            content: message.content,
            toolCallId: nil,
            toolCalls: nil
        ))
        return result
    }

    /// ToolChoice を OpenAI 形式に変換
    private func mapToolChoice(_ choice: ToolChoice) -> OpenAIAgentToolChoice {
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

    /// エラーステータスコードから LLMError を生成
    private func parseAgentError(data: Data, statusCode: Int) throws -> LLMError {
        switch statusCode {
        case 401:
            return .unauthorized
        case 429:
            return .rateLimitExceeded
        case 400:
            let errorResponse = try? JSONDecoder().decode(OpenAIAgentErrorResponse.self, from: data)
            return .invalidRequest(errorResponse?.error.message ?? "Bad request")
        case 404:
            let errorResponse = try? JSONDecoder().decode(OpenAIAgentErrorResponse.self, from: data)
            return .modelNotFound(errorResponse?.error.message ?? "Model not found")
        case 500...599:
            let errorResponse = try? JSONDecoder().decode(OpenAIAgentErrorResponse.self, from: data)
            return .serverError(statusCode, errorResponse?.error.message ?? "Server error")
        default:
            return .serverError(statusCode, "Unexpected status code")
        }
    }

    /// 成功レスポンスから LLMResponse を生成
    private func parseAgentSuccessResponse(data: Data) throws -> LLMResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let openAIResponse: OpenAIAgentResponseBody
        do {
            openAIResponse = try decoder.decode(OpenAIAgentResponseBody.self, from: data)
        } catch {
            throw LLMError.decodingFailed(error)
        }

        return convertToLLMResponse(openAIResponse)
    }

    /// OpenAI レスポンスから LLMResponse を生成
    private func convertToLLMResponse(_ response: OpenAIAgentResponseBody) -> LLMResponse {
        guard let choice = response.choices.first else {
            return LLMResponse(
                content: [],
                model: response.model,
                usage: TokenUsage(
                    inputTokens: response.usage.promptTokens,
                    outputTokens: response.usage.completionTokens
                ),
                stopReason: nil
            )
        }

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

        // 停止理由をマッピング
        let stopReason = mapStopReason(choice.finishReason)

        return LLMResponse(
            content: contentBlocks,
            model: response.model,
            usage: TokenUsage(
                inputTokens: response.usage.promptTokens,
                outputTokens: response.usage.completionTokens
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

// MARK: - OpenAI Agent Request/Response Types

/// OpenAI エージェントリクエストボディ
private struct OpenAIAgentRequestBody: Encodable {
    let model: String
    let messages: [OpenAIAgentMessage]
    let maxCompletionTokens: Int
    let temperature: Double?
    let tools: [OpenAIAgentToolDef]?
    let toolChoice: OpenAIAgentToolChoice?
    let responseFormat: OpenAIAgentResponseFormat?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, tools
        case maxCompletionTokens = "max_completion_tokens"
        case toolChoice = "tool_choice"
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
        if let tools = tools {
            try container.encode(tools, forKey: .tools)
        }
        if let toolChoice = toolChoice {
            try container.encode(toolChoice, forKey: .toolChoice)
        }
        if let responseFormat = responseFormat {
            try container.encode(responseFormat, forKey: .responseFormat)
        }
    }
}

/// OpenAI ツール定義
private struct OpenAIAgentToolDef: Encodable {
    let type: String
    let function: OpenAIAgentFunctionDef

    init(dict: [String: Any]) {
        self.type = dict["type"] as? String ?? "function"
        if let funcDict = dict["function"] as? [String: Any] {
            self.function = OpenAIAgentFunctionDef(dict: funcDict)
        } else {
            self.function = OpenAIAgentFunctionDef(dict: [:])
        }
    }
}

/// OpenAI 関数定義
private struct OpenAIAgentFunctionDef: Encodable {
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
        let paramsData = try JSONSerialization.data(withJSONObject: parameters)
        let paramsJSON = try JSONDecoder().decode(AgentOpenAIJSONValue.self, from: paramsData)
        try container.encode(paramsJSON, forKey: .parameters)
    }
}

/// OpenAI ツール選択
private enum OpenAIAgentToolChoice: Encodable {
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

/// OpenAI レスポンスフォーマット設定
private struct OpenAIAgentResponseFormat: Encodable {
    let type: String
    let jsonSchema: OpenAIAgentJSONSchemaWrapper

    enum CodingKeys: String, CodingKey {
        case type
        case jsonSchema = "json_schema"
    }
}

/// JSON Schema ラッパー
private struct OpenAIAgentJSONSchemaWrapper: Encodable {
    let name: String
    let strict: Bool
    let schema: JSONSchema
}

/// OpenAI メッセージ
private struct OpenAIAgentMessage: Encodable {
    let role: String
    let content: String?
    let toolCallId: String?
    let toolCalls: [OpenAIAgentMessageToolCall]?

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCallId = "tool_call_id"
        case toolCalls = "tool_calls"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)

        if let content = content {
            try container.encode(content, forKey: .content)
        }

        if let toolCallId = toolCallId {
            try container.encode(toolCallId, forKey: .toolCallId)
        }

        if let toolCalls = toolCalls {
            try container.encode(toolCalls, forKey: .toolCalls)
        }
    }
}

/// OpenAI メッセージ内のツール呼び出し
private struct OpenAIAgentMessageToolCall: Encodable {
    let id: String
    let type: String
    let function: OpenAIAgentMessageFunction
}

/// OpenAI メッセージ内のツール呼び出し関数
private struct OpenAIAgentMessageFunction: Encodable {
    let name: String
    let arguments: String
}

/// JSON 値の汎用エンコード/デコード用
private enum AgentOpenAIJSONValue: Codable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AgentOpenAIJSONValue])
    case object([String: AgentOpenAIJSONValue])

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
        } else if let array = try? container.decode([AgentOpenAIJSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: AgentOpenAIJSONValue].self) {
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

/// OpenAI エージェントレスポンスボディ
private struct OpenAIAgentResponseBody: Decodable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAIAgentChoice]
    let usage: OpenAIAgentUsage
}

/// OpenAI 選択肢
private struct OpenAIAgentChoice: Decodable {
    let index: Int
    let message: OpenAIAgentResponseMessage
    let finishReason: String?
}

/// OpenAI レスポンスメッセージ
private struct OpenAIAgentResponseMessage: Decodable {
    let role: String
    let content: String?
    let toolCalls: [OpenAIAgentResponseToolCall]?
}

/// OpenAI ツール呼び出し
private struct OpenAIAgentResponseToolCall: Decodable {
    let id: String
    let type: String
    let function: OpenAIAgentResponseFunction
}

/// OpenAI ツール呼び出し関数
private struct OpenAIAgentResponseFunction: Decodable {
    let name: String
    let arguments: String
}

/// OpenAI 使用量
private struct OpenAIAgentUsage: Decodable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}

/// OpenAI エラーレスポンス
private struct OpenAIAgentErrorResponse: Decodable {
    let error: OpenAIAgentError
}

/// OpenAI エラー詳細
private struct OpenAIAgentError: Decodable {
    let message: String
    let type: String
    let param: String?
    let code: String?
}
