import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - AnthropicClient Streaming Extension

extension AnthropicClient {

    /// Anthropic Messages API をストリーミングモードで呼び出し、テキストチャンクを返す
    ///
    /// `stream: true` で API を呼び出し、Server-Sent Events を解析して
    /// `content_block_delta` イベントのテキスト部分のみを順次返します。
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// let client = AnthropicClient(apiKey: "sk-ant-...")
    ///
    /// for try await chunk in client.streamText(
    ///     input: "日本の四季について教えてください",
    ///     model: .haiku,
    ///     systemPrompt: "簡潔に答えてください"
    /// ) {
    ///     print(chunk, terminator: "")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - input: 入力テキストまたは LLMInput
    ///   - model: 使用する Claude モデル
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション、デフォルト: 4096）
    /// - Returns: テキストチャンクの AsyncThrowingStream
    public func streamText(
        input: LLMInput,
        model: ClaudeModel,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) -> AsyncThrowingStream<String, Error> {
        streamText(
            messages: [input.toLLMMessage()],
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    /// メッセージ配列を使ったストリーミングテキスト生成
    ///
    /// 会話履歴を含むマルチターンの入力に対してストリーミングで応答を生成します。
    ///
    /// - Parameters:
    ///   - messages: LLMMessage の配列
    ///   - model: 使用する Claude モデル
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション、デフォルト: 4096）
    /// - Returns: テキストチャンクの AsyncThrowingStream
    public func streamText(
        messages: [LLMMessage],
        model: ClaudeModel,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // HTTP リクエストを構築
                    let request = try buildStreamingRequest(
                        messages: messages,
                        model: model,
                        systemPrompt: systemPrompt,
                        temperature: temperature,
                        maxTokens: maxTokens
                    )

                    // ストリーミングレスポンスを取得
                    var sseParser = SSELineParser()
                    var lineBuffer = DataLineBuffer()

                    for try await chunk in HTTPStreamingClient.stream(
                        request: request,
                        session: session
                    ) {
                        // Data チャンクを行に分割
                        let lines = lineBuffer.append(chunk)
                        for line in lines {
                            // SSE イベントをパース
                            if let event = sseParser.parseLine(line) {
                                // テキストデルタを抽出して yield
                                if let text = extractTextDelta(from: event) {
                                    continuation.yield(text)
                                }
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Private Helpers

    /// ストリーミング用の HTTP リクエストを構築
    private func buildStreamingRequest(
        messages: [LLMMessage],
        model: ClaudeModel,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) throws -> URLRequest {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // メッセージを Anthropic 形式に変換
        let anthropicMessages = messages.map { message -> [String: Any] in
            let role = message.role == .user ? "user" : "assistant"
            let textContents = message.contents.compactMap { content -> String? in
                if case .text(let text) = content { return text }
                return nil
            }
            let text = textContents.joined(separator: "\n")
            return ["role": role, "content": text]
        }

        var body: [String: Any] = [
            "model": model.id,
            "max_tokens": maxTokens ?? 4096,
            "stream": true,
            "messages": anthropicMessages
        ]

        if let systemPrompt = systemPrompt {
            body["system"] = systemPrompt
        }

        if let temperature = temperature {
            body["temperature"] = temperature
        }

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlRequest
    }

    /// SSE イベントから content_block_delta のテキストを抽出
    private func extractTextDelta(from event: SSEParsedEvent) -> String? {
        guard let data = event.data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return nil
        }

        switch type {
        case "content_block_delta":
            guard let delta = json["delta"] as? [String: Any],
                  let text = delta["text"] as? String else {
                return nil
            }
            return text
        default:
            return nil
        }
    }
}
