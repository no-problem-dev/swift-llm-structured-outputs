// GeminiClient+ImageGeneration.swift
// swift-llm-structured-outputs
//
// Gemini クライアントの画像生成機能拡張
// Imagen モデルと Gemini Image モデルの両方をサポート

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - GeminiClient + ImageGenerationCapable

extension GeminiClient: ImageGenerationCapable {
    public typealias ImageModel = GeminiImageModel

    /// 画像を生成
    ///
    /// - Parameters:
    ///   - prompt: 画像を説明するプロンプト
    ///   - model: 使用する画像生成モデル
    ///   - size: 出力画像のサイズ
    ///   - quality: 画像品質（Gemini では未使用）
    ///   - format: 出力フォーマット（Gemini は PNG のみ対応）
    ///   - n: 生成する画像の数
    /// - Returns: 生成された画像
    public func generateImage(
        prompt: String,
        model: GeminiImageModel,
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
    ///   - quality: 画像品質（Gemini では未使用）
    ///   - format: 出力フォーマット（Gemini は PNG のみ対応）
    ///   - n: 生成する画像の数
    /// - Returns: 生成された画像の配列
    public func generateImages(
        prompt: String,
        model: GeminiImageModel,
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

        // Gemini は PNG のみ対応
        let actualFormat: ImageOutputFormat = .png
        if let requestedFormat = format, requestedFormat != .png {
            throw ImageGenerationError.unsupportedFormat(requestedFormat, model: model.displayName)
        }

        // モデルタイプに応じて処理を分岐
        if model.isImagenModel {
            return try await generateWithImagen(
                prompt: prompt,
                model: model,
                size: actualSize,
                n: n,
                format: actualFormat
            )
        } else {
            return try await generateWithGeminiImage(
                prompt: prompt,
                model: model,
                format: actualFormat
            )
        }
    }

    // MARK: - Imagen API

    private func generateWithImagen(
        prompt: String,
        model: GeminiImageModel,
        size: ImageSize,
        n: Int,
        format: ImageOutputFormat
    ) async throws -> [GeneratedImage] {
        let endpoint = imagenEndpoint(for: model)

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let requestBody = ImagenRequestBody(
            instances: [ImagenInstance(prompt: prompt)],
            parameters: ImagenParameters(
                sampleCount: n,
                aspectRatio: aspectRatioString(for: size),
                personGeneration: "allow_adult"
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
        let imagenResponse = try decoder.decode(ImagenResponse.self, from: data)

        return try imagenResponse.predictions.compactMap { prediction -> GeneratedImage? in
            guard let base64 = prediction.bytesBase64Encoded else {
                return nil
            }
            guard let imageData = Data(base64Encoded: base64) else {
                throw GeneratedMediaError.invalidBase64Data
            }
            return GeneratedImage(
                data: imageData,
                format: format,
                revisedPrompt: nil
            )
        }
    }

    private func imagenEndpoint(for model: GeminiImageModel) -> URL {
        let baseURLString = "https://generativelanguage.googleapis.com/v1beta/models/\(model.id):predict"
        return URL(string: baseURLString)!
    }

    // MARK: - Gemini Image API (generateContent)

    private func generateWithGeminiImage(
        prompt: String,
        model: GeminiImageModel,
        format: ImageOutputFormat
    ) async throws -> [GeneratedImage] {
        let endpoint = geminiImageEndpoint(for: model)

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let requestBody = GeminiImageRequestBody(
            contents: [
                GeminiImageContent(parts: [GeminiImagePart(text: prompt)])
            ],
            generationConfig: GeminiImageGenerationConfig(
                responseModalities: ["TEXT", "IMAGE"]
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
        let geminiResponse = try decoder.decode(GeminiImageResponse.self, from: data)

        var images: [GeneratedImage] = []

        for candidate in geminiResponse.candidates ?? [] {
            for part in candidate.content?.parts ?? [] {
                if let inlineData = part.inlineData,
                   let base64 = inlineData.data,
                   let imageData = Data(base64Encoded: base64) {
                    images.append(GeneratedImage(
                        data: imageData,
                        format: format,
                        revisedPrompt: nil
                    ))
                }
            }
        }

        if images.isEmpty {
            throw LLMError.emptyResponse
        }

        return images
    }

    private func geminiImageEndpoint(for model: GeminiImageModel) -> URL {
        let baseURLString = "https://generativelanguage.googleapis.com/v1beta/models/\(model.id):generateContent"
        return URL(string: baseURLString)!
    }

    // MARK: - Private Helpers

    private func aspectRatioString(for size: ImageSize) -> String {
        switch size {
        case .square256, .square512, .square1024:
            return "1:1"
        case .landscape1792x1024, .landscape1536x1024:
            return "16:9"
        case .portrait1024x1792, .portrait1024x1536:
            return "9:16"
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

// MARK: - Imagen Request/Response Types

private struct ImagenRequestBody: Encodable {
    let instances: [ImagenInstance]
    let parameters: ImagenParameters
}

private struct ImagenInstance: Encodable {
    let prompt: String
}

private struct ImagenParameters: Encodable {
    let sampleCount: Int
    let aspectRatio: String
    let personGeneration: String
}

private struct ImagenResponse: Decodable {
    let predictions: [ImagenPrediction]

    struct ImagenPrediction: Decodable {
        let bytesBase64Encoded: String?
        let mimeType: String?
    }
}

// MARK: - Gemini Image Request/Response Types

private struct GeminiImageRequestBody: Encodable {
    let contents: [GeminiImageContent]
    let generationConfig: GeminiImageGenerationConfig
}

private struct GeminiImageContent: Encodable {
    let parts: [GeminiImagePart]
}

private struct GeminiImagePart: Encodable {
    let text: String?
    let inlineData: GeminiInlineData?

    init(text: String) {
        self.text = text
        self.inlineData = nil
    }
}

private struct GeminiInlineData: Codable {
    let mimeType: String?
    let data: String?
}

private struct GeminiImageGenerationConfig: Encodable {
    let responseModalities: [String]
}

private struct GeminiImageResponse: Decodable {
    let candidates: [GeminiCandidate]?

    struct GeminiCandidate: Decodable {
        let content: GeminiCandidateContent?
    }

    struct GeminiCandidateContent: Decodable {
        let parts: [GeminiResponsePart]?
    }

    struct GeminiResponsePart: Decodable {
        let text: String?
        let inlineData: GeminiInlineData?
    }
}
