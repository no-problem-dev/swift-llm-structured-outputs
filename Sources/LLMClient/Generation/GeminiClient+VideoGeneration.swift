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
        input: LLMInput,
        model: GeminiVideoModel,
        duration: Int?,
        aspectRatio: VideoAspectRatio?,
        resolution: VideoResolution?
    ) async throws -> VideoGenerationJob {
        // プロンプトテキストを取得
        let prompt = input.prompt.render()
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
            durationSeconds: actualDuration,
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
        let operationResponse: VeoOperationResponse
        do {
            operationResponse = try decoder.decode(VeoOperationResponse.self, from: data)
        } catch {
            // デコード失敗時は生のJSONを確認
            let rawJSON = String(data: data, encoding: .utf8) ?? "Unable to decode"
            throw LLMError.invalidRequest("Failed to decode response: \(error.localizedDescription). Raw: \(rawJSON.prefix(500))")
        }

        let status: VideoGenerationStatus
        var videoURL: URL?
        var errorMessage: String?

        if operationResponse.done == true {
            if let error = operationResponse.error {
                status = .failed
                errorMessage = error.message
            } else if let uri = operationResponse.getVideoURL() {
                status = .completed
                videoURL = URL(string: uri)
            } else if let base64 = operationResponse.getVideoBase64() {
                // Base64 データがある場合は data URL として扱う
                status = .completed
                videoURL = URL(string: "data:video/mp4;base64,\(base64)")
            } else {
                status = .failed
                // デバッグ用にレスポンス情報を含める
                let rawJSON = String(data: data, encoding: .utf8) ?? "Unable to decode"
                errorMessage = "No video generated. Response: \(rawJSON.prefix(1000))"
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

        let videoData: Data
        let urlString = videoURL.absoluteString

        // URI の形式によって処理を分岐
        if urlString.contains(":download") || urlString.contains("alt=media") {
            // 既にダウンロード URL の場合は直接ダウンロード
            var downloadRequest = URLRequest(url: videoURL)
            downloadRequest.httpMethod = "GET"
            downloadRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            let (data, response) = try await session.data(for: downloadRequest)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw VideoGenerationError.generationFailed("Failed to download video (status: \(statusCode))")
            }
            videoData = data
        } else if urlString.hasPrefix("gs://") || urlString.contains("files/") {
            // Gemini Files API 経由でダウンロード（ファイル参照の場合）
            videoData = try await downloadViaFilesAPI(uri: urlString)
        } else if urlString.hasPrefix("data:") {
            // Base64 data URL
            if let base64Start = urlString.range(of: "base64,"),
               let data = Data(base64Encoded: String(urlString[base64Start.upperBound...])) {
                videoData = data
            } else {
                throw VideoGenerationError.generationFailed("Invalid base64 data URL")
            }
        } else {
            // 通常の HTTP(S) URL
            let (data, _) = try await session.data(from: videoURL)
            videoData = data
        }

        return GeneratedVideo(
            data: videoData,
            format: .mp4,
            remoteURL: videoURL,
            duration: job.configuration?.duration.map { TimeInterval($0) },
            resolution: job.configuration?.resolution,
            jobId: job.id,
            prompt: job.prompt
        )
    }

    /// Gemini Files API 経由で動画をダウンロード
    private func downloadViaFilesAPI(uri: String) async throws -> Data {
        // URI から file name を抽出
        // 形式: "files/abc123" または "gs://bucket/path/file.mp4" または完全な URL
        let fileName: String

        if uri.hasPrefix("https://generativelanguage.googleapis.com/") {
            // 完全な API URL の場合、files/ 以降を抽出
            if let range = uri.range(of: "files/") {
                fileName = String(uri[range.lowerBound...])
            } else {
                throw VideoGenerationError.generationFailed("Cannot extract file name from URL: \(uri)")
            }
        } else if uri.hasPrefix("gs://") {
            // GCS URI の場合
            throw VideoGenerationError.generationFailed("GCS URI direct download not supported: \(uri)")
        } else if uri.hasPrefix("files/") {
            // files/xxx 形式
            fileName = uri
        } else if let range = uri.range(of: "files/") {
            // 何らかのパスに files/ が含まれている場合
            fileName = String(uri[range.lowerBound...])
        } else {
            throw VideoGenerationError.generationFailed("Unknown URI format: \(uri)")
        }

        // 1. files.get でファイル情報を取得（downloadUri を含む）
        let fileInfoURLString = "https://generativelanguage.googleapis.com/v1beta/\(fileName)"
        guard let fileInfoURL = URL(string: fileInfoURLString) else {
            throw VideoGenerationError.generationFailed("Invalid file info URL: \(fileInfoURLString)")
        }
        var fileInfoRequest = URLRequest(url: fileInfoURL)
        fileInfoRequest.httpMethod = "GET"
        fileInfoRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let (fileInfoData, fileInfoResponse) = try await session.data(for: fileInfoRequest)

        guard let httpResponse = fileInfoResponse as? HTTPURLResponse else {
            throw VideoGenerationError.generationFailed("Invalid response from files.get")
        }

        let rawFileInfoJSON = String(data: fileInfoData, encoding: .utf8) ?? "Unable to decode (binary data)"

        guard httpResponse.statusCode == 200 else {
            throw VideoGenerationError.generationFailed("Failed to get file info (status: \(httpResponse.statusCode)). Response: \(rawFileInfoJSON.prefix(500))"
            )
        }

        // downloadUri を抽出
        struct FileInfo: Decodable {
            let name: String?
            let displayName: String?
            let mimeType: String?
            let sizeBytes: String?
            let uri: String?
            let downloadUri: String?
        }

        let fileInfo: FileInfo
        do {
            fileInfo = try JSONDecoder().decode(FileInfo.self, from: fileInfoData)
        } catch {
            throw VideoGenerationError.generationFailed("Failed to decode file info: \(error.localizedDescription). Raw JSON: \(rawFileInfoJSON.prefix(1000))")
        }

        guard let downloadUri = fileInfo.downloadUri else {
            throw VideoGenerationError.generationFailed("No download URI in file info. Raw JSON: \(rawFileInfoJSON.prefix(1000))")
        }

        // 2. downloadUri から動画をダウンロード
        guard let downloadURL = URL(string: downloadUri) else {
            throw VideoGenerationError.generationFailed("Invalid download URI: \(downloadUri)")
        }

        var downloadRequest = URLRequest(url: downloadURL)
        downloadRequest.httpMethod = "GET"
        // downloadUri にはすでに認証情報が含まれている場合もあるが、念のためヘッダーも付ける
        downloadRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let (videoData, downloadResponse) = try await session.data(for: downloadRequest)

        guard let downloadHttpResponse = downloadResponse as? HTTPURLResponse,
              downloadHttpResponse.statusCode == 200 else {
            let statusCode = (downloadResponse as? HTTPURLResponse)?.statusCode ?? -1
            throw VideoGenerationError.generationFailed("Failed to download video (status: \(statusCode))")
        }

        return videoData
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
    let durationSeconds: Int
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
    let durationSeconds: Int
}

private struct VeoOperationResponse: Decodable {
    let name: String
    let done: Bool?
    let error: VeoError?
    let response: VeoResult?

    /// 動画 URL を取得（複数のレスポンス形式に対応）
    func getVideoURL() -> String? {
        guard let response = response else { return nil }

        // Format 1: Gemini API format - generateVideoResponse.generatedSamples[].video.uri
        if let sample = response.generateVideoResponse?.generatedSamples?.first,
           let uri = sample.video?.uri {
            return uri
        }

        // Format 2: Vertex AI format - videos[].gcsUri or bytesBase64Encoded
        if let video = response.videos?.first {
            if let gcsUri = video.gcsUri {
                return gcsUri
            }
        }

        // Format 3: Legacy format - generatedVideos[].uri
        if let video = response.generatedVideos?.first,
           let uri = video.uri {
            return uri
        }

        return nil
    }

    /// Base64 エンコードされた動画データを取得
    func getVideoBase64() -> String? {
        guard let response = response else { return nil }

        // Vertex AI format - videos[].bytesBase64Encoded
        if let video = response.videos?.first,
           let bytes = video.bytesBase64Encoded {
            return bytes
        }

        return nil
    }
}

private struct VeoError: Decodable {
    let code: Int
    let message: String
    let status: String?
}

private struct VeoResult: Decodable {
    // Gemini API format
    let generateVideoResponse: VeoGenerateVideoResponse?

    // Vertex AI format
    let videos: [VeoVideo]?

    // Legacy format
    let generatedVideos: [VeoGeneratedVideo]?
}

// Gemini API format structures
private struct VeoGenerateVideoResponse: Decodable {
    let generatedSamples: [VeoGeneratedSample]?
}

private struct VeoGeneratedSample: Decodable {
    let video: VeoVideoInfo?
}

private struct VeoVideoInfo: Decodable {
    let uri: String?
    let mimeType: String?
}

// Vertex AI format structures
private struct VeoVideo: Decodable {
    let gcsUri: String?
    let bytesBase64Encoded: String?
    let mimeType: String?
}

// Legacy format structures
private struct VeoGeneratedVideo: Decodable {
    let uri: String?
    let encoding: String?
}
