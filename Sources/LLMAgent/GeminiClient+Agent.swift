import Foundation
import LLMClient
import LLMTool
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - GeminiClient + AgentCapableClient

extension GeminiClient: AgentCapableClient {
    /// エージェントステップを実行
    ///
    /// Google Gemini API を使用してエージェントステップを実行します。
    /// ツールコールと構造化出力の両方をサポートします。
    public func executeAgentStep(
        messages: [LLMMessage],
        model: GeminiModel,
        systemPrompt: Prompt?,
        tools: ToolSet,
        toolChoice: ToolChoice?,
        responseSchema: JSONSchema?
    ) async throws -> LLMResponse {
        // エンドポイントを構築
        let endpoint = URL(string: "\(baseURL)/\(model.id):generateContent?key=\(apiKey)")!

        // HTTPリクエストを構築
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

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

        // リクエストを送信
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidRequest("Invalid response type")
        }

        // レスポンスを処理
        return try handleAgentResponse(data: data, httpResponse: httpResponse, model: model.id)
    }

    // MARK: - Private Constants

    /// デフォルトの最大トークン数
    private static let defaultMaxTokens = 4096

    // MARK: - Private Helpers

    /// エージェントリクエストボディを構築
    private func buildAgentRequestBody(
        model: GeminiModel,
        messages: [LLMMessage],
        systemPrompt: Prompt?,
        tools: ToolSet,
        toolChoice: ToolChoice?,
        responseSchema: JSONSchema?
    ) -> GeminiAgentRequestBody {
        // コンテンツを構築
        var contents: [GeminiAgentContent] = []

        for message in messages {
            contents.append(contentsOf: convertToGeminiContent(message))
        }

        // システムインストラクション
        var systemInstruction: GeminiAgentContent?
        if let prompt = systemPrompt {
            systemInstruction = GeminiAgentContent(
                role: "user",
                parts: [GeminiAgentPart(text: prompt.render())]
            )
        }

        // 生成設定
        var generationConfig = GeminiAgentGenerationConfig(
            maxOutputTokens: Self.defaultMaxTokens,
            temperature: nil
        )

        // 構造化出力の設定
        if let schema = responseSchema {
            let adapter = GeminiSchemaAdapter()
            generationConfig.responseMimeType = "application/json"
            generationConfig.responseSchema = adapter.adapt(schema)
        }

        // ツール設定（空の場合は nil）
        let geminiTools: [GeminiAgentToolDef]?
        let toolConfig: GeminiAgentToolConfig?

        if !tools.isEmpty {
            let functionDeclarations = tools.toGeminiFormat().map { GeminiAgentFunctionDeclaration(dict: $0) }
            geminiTools = [GeminiAgentToolDef(functionDeclarations: functionDeclarations)]
            toolConfig = toolChoice.map { mapToolChoice($0, tools: tools) }
        } else {
            geminiTools = nil
            toolConfig = nil
        }

        return GeminiAgentRequestBody(
            contents: contents,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            tools: geminiTools,
            toolConfig: toolConfig
        )
    }

    /// LLMMessage を Gemini コンテンツ形式に変換
    private func convertToGeminiContent(_ message: LLMMessage) -> [GeminiAgentContent] {
        let role = message.role == .user ? "user" : "model"
        var parts: [GeminiAgentPart] = []
        var toolResultParts: [GeminiAgentPart] = []

        for content in message.contents {
            switch content {
            case .text(let text):
                parts.append(GeminiAgentPart(text: text))

            case .toolUse(_, let name, let input):
                // ツール呼び出し（モデルからの応答）
                let args: [String: Any]?
                if let argsDict = try? JSONSerialization.jsonObject(with: input) as? [String: Any] {
                    args = argsDict
                } else {
                    args = nil
                }
                let functionCall = GeminiAgentFunctionCall(name: name, args: args)
                parts.append(GeminiAgentPart(functionCall: functionCall))

            case .toolResult(_, let name, let resultContent, _):
                // ツール結果（ユーザーからの応答）
                let responseDict: [String: Any] = ["result": resultContent]
                let functionResponse = GeminiAgentFunctionResponse(name: name, response: responseDict)
                toolResultParts.append(GeminiAgentPart(functionResponse: functionResponse))
            }
        }

        var contents: [GeminiAgentContent] = []

        // 通常のパーツ（テキストとツール呼び出し）
        if !parts.isEmpty {
            contents.append(GeminiAgentContent(role: role, parts: parts))
        }

        // ツール結果は常にuserロールで送信
        if !toolResultParts.isEmpty {
            contents.append(GeminiAgentContent(role: "user", parts: toolResultParts))
        }

        return contents
    }

    /// ToolChoice を Gemini 形式に変換
    private func mapToolChoice(_ choice: ToolChoice, tools: ToolSet) -> GeminiAgentToolConfig {
        let config: GeminiAgentFunctionCallingConfig
        switch choice {
        case .auto:
            config = GeminiAgentFunctionCallingConfig(mode: "AUTO", allowedFunctionNames: nil)
        case .none:
            config = GeminiAgentFunctionCallingConfig(mode: "NONE", allowedFunctionNames: nil)
        case .required:
            config = GeminiAgentFunctionCallingConfig(mode: "ANY", allowedFunctionNames: nil)
        case .tool(let name):
            config = GeminiAgentFunctionCallingConfig(mode: "ANY", allowedFunctionNames: [name])
        }
        return GeminiAgentToolConfig(functionCallingConfig: config)
    }

    /// レスポンスを処理
    private func handleAgentResponse(data: Data, httpResponse: HTTPURLResponse, model: String) throws -> LLMResponse {
        // エラーステータスコードの処理
        switch httpResponse.statusCode {
        case 200:
            break
        case 401, 403:
            throw LLMError.unauthorized
        case 429:
            throw LLMError.rateLimitExceeded
        case 400:
            let errorResponse = try? JSONDecoder().decode(GeminiAgentErrorResponse.self, from: data)
            throw LLMError.invalidRequest(errorResponse?.error.message ?? "Bad request")
        case 404:
            let errorResponse = try? JSONDecoder().decode(GeminiAgentErrorResponse.self, from: data)
            throw LLMError.modelNotFound(errorResponse?.error.message ?? "Model not found")
        case 500...599:
            let errorResponse = try? JSONDecoder().decode(GeminiAgentErrorResponse.self, from: data)
            throw LLMError.serverError(httpResponse.statusCode, errorResponse?.error.message ?? "Server error")
        default:
            throw LLMError.serverError(httpResponse.statusCode, "Unexpected status code")
        }

        // 成功レスポンスをデコード
        let decoder = JSONDecoder()

        let geminiResponse: GeminiAgentResponseBody
        do {
            geminiResponse = try decoder.decode(GeminiAgentResponseBody.self, from: data)
        } catch {
            throw LLMError.decodingFailed(error)
        }

        // LLMResponse に変換
        return convertToLLMResponse(geminiResponse, model: model)
    }

    /// Gemini レスポンスから LLMResponse を生成
    private func convertToLLMResponse(_ response: GeminiAgentResponseBody, model: String) -> LLMResponse {
        // 最初の候補を取得
        guard let candidate = response.candidates?.first,
              let content = candidate.content else {
            let usage: TokenUsage
            if let usageMetadata = response.usageMetadata {
                usage = TokenUsage(
                    inputTokens: usageMetadata.promptTokenCount ?? 0,
                    outputTokens: usageMetadata.candidatesTokenCount ?? 0
                )
            } else {
                usage = TokenUsage(inputTokens: 0, outputTokens: 0)
            }
            return LLMResponse(
                content: [],
                model: model,
                usage: usage,
                stopReason: nil
            )
        }

        var contentBlocks: [LLMResponse.ContentBlock] = []

        // パーツを処理
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

        // 停止理由をマッピング
        let stopReason = mapStopReason(candidate.finishReason)

        // 使用量を取得
        let usage: TokenUsage
        if let usageMetadata = response.usageMetadata {
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
            return nil
        default:
            return nil
        }
    }
}

// MARK: - Gemini Agent Request/Response Types

/// Gemini エージェントリクエストボディ
private struct GeminiAgentRequestBody: Encodable {
    let contents: [GeminiAgentContent]
    let systemInstruction: GeminiAgentContent?
    let generationConfig: GeminiAgentGenerationConfig
    let tools: [GeminiAgentToolDef]?
    let toolConfig: GeminiAgentToolConfig?
}

/// Gemini ツール定義
private struct GeminiAgentToolDef: Encodable {
    let functionDeclarations: [GeminiAgentFunctionDeclaration]
}

/// Gemini 関数宣言
private struct GeminiAgentFunctionDeclaration: Encodable {
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
        let paramsData = try JSONSerialization.data(withJSONObject: parameters)
        let paramsJSON = try JSONDecoder().decode(AgentGeminiJSONValue.self, from: paramsData)
        try container.encode(paramsJSON, forKey: .parameters)
    }
}

/// Gemini ツール設定
private struct GeminiAgentToolConfig: Encodable {
    let functionCallingConfig: GeminiAgentFunctionCallingConfig
}

/// Gemini 関数呼び出し設定
private struct GeminiAgentFunctionCallingConfig: Encodable {
    let mode: String
    let allowedFunctionNames: [String]?
}

/// Gemini 生成設定
private struct GeminiAgentGenerationConfig: Encodable {
    var maxOutputTokens: Int
    var temperature: Double?
    var responseMimeType: String?
    var responseSchema: JSONSchema?
}

/// Gemini コンテンツ
private struct GeminiAgentContent: Codable {
    let role: String
    let parts: [GeminiAgentPart]
}

/// Gemini パーツ
private struct GeminiAgentPart: Codable {
    let text: String?
    let functionCall: GeminiAgentFunctionCall?
    let functionResponse: GeminiAgentFunctionResponse?

    init(text: String) {
        self.text = text
        self.functionCall = nil
        self.functionResponse = nil
    }

    init(functionCall: GeminiAgentFunctionCall) {
        self.text = nil
        self.functionCall = functionCall
        self.functionResponse = nil
    }

    init(functionResponse: GeminiAgentFunctionResponse) {
        self.text = nil
        self.functionCall = nil
        self.functionResponse = functionResponse
    }
}

/// Gemini 関数呼び出し
private struct GeminiAgentFunctionCall: Codable {
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
        if let argsJSON = try? container.decodeIfPresent(AgentGeminiAnyCodable.self, forKey: .args) {
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
            let argsJSON = try JSONDecoder().decode(AgentGeminiJSONValue.self, from: argsData)
            try container.encode(argsJSON, forKey: .args)
        }
    }
}

/// Gemini 関数レスポンス（ツール実行結果）
private struct GeminiAgentFunctionResponse: Codable {
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
        if let responseJSON = try? container.decode(AgentGeminiAnyCodable.self, forKey: .response) {
            response = responseJSON.value as? [String: Any] ?? [:]
        } else {
            response = [:]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        let responseData = try JSONSerialization.data(withJSONObject: response)
        let responseJSON = try JSONDecoder().decode(AgentGeminiJSONValue.self, from: responseData)
        try container.encode(responseJSON, forKey: .response)
    }
}

/// JSON 値の汎用エンコード/デコード用
private enum AgentGeminiJSONValue: Codable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AgentGeminiJSONValue])
    case object([String: AgentGeminiJSONValue])

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
        } else if let array = try? container.decode([AgentGeminiJSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: AgentGeminiJSONValue].self) {
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

/// 任意の JSON 値をデコードするためのラッパー
private struct AgentGeminiAnyCodable: Decodable {
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
        } else if let array = try? container.decode([AgentGeminiAnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AgentGeminiAnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }
}

/// Gemini エージェントレスポンスボディ
private struct GeminiAgentResponseBody: Decodable {
    let candidates: [GeminiAgentCandidate]?
    let promptFeedback: GeminiAgentPromptFeedback?
    let usageMetadata: GeminiAgentUsageMetadata?
}

/// Gemini 候補
private struct GeminiAgentCandidate: Decodable {
    let content: GeminiAgentContent?
    let finishReason: String?
    let safetyRatings: [GeminiAgentSafetyRating]?
}

/// Gemini プロンプトフィードバック
private struct GeminiAgentPromptFeedback: Decodable {
    let blockReason: String?
    let safetyRatings: [GeminiAgentSafetyRating]?
}

/// Gemini 安全性評価
private struct GeminiAgentSafetyRating: Decodable {
    let category: String
    let probability: String
}

/// Gemini 使用量メタデータ
private struct GeminiAgentUsageMetadata: Decodable {
    let promptTokenCount: Int?
    let candidatesTokenCount: Int?
    let totalTokenCount: Int?
}

/// Gemini エラーレスポンス
private struct GeminiAgentErrorResponse: Decodable {
    let error: GeminiAgentError
}

/// Gemini エラー詳細
private struct GeminiAgentError: Decodable {
    let code: Int
    let message: String
    let status: String
}
