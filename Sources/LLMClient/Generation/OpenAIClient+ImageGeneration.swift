// OpenAIClient+ImageGeneration.swift
// swift-llm-structured-outputs
//
// OpenAI クライアントの画像生成機能拡張

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - OpenAIClient + ImageGenerationCapable

extension OpenAIClient: ImageGenerationCapable {
    public typealias ImageModel = OpenAIImageModel

    /// 画像を生成
    ///
    /// - Parameters:
    ///   - prompt: 画像を説明するプロンプト
    ///   - model: 使用する画像生成モデル
    ///   - size: 出力画像のサイズ
    ///   - quality: 画像品質
    ///   - format: 出力フォーマット
    ///   - n: 生成する画像の数
    /// - Returns: 生成された画像
    public func generateImage(
        prompt: String,
        model: OpenAIImageModel,
        size: ImageSize?,
        quality: ImageQuality?,
        format: ImageOutputFormat?,
        n: Int
    ) async throws -> GeneratedImage {
        let images = try await generateImages(
            prompt: prompt,
            model: model,
            size: size,
            quality: quality,
            format: format,
            n: 1
        )
        guard let image = images.first else {
            throw LLMError.emptyResponse
        }
        return image
    }

    /// 複数の画像を生成
    ///
    /// - Parameters:
    ///   - prompt: 画像を説明するプロンプト
    ///   - model: 使用する画像生成モデル
    ///   - size: 出力画像のサイズ
    ///   - quality: 画像品質
    ///   - format: 出力フォーマット
    ///   - n: 生成する画像の数
    /// - Returns: 生成された画像の配列
    public func generateImages(
        prompt: String,
        model: OpenAIImageModel,
        size: ImageSize?,
        quality: ImageQuality?,
        format: ImageOutputFormat?,
        n: Int
    ) async throws -> [GeneratedImage] {
        // バリデーション
        if n > model.maxImages {
            throw ImageGenerationError.exceedsMaxImages(requested: n, maximum: model.maxImages)
        }

        let actualSize = size ?? .square1024
        if !model.supportedSizes.contains(actualSize) {
            throw ImageGenerationError.unsupportedSize(actualSize, model: model.displayName)
        }

        let actualFormat = format ?? .png
        if !ImageOutputFormat.openaiFormats.contains(actualFormat) {
            throw ImageGenerationError.unsupportedFormat(actualFormat, model: model.displayName)
        }

        // リクエスト作成
        // GPT-Image モデルは response_format をサポートしない（常に base64 を返す）
        // DALL-E モデルのみ response_format を使用
        let useResponseFormat = model == .dalle2 || model == .dalle3

        let request = OpenAIImageRequest(
            model: model.id,
            prompt: prompt,
            n: n,
            size: actualSize.rawValue,
            quality: quality?.rawValue,
            responseFormat: useResponseFormat ? "b64_json" : nil,
            outputFormat: actualFormat == .png ? nil : actualFormat.fileExtension
        )

        // API 呼び出し
        let response = try await sendImageRequest(request, model: model)

        // レスポンス変換
        return try await withThrowingTaskGroup(of: GeneratedImage.self) { group in
            for item in response.data {
                group.addTask {
                    let imageData: Data

                    if let b64Json = item.b64Json {
                        // Base64データがある場合
                        guard let data = Data(base64Encoded: b64Json) else {
                            throw GeneratedMediaError.invalidBase64Data
                        }
                        imageData = data
                    } else if let urlString = item.url, let imageURL = URL(string: urlString) {
                        // URLがある場合はダウンロード
                        let (data, _) = try await URLSession.shared.data(from: imageURL)
                        imageData = data
                    } else {
                        throw GeneratedMediaError.invalidImageData
                    }

                    return GeneratedImage(
                        data: imageData,
                        format: actualFormat,
                        revisedPrompt: item.revisedPrompt
                    )
                }
            }

            var images: [GeneratedImage] = []
            for try await image in group {
                images.append(image)
            }
            return images
        }
    }

    // MARK: - Private Helpers

    private func sendImageRequest(
        _ request: OpenAIImageRequest,
        model: OpenAIImageModel
    ) async throws -> OpenAIImageResponse {
        let endpoint = imageGenerationEndpoint(for: model)

        var urlRequest = URLRequest(url: endpoint)
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
            throw try parseError(from: data, statusCode: httpResponse.statusCode)
        }

        // 注意: CodingKeysで明示的にマッピングしているので、keyDecodingStrategyは使用しない
        let decoder = JSONDecoder()
        return try decoder.decode(OpenAIImageResponse.self, from: data)
    }

    private func imageGenerationEndpoint(for model: OpenAIImageModel) -> URL {
        // endpoint は "https://api.openai.com/v1/chat/completions" のような形式
        // /v1 まで戻って images/generations を追加する
        let baseURL = endpoint
            .deletingLastPathComponent()  // /v1/chat
            .deletingLastPathComponent()  // /v1
        switch model {
        case .gptImage:
            return baseURL.appendingPathComponent("images/generations")
        case .dalle3, .dalle2:
            return baseURL.appendingPathComponent("images/generations")
        }
    }

    private func parseError(from data: Data, statusCode: Int) throws -> LLMError {
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
                if message.contains("content_policy") || message.contains("safety") {
                    throw ImageGenerationError.contentPolicyViolation(message)
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

private struct OpenAIImageRequest: Encodable {
    let model: String
    let prompt: String
    let n: Int
    let size: String
    let quality: String?
    /// DALL-E モデル用（GPT-Image は常に base64 を返すため不要）
    let responseFormat: String?
    /// GPT-Image モデル用（png, jpeg, webp）
    let outputFormat: String?

    enum CodingKeys: String, CodingKey {
        case model
        case prompt
        case n
        case size
        case quality
        case responseFormat = "response_format"
        case outputFormat = "output_format"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(n, forKey: .n)
        try container.encode(size, forKey: .size)
        try container.encodeIfPresent(quality, forKey: .quality)
        try container.encodeIfPresent(responseFormat, forKey: .responseFormat)
        try container.encodeIfPresent(outputFormat, forKey: .outputFormat)
    }
}

private struct OpenAIImageResponse: Decodable {
    let created: Int
    let data: [ImageData]

    struct ImageData: Decodable {
        /// Base64エンコードされた画像データ（response_format="b64_json"の場合）
        let b64Json: String?
        /// 画像のURL（response_format="url"の場合）
        let url: String?
        /// 修正されたプロンプト
        let revisedPrompt: String?

        enum CodingKeys: String, CodingKey {
            case b64Json = "b64_json"
            case url
            case revisedPrompt = "revised_prompt"
        }
    }
}
