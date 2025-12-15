import Foundation
import LLMClient
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - OpenAIClient + ToolCapableClient

extension OpenAIClient: ToolCapableClient {
    /// ツール呼び出しを計画する（会話履歴付き）
    ///
    /// OpenAI GPT API を使用してツール呼び出しを計画します。
    public func planToolCalls(
        messages: [LLMMessage],
        model: GPTModel,
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
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        if let org = organization {
            urlRequest.setValue(org, forHTTPHeaderField: "OpenAI-Organization")
        }

        // リクエストボディを構築
        let body = buildToolRequestBody(
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

    /// デフォルトの最大トークン数
    private static let defaultMaxTokens = 4096

    // MARK: - Private Helpers

    /// ツールリクエストボディを構築
    private func buildToolRequestBody(
        model: GPTModel,
        messages: [LLMMessage],
        tools: ToolSet,
        toolChoice: ToolChoice?,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) -> OpenAIToolRequestBody {
        var openAIMessages: [OpenAIToolMessage] = []

        // システムプロンプト
        if let systemPrompt = systemPrompt {
            openAIMessages.append(OpenAIToolMessage(
                role: "system",
                content: systemPrompt,
                toolCallId: nil,
                toolCalls: nil
            ))
        }

        // ユーザー/アシスタントメッセージ
        for message in messages {
            openAIMessages.append(contentsOf: convertToOpenAIMessages(message))
        }

        let openAITools = tools.toOpenAIFormat().map { OpenAIToolDef(dict: $0) }
        let openAIToolChoice = toolChoice.map { mapToolChoice($0) }

        return OpenAIToolRequestBody(
            model: model.id,
            messages: openAIMessages,
            maxCompletionTokens: maxTokens ?? Self.defaultMaxTokens,
            temperature: temperature,
            tools: openAITools,
            toolChoice: openAIToolChoice
        )
    }

    /// LLMMessage を OpenAI メッセージ形式に変換
    private func convertToOpenAIMessages(_ message: LLMMessage) -> [OpenAIToolMessage] {
        var result: [OpenAIToolMessage] = []

        // ツール結果を持つ場合、各結果を個別の tool メッセージとして送信
        let toolResults = message.toolResults
        if !toolResults.isEmpty {
            for toolResult in toolResults {
                result.append(OpenAIToolMessage(
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
            let toolCalls = toolUses.map { toolUse -> OpenAIToolMessageToolCall in
                let argumentsString: String
                if let str = String(data: toolUse.input, encoding: .utf8) {
                    argumentsString = str
                } else {
                    argumentsString = "{}"
                }
                return OpenAIToolMessageToolCall(
                    id: toolUse.id,
                    type: "function",
                    function: OpenAIToolMessageFunction(
                        name: toolUse.name,
                        arguments: argumentsString
                    )
                )
            }
            result.append(OpenAIToolMessage(
                role: "assistant",
                content: message.content.isEmpty ? nil : message.content,
                toolCallId: nil,
                toolCalls: toolCalls
            ))
            return result
        }

        // 通常のテキストメッセージ
        let role = message.role == .user ? "user" : "assistant"
        result.append(OpenAIToolMessage(
            role: role,
            content: message.content,
            toolCallId: nil,
            toolCalls: nil
        ))
        return result
    }

    /// ToolChoice を OpenAI 形式に変換
    private func mapToolChoice(_ choice: ToolChoice) -> OpenAIToolChoiceValue {
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
            let errorResponse = try? JSONDecoder().decode(OpenAIToolErrorResponse.self, from: data)
            throw LLMError.invalidRequest(errorResponse?.error.message ?? "Bad request")
        case 404:
            let errorResponse = try? JSONDecoder().decode(OpenAIToolErrorResponse.self, from: data)
            throw LLMError.modelNotFound(errorResponse?.error.message ?? "Model not found")
        case 500...599:
            let errorResponse = try? JSONDecoder().decode(OpenAIToolErrorResponse.self, from: data)
            throw LLMError.serverError(httpResponse.statusCode, errorResponse?.error.message ?? "Server error")
        default:
            throw LLMError.serverError(httpResponse.statusCode, "Unexpected status code")
        }

        // 成功レスポンスをデコード
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let openAIResponse: OpenAIToolResponseBody
        do {
            openAIResponse = try decoder.decode(OpenAIToolResponseBody.self, from: data)
        } catch {
            throw LLMError.decodingFailed(error)
        }

        // ToolCallResponse に変換
        return parseToolCallResponse(openAIResponse)
    }

    /// OpenAI レスポンスから ToolCallResponse を生成
    private func parseToolCallResponse(_ response: OpenAIToolResponseBody) -> ToolCallResponse {
        var toolCalls: [ToolCall] = []
        var textContent: String?

        // 最初の choice を使用
        guard let choice = response.choices.first else {
            return ToolCallResponse(
                toolCalls: [],
                text: nil,
                usage: TokenUsage(
                    inputTokens: response.usage.promptTokens,
                    outputTokens: response.usage.completionTokens
                ),
                stopReason: nil,
                model: response.model
            )
        }

        // テキストコンテンツ
        textContent = choice.message.content

        // ツール呼び出し
        if let responseToolCalls = choice.message.toolCalls {
            for toolCall in responseToolCalls {
                if toolCall.type == "function",
                   let argumentsData = toolCall.function.arguments.data(using: .utf8) {
                    toolCalls.append(ToolCall(
                        id: toolCall.id,
                        name: toolCall.function.name,
                        arguments: argumentsData
                    ))
                }
            }
        }

        // 停止理由をマッピング
        let stopReason = mapStopReason(choice.finishReason)

        return ToolCallResponse(
            toolCalls: toolCalls,
            text: textContent,
            usage: TokenUsage(
                inputTokens: response.usage.promptTokens,
                outputTokens: response.usage.completionTokens
            ),
            stopReason: stopReason,
            model: response.model
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

// MARK: - OpenAI Tool Request/Response Types

/// OpenAI ツールリクエストボディ
private struct OpenAIToolRequestBody: Encodable {
    let model: String
    let messages: [OpenAIToolMessage]
    let maxCompletionTokens: Int
    let temperature: Double?
    let tools: [OpenAIToolDef]
    let toolChoice: OpenAIToolChoiceValue?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, tools
        case maxCompletionTokens = "max_completion_tokens"
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
        try container.encode(tools, forKey: .tools)
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
        let paramsJSON = try JSONDecoder().decode(OpenAIToolJSONValue.self, from: paramsData)
        try container.encode(paramsJSON, forKey: .parameters)
    }
}

/// OpenAI ツール選択値
private enum OpenAIToolChoiceValue: Encodable {
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

/// OpenAI メッセージ
private struct OpenAIToolMessage: Encodable {
    let role: String
    let content: String?
    let toolCallId: String?
    let toolCalls: [OpenAIToolMessageToolCall]?

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
private struct OpenAIToolMessageToolCall: Encodable {
    let id: String
    let type: String
    let function: OpenAIToolMessageFunction
}

/// OpenAI メッセージ内のツール呼び出し関数
private struct OpenAIToolMessageFunction: Encodable {
    let name: String
    let arguments: String
}

/// JSON 値の汎用エンコード/デコード用
private enum OpenAIToolJSONValue: Codable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([OpenAIToolJSONValue])
    case object([String: OpenAIToolJSONValue])

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
        } else if let array = try? container.decode([OpenAIToolJSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: OpenAIToolJSONValue].self) {
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

/// OpenAI ツールレスポンスボディ
private struct OpenAIToolResponseBody: Decodable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAIToolChoice]
    let usage: OpenAIToolUsage
}

/// OpenAI 選択肢
private struct OpenAIToolChoice: Decodable {
    let index: Int
    let message: OpenAIToolResponseMessage
    let finishReason: String?
}

/// OpenAI レスポンスメッセージ
private struct OpenAIToolResponseMessage: Decodable {
    let role: String
    let content: String?
    let toolCalls: [OpenAIToolResponseToolCall]?
}

/// OpenAI ツール呼び出し
private struct OpenAIToolResponseToolCall: Decodable {
    let id: String
    let type: String
    let function: OpenAIToolResponseFunction
}

/// OpenAI ツール呼び出し関数
private struct OpenAIToolResponseFunction: Decodable {
    let name: String
    let arguments: String
}

/// OpenAI 使用量
private struct OpenAIToolUsage: Decodable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}

/// OpenAI エラーレスポンス
private struct OpenAIToolErrorResponse: Decodable {
    let error: OpenAIToolError
}

/// OpenAI エラー詳細
private struct OpenAIToolError: Decodable {
    let message: String
    let type: String
    let param: String?
    let code: String?
}
