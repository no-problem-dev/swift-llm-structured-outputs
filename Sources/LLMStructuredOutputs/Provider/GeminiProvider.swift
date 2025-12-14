import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - GeminiProvider

/// Google Gemini API プロバイダー（内部実装）
///
/// このプロバイダーは `GeminiClient` 内部で使用されます。
/// 直接使用する場合は `GeminiClient` を使用してください。
internal struct GeminiProvider: LLMProvider {
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

    public func send(_ request: LLMRequest) async throws -> LLMResponse {
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

        // レスポンスを処理
        return try handleResponse(data: data, response: response, model: request.model.id)
    }

    // MARK: - Private Helpers

    /// リクエストボディを構築
    private func buildRequestBody(from request: LLMRequest) throws -> GeminiRequestBody {
        // コンテンツを構築
        var contents: [GeminiContent] = []

        for message in request.messages {
            contents.append(GeminiContent(
                role: message.role == .user ? "user" : "model",
                parts: [GeminiPart(text: message.content)]
            ))
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

        return GeminiRequestBody(
            contents: contents,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig
        )
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
    private func handleResponse(data: Data, response: URLResponse, model: String) throws -> LLMResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidRequest("Invalid response type")
        }

        // エラーステータスコードの処理
        switch httpResponse.statusCode {
        case 200:
            break
        case 401, 403:
            throw LLMError.unauthorized
        case 429:
            throw LLMError.rateLimitExceeded
        case 400:
            let errorResponse = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data)
            throw LLMError.invalidRequest(errorResponse?.error.message ?? "Bad request")
        case 404:
            let errorResponse = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data)
            throw LLMError.modelNotFound(errorResponse?.error.message ?? "Model not found")
        case 500...599:
            let errorResponse = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data)
            throw LLMError.serverError(httpResponse.statusCode, errorResponse?.error.message ?? "Server error")
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

        // コンテンツを取得
        guard let content = candidate.content,
              let text = content.parts.first?.text else {
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
            content: [.text(text)],
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
}

// MARK: - Request/Response Types

/// Gemini API リクエストボディ
private struct GeminiRequestBody: Encodable {
    let contents: [GeminiContent]
    let systemInstruction: GeminiContent?
    let generationConfig: GeminiGenerationConfig
}

/// Gemini コンテンツ
private struct GeminiContent: Codable {
    let role: String
    let parts: [GeminiPart]
}

/// Gemini パーツ
private struct GeminiPart: Codable {
    let text: String
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
