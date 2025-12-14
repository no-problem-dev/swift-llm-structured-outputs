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
            convertToAnthropicMessage(message)
        }

        // 構造化出力の設定（Anthropic APIでサポートされていない制約を除去）
        var outputFormat: AnthropicOutputFormat?
        if let schema = request.responseSchema {
            outputFormat = AnthropicOutputFormat(
                type: "json_schema",
                schema: schema.sanitizedForAnthropic()
            )
        }

        // ツール設定
        let tools = request.tools?.toAnthropicFormat()
        let toolChoice = request.toolChoice.map { mapToolChoice($0) }

        return AnthropicRequestBody(
            model: request.model.id,
            messages: messages,
            system: request.systemPrompt,
            maxTokens: request.maxTokens ?? Self.defaultMaxTokens,
            temperature: request.temperature,
            outputFormat: outputFormat,
            tools: tools,
            toolChoice: toolChoice
        )
    }

    /// ToolChoice を Anthropic 形式に変換
    private func mapToolChoice(_ choice: ToolChoice) -> AnthropicToolChoice {
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

    /// LLMMessage を Anthropic メッセージ形式に変換
    private func convertToAnthropicMessage(_ message: LLMMessage) -> AnthropicMessage {
        let role = message.role == .user ? "user" : "assistant"

        // コンテンツブロックを変換
        var contentBlocks: [AnthropicMessageContent] = []

        for content in message.contents {
            switch content {
            case .text(let text):
                contentBlocks.append(.text(text))

            case .toolUse(let id, let name, let input):
                contentBlocks.append(.toolUse(id: id, name: name, input: input))

            case .toolResult(let toolCallId, _, let resultContent, let isError):
                // Anthropic APIではnameは不要（toolUseIdで関連付け）
                contentBlocks.append(.toolResult(toolUseId: toolCallId, content: resultContent, isError: isError))
            }
        }

        return AnthropicMessage(role: role, content: contentBlocks)
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
        let contentBlocks = try anthropicResponse.content.compactMap { block -> LLMResponse.ContentBlock? in
            switch block.type {
            case "text":
                return block.text.map { .text($0) }
            case "tool_use":
                guard let id = block.id, let name = block.name, let input = block.input else {
                    return nil
                }
                let inputData = try JSONSerialization.data(withJSONObject: input)
                return .toolUse(id: id, name: name, input: inputData)
            default:
                return nil
            }
        }

        // tool_use の場合は空でもOK
        guard !contentBlocks.isEmpty || stopReason == .toolUse else {
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
    let tools: [[String: Any]]?
    let toolChoice: AnthropicToolChoice?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case system
        case maxTokens = "max_tokens"
        case temperature
        case outputFormat = "output_format"
        case tools
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
        if let outputFormat = outputFormat {
            try container.encode(outputFormat, forKey: .outputFormat)
        }
        if let tools = tools {
            // tools を直接エンコード
            let toolDefs = tools.map { AnthropicToolDef(dict: $0) }
            try container.encode(toolDefs, forKey: .tools)
        }
        if let toolChoice = toolChoice {
            try container.encode(toolChoice, forKey: .toolChoice)
        }
    }
}

/// Anthropic ツール定義（エンコード用）
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
        case name
        case description
        case inputSchema = "input_schema"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        // inputSchema を JSON として手動エンコード
        let schemaData = try JSONSerialization.data(withJSONObject: inputSchema)
        let schemaJSON = try JSONDecoder().decode(JSONValue.self, from: schemaData)
        try container.encode(schemaJSON, forKey: .inputSchema)
    }
}

/// JSON 値の汎用エンコード用
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

/// Anthropic ツール選択
private enum AnthropicToolChoice: Encodable {
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
            // Anthropic では "none" は存在しないので auto と同等に
            try container.encode(["type": "auto"])
        case .tool(let name):
            try container.encode(["type": "tool", "name": name])
        }
    }
}

/// Anthropic メッセージ
private struct AnthropicMessage: Encodable {
    let role: String
    let content: [AnthropicMessageContent]

    enum CodingKeys: String, CodingKey {
        case role
        case content
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
    }
}

/// Anthropic メッセージコンテンツ
private enum AnthropicMessageContent: Encodable {
    /// テキストコンテンツ
    case text(String)

    /// ツール呼び出し（アシスタント）
    case toolUse(id: String, name: String, input: Data)

    /// ツール結果（ユーザー）
    case toolResult(toolUseId: String, content: String, isError: Bool)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .text(let text):
            try container.encode(["type": "text", "text": text])

        case .toolUse(let id, let name, let input):
            // input を辞書に変換
            let inputDict: [String: Any]
            if let dict = try? JSONSerialization.jsonObject(with: input) as? [String: Any] {
                inputDict = dict
            } else {
                inputDict = [:]
            }
            // JSONValue を使ってエンコード
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
    // tool_use 用フィールド
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
        // input は任意の JSON なので手動でデコード
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
