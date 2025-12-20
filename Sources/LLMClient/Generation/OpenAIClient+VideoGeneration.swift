// OpenAIClient+VideoGeneration.swift
// swift-llm-structured-outputs
//
// OpenAI クライアントの動画生成機能拡張（Sora 2）

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - OpenAIClient + VideoGenerationCapable

extension OpenAIClient: VideoGenerationCapable {
    public typealias VideoModel = OpenAIVideoModel

    /// 動画生成ジョブを開始
    ///
    /// Sora 2 API を使用して動画生成を開始します。
    /// 動画生成は非同期で処理されるため、ジョブ ID を返します。
    ///
    /// ## 使用例
    /// ```swift
    /// let client = OpenAIClient(apiKey: "sk-...")
    /// let job = try await client.startVideoGeneration(
    ///     prompt: "A cat playing piano on stage",
    ///     model: .sora2
    /// )
    /// ```
    public func startVideoGeneration(
        prompt: String,
        model: OpenAIVideoModel,
        duration: Int?,
        aspectRatio: VideoAspectRatio?,
        resolution: VideoResolution?
    ) async throws -> VideoGenerationJob {
        // バリデーション
        let actualDuration = duration ?? 4
        if !model.supportedDurations.contains(actualDuration) {
            throw VideoGenerationError.durationExceedsLimit(
                requested: actualDuration,
                maximum: model.maxDuration
            )
        }

        let actualAspectRatio = aspectRatio ?? .landscape16x9
        if !model.supportedAspectRatios.contains(actualAspectRatio) {
            throw VideoGenerationError.unsupportedAspectRatio(actualAspectRatio, model: model.displayName)
        }

        let actualResolution = resolution ?? model.defaultResolution
        if !model.supportedResolutions.contains(actualResolution) {
            throw VideoGenerationError.unsupportedResolution(actualResolution, model: model.displayName)
        }

        // サイズ文字列を生成（アスペクト比に応じて）
        let sizeString = soraSize(for: actualAspectRatio, resolution: actualResolution)

        // API 呼び出し
        let response = try await sendVideoCreationRequest(
            prompt: prompt,
            model: model,
            seconds: actualDuration,
            size: sizeString
        )

        // 設定を作成
        let configuration = VideoGenerationConfiguration(
            duration: actualDuration,
            resolution: actualResolution,
            frameRate: nil,
            aspectRatio: actualAspectRatio,
            format: .mp4
        )

        return VideoGenerationJob(
            id: response.id,
            status: mapStatus(response.status),
            prompt: prompt,
            configuration: configuration,
            createdAt: Date(timeIntervalSince1970: TimeInterval(response.createdAt))
        )
    }

    /// 動画生成ジョブのステータスを確認
    public func checkVideoStatus(_ job: VideoGenerationJob) async throws -> VideoGenerationJob {
        let endpoint = videoStatusEndpoint(videoId: job.id)

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode != 200 {
            throw try parseVideoError(from: data, statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let statusResponse = try decoder.decode(SoraVideoResponse.self, from: data)

        let status = mapStatus(statusResponse.status)
        var videoURL: URL?
        var errorMessage: String?

        if status == .completed {
            // 動画ダウンロード URL を取得
            videoURL = videoDownloadEndpoint(videoId: job.id)
        } else if status == .failed {
            errorMessage = statusResponse.error?.message ?? "Video generation failed"
        }

        return job.updated(
            status: status,
            videoURL: videoURL,
            errorMessage: errorMessage,
            progress: statusResponse.progress.map { Double($0) / 100.0 }
        )
    }

    /// 生成された動画を取得
    public func getGeneratedVideo(_ job: VideoGenerationJob) async throws -> GeneratedVideo {
        guard job.status == .completed else {
            throw VideoGenerationError.jobNotCompleted(status: job.status)
        }

        // 動画をダウンロード
        let endpoint = videoDownloadEndpoint(videoId: job.id)

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode != 200 {
            throw try parseVideoError(from: data, statusCode: httpResponse.statusCode)
        }

        return GeneratedVideo(
            data: data,
            format: .mp4,
            remoteURL: endpoint,
            duration: job.configuration?.duration.map { TimeInterval($0) },
            resolution: job.configuration?.resolution,
            jobId: job.id,
            prompt: job.prompt
        )
    }

    // MARK: - Private Helpers

    private func sendVideoCreationRequest(
        prompt: String,
        model: OpenAIVideoModel,
        seconds: Int,
        size: String
    ) async throws -> SoraVideoResponse {
        let endpoint = videoCreationEndpoint()

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // multipart/form-data を構築
        let boundary = UUID().uuidString
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // model
        body.appendMultipartField(name: "model", value: model.id, boundary: boundary)
        // prompt
        body.appendMultipartField(name: "prompt", value: prompt, boundary: boundary)
        // seconds
        body.appendMultipartField(name: "seconds", value: String(seconds), boundary: boundary)
        // size
        body.appendMultipartField(name: "size", value: size, boundary: boundary)

        // 終端
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        urlRequest.httpBody = body

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
            throw try parseVideoError(from: data, statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SoraVideoResponse.self, from: data)
    }

    private func videoCreationEndpoint() -> URL {
        URL(string: "https://api.openai.com/v1/videos")!
    }

    private func videoStatusEndpoint(videoId: String) -> URL {
        URL(string: "https://api.openai.com/v1/videos/\(videoId)")!
    }

    private func videoDownloadEndpoint(videoId: String) -> URL {
        URL(string: "https://api.openai.com/v1/videos/\(videoId)/content")!
    }

    private func soraSize(for aspectRatio: VideoAspectRatio, resolution: VideoResolution) -> String {
        // Sora 2 のサポートサイズ:
        // sora-2: 720x1280, 1280x720
        // sora-2-pro: 720x1280, 1280x720, 1024x1792, 1792x1024
        switch aspectRatio {
        case .landscape16x9:
            switch resolution {
            case .hd720p:
                return "1280x720"
            case .fhd1080p:
                return "1792x1024"
            default:
                return "1280x720"
            }
        case .portrait9x16:
            switch resolution {
            case .hd720p:
                return "720x1280"
            case .fhd1080p:
                return "1024x1792"
            default:
                return "720x1280"
            }
        default:
            // Sora は 16:9 と 9:16 のみサポート
            return "1280x720"
        }
    }

    private func mapStatus(_ status: String) -> VideoGenerationStatus {
        switch status.lowercased() {
        case "queued":
            return .queued
        case "in_progress", "processing":
            return .processing
        case "completed", "succeeded":
            return .completed
        case "failed":
            return .failed
        case "cancelled", "canceled":
            return .cancelled
        default:
            return .processing
        }
    }

    private func parseVideoError(from data: Data, statusCode: Int) throws -> LLMError {
        struct ErrorResponse: Decodable {
            struct Error: Decodable {
                let message: String
                let type: String?
                let code: String?
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
                if message.contains("safety") || message.contains("policy") || message.contains("copyright") {
                    throw VideoGenerationError.contentPolicyViolation(message)
                }
                return .invalidRequest(message)
            default:
                return .serverError(statusCode, message)
            }
        }

        return .serverError(statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
    }
}

// MARK: - Multipart Form Data Helper

private extension Data {
    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
}

// MARK: - Response Types

private struct SoraVideoResponse: Decodable {
    let id: String
    let object: String
    let createdAt: Int
    let status: String
    let model: String
    let progress: Int?
    let seconds: String?
    let size: String?
    let error: SoraError?

    enum CodingKeys: String, CodingKey {
        case id, object, status, model, progress, seconds, size, error
        case createdAt = "created_at"
    }
}

private struct SoraError: Decodable {
    let message: String
    let type: String?
    let code: String?
}
