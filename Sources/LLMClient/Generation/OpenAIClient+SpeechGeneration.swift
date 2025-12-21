// OpenAIClient+SpeechGeneration.swift
// swift-llm-structured-outputs
//
// OpenAI クライアントの音声生成（TTS）機能拡張

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - OpenAIClient + SpeechGenerationCapable

extension OpenAIClient: SpeechGenerationCapable {
    public typealias SpeechModel = OpenAITTSModel
    public typealias Voice = OpenAIVoice

    /// テキストから音声を生成
    ///
    /// - Parameters:
    ///   - text: 音声化するテキスト（最大 4096 文字）
    ///   - model: 使用する TTS モデル
    ///   - voice: 使用する声
    ///   - speed: 再生速度（0.25〜4.0、デフォルト: 1.0）
    ///   - format: 出力フォーマット（デフォルト: mp3）
    /// - Returns: 生成された音声
    public func generateSpeech(
        text: String,
        model: OpenAITTSModel,
        voice: OpenAIVoice,
        speed: Double?,
        format: AudioOutputFormat?
    ) async throws -> GeneratedAudio {
        // バリデーション
        if text.isEmpty {
            throw SpeechGenerationError.emptyText
        }

        if text.count > 4096 {
            throw SpeechGenerationError.textTooLong(length: text.count, maximum: 4096)
        }

        let actualSpeed = speed ?? 1.0
        if actualSpeed < 0.25 || actualSpeed > 4.0 {
            throw SpeechGenerationError.invalidSpeed(actualSpeed)
        }

        let actualFormat = format ?? .mp3
        if !model.supportedFormats.contains(actualFormat) {
            throw SpeechGenerationError.unsupportedFormat(actualFormat, model: model.displayName)
        }

        // リクエスト作成
        let request = OpenAITTSRequest(
            model: model.id,
            input: text,
            voice: voice.id,
            responseFormat: actualFormat.fileExtension,
            speed: actualSpeed
        )

        // API 呼び出し
        let data = try await sendTTSRequest(request)

        return GeneratedAudio(
            data: data,
            format: actualFormat,
            transcript: text
        )
    }

    // MARK: - Private Helpers

    private func sendTTSRequest(_ request: OpenAITTSRequest) async throws -> Data {
        // endpoint は "https://api.openai.com/v1/chat/completions" のような形式
        // /v1 まで戻って audio/speech を追加する
        let ttsEndpoint = endpoint
            .deletingLastPathComponent()  // /v1/chat
            .deletingLastPathComponent()  // /v1
            .appendingPathComponent("audio/speech")

        var urlRequest = URLRequest(url: ttsEndpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if let org = organization {
            urlRequest.setValue(org, forHTTPHeaderField: "OpenAI-Organization")
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode != 200 {
            throw try parseTTSError(from: data, statusCode: httpResponse.statusCode)
        }

        return data
    }

    private func parseTTSError(from data: Data, statusCode: Int) throws -> LLMError {
        struct ErrorResponse: Decodable {
            struct Error: Decodable {
                let message: String
                let type: String?
            }
            let error: Error
        }

        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            let message = errorResponse.error.message

            switch statusCode {
            case 401:
                return .unauthorized
            case 429:
                return .rateLimitExceeded
            case 400:
                return .invalidRequest(message)
            default:
                return .serverError(statusCode, message)
            }
        }

        return .serverError(statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
    }
}

// MARK: - Request Types

private struct OpenAITTSRequest: Encodable {
    let model: String
    let input: String
    let voice: String
    let responseFormat: String
    let speed: Double
}
