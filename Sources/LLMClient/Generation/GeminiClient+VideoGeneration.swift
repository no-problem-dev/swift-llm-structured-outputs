// GeminiClient+VideoGeneration.swift
// swift-llm-structured-outputs
//
// Gemini クライアントの動画生成機能拡張（Veo）

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - GeminiClient + VideoGenerationCapable

extension GeminiClient: VideoGenerationCapable {
    public typealias VideoModel = GeminiVideoModel

    /// 動画生成ジョブを開始
    ///
    /// Veo API を使用して動画生成を開始します。
    /// 動画生成は非同期で処理されるため、ジョブ ID を返します。
    public func startVideoGeneration(
        prompt: String,
        model: GeminiVideoModel,
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

        let actualResolution = resolution ?? .hd720p
        if !model.supportedResolutions.contains(actualResolution) {
            throw VideoGenerationError.unsupportedResolution(actualResolution, model: model.displayName)
        }

        // 1080p は 8 秒の動画のみ
        if actualResolution == .fhd1080p && actualDuration != 8 {
            throw VideoGenerationError.unsupportedResolution(actualResolution, model: "\(model.displayName) (1080p requires 8 seconds)")
        }

        // リクエスト作成
        let request = VeoVideoRequest(
            prompt: prompt,
            aspectRatio: veoAspectRatioString(for: actualAspectRatio),
            resolution: veoResolutionString(for: actualResolution),
            durationSeconds: String(actualDuration),
            negativePrompt: nil
        )

        // API 呼び出し
        let response = try await sendVideoRequest(request, model: model)

        // 設定を作成
        let configuration = VideoGenerationConfiguration(
            duration: actualDuration,
            resolution: actualResolution,
            frameRate: nil,
            aspectRatio: actualAspectRatio,
            format: .mp4
        )

        return VideoGenerationJob(
            id: response.name,
            status: .queued,
            prompt: prompt,
            configuration: configuration,
            createdAt: Date()
        )
    }

    /// 動画生成ジョブのステータスを確認
    public func checkVideoStatus(_ job: VideoGenerationJob) async throws -> VideoGenerationJob {
        let endpoint = operationStatusEndpoint(operationName: job.id)

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "GET"
        // Veo API は x-goog-api-key ヘッダーで認証
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode != 200 {
            throw try parseError(from: data, statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let operationResponse = try decoder.decode(VeoOperationResponse.self, from: data)

        let status: VideoGenerationStatus
        var videoURL: URL?
        var errorMessage: String?

        if operationResponse.done == true {
            if let error = operationResponse.error {
                status = .failed
                errorMessage = error.message
            } else if let result = operationResponse.response,
                      let video = result.generatedVideos?.first,
                      let uri = video.uri {
                status = .completed
                videoURL = URL(string: uri)
            } else {
                status = .failed
                errorMessage = "No video generated"
            }
        } else {
            status = .processing
        }

        return job.updated(
            status: status,
            videoURL: videoURL,
            errorMessage: errorMessage,
            progress: status == .completed ? 1.0 : (status == .processing ? 0.5 : nil)
        )
    }

    /// 生成された動画を取得
    public func getGeneratedVideo(_ job: VideoGenerationJob) async throws -> GeneratedVideo {
        guard job.status == .completed else {
            throw VideoGenerationError.jobNotCompleted(status: job.status)
        }

        guard let videoURL = job.videoURL else {
            throw VideoGenerationError.generationFailed("No video URL available")
        }

        // 動画データをダウンロード
        let (data, _) = try await URLSession.shared.data(from: videoURL)

        return GeneratedVideo(
            data: data,
            format: .mp4,
            remoteURL: videoURL,
            duration: job.configuration?.duration.map { TimeInterval($0) },
            resolution: job.configuration?.resolution,
            jobId: job.id,
            prompt: job.prompt
        )
    }

    // MARK: - Private Helpers

    private func sendVideoRequest(
        _ request: VeoVideoRequest,
        model: GeminiVideoModel
    ) async throws -> VeoOperationResponse {
        let endpoint = videoGenerationEndpoint(for: model)

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Veo API は x-goog-api-key ヘッダーで認証
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let requestBody = VeoVideoRequestBody(
            instances: [VeoVideoInstance(prompt: request.prompt)],
            parameters: VeoVideoParameters(
                aspectRatio: request.aspectRatio,
                negativePrompt: request.negativePrompt,
                resolution: request.resolution,
                durationSeconds: request.durationSeconds
            )
        )

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode != 200 {
            throw try parseError(from: data, statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(VeoOperationResponse.self, from: data)
    }

    private func videoGenerationEndpoint(for model: GeminiVideoModel) -> URL {
        // Veo uses predictLongRunning endpoint
        let baseURLString = "https://generativelanguage.googleapis.com/v1beta/models/\(model.id):predictLongRunning"
        return URL(string: baseURLString)!
    }

    private func operationStatusEndpoint(operationName: String) -> URL {
        // Operations endpoint to check status
        let baseURLString = "https://generativelanguage.googleapis.com/v1beta/\(operationName)"
        return URL(string: baseURLString)!
    }

    private func veoAspectRatioString(for aspectRatio: VideoAspectRatio) -> String {
        switch aspectRatio {
        case .landscape16x9: return "16:9"
        case .portrait9x16: return "9:16"
        case .square1x1: return "1:1"
        case .standard4x3: return "4:3"
        case .cinematic21x9: return "21:9"
        }
    }

    private func veoResolutionString(for resolution: VideoResolution) -> String {
        switch resolution {
        case .sd480p: return "480p"
        case .hd720p: return "720p"
        case .fhd1080p: return "1080p"
        case .uhd4k: return "4k"
        }
    }

    private func parseError(from data: Data, statusCode: Int) throws -> LLMError {
        struct ErrorResponse: Decodable {
            struct Error: Decodable {
                let message: String
                let status: String?
            }
            let error: Error
        }

        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            let message = errorResponse.error.message

            switch statusCode {
            case 401, 403:
                return .unauthorized
            case 429:
                return .rateLimitExceeded
            case 400:
                if message.contains("safety") || message.contains("blocked") {
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

// MARK: - Request/Response Types

private struct VeoVideoRequest {
    let prompt: String
    let aspectRatio: String
    let resolution: String
    let durationSeconds: String
    let negativePrompt: String?
}

private struct VeoVideoRequestBody: Encodable {
    let instances: [VeoVideoInstance]
    let parameters: VeoVideoParameters
}

private struct VeoVideoInstance: Encodable {
    let prompt: String
}

private struct VeoVideoParameters: Encodable {
    let aspectRatio: String
    let negativePrompt: String?
    let resolution: String
    let durationSeconds: String
}

private struct VeoOperationResponse: Decodable {
    let name: String
    let done: Bool?
    let error: VeoError?
    let response: VeoResult?
}

private struct VeoError: Decodable {
    let code: Int
    let message: String
    let status: String?
}

private struct VeoResult: Decodable {
    let generatedVideos: [VeoGeneratedVideo]?
}

private struct VeoGeneratedVideo: Decodable {
    let uri: String?
    let encoding: String?
}
