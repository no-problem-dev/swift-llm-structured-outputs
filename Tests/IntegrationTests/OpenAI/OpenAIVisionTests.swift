// VisionTests.swift
// swift-llm-structured-outputs
//
// OpenAI Vision (画像入力) のインテグレーションテスト

import Foundation
import Testing
@testable import LLMStructuredOutputs

@Suite("OpenAI Vision", .tags(.integration, .openai, .vision))
struct OpenAIVisionTests {
    let client: OpenAIClient

    init() throws {
        let apiKey = try TestConfiguration.requireOpenAIKey()
        client = OpenAIClient(apiKey: apiKey)
    }

    // MARK: - Generated Image Analysis

    @Test("Analyze generated image")
    func testAnalyzeGeneratedImage() async throws {
        // まず簡単な画像を生成
        let generatedImage = try await client.generateImage(
            input: "A solid blue square on white background, simple geometric shape",
            model: .dalle3,
            size: .square1024,
            quality: .standard,
            format: .png,
            n: 1
        )

        // 生成した画像を分析
        let imageContent = ImageContent.base64(generatedImage.data, mediaType: .png)
        let message = LLMMessage.user(
            "この画像を分析してください。主な色、形状、簡単な説明を教えてください。",
            image: imageContent
        )

        let analysis: ImageAnalysisResult = try await client.generate(
            messages: [message],
            model: .gpt4o,
            systemPrompt: "画像を分析し、指定されたJSON形式で回答してください。"
        )

        #expect(!analysis.dominantColor.isEmpty)
        #expect(!analysis.mainShape.isEmpty)
        #expect(!analysis.description.isEmpty)
    }

    // MARK: - URL Image Analysis

    @Test("Analyze image from URL")
    func testAnalyzeURLImage() async throws {
        // OpenAI の公開ロゴ画像を使用
        let imageURL = URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4d/OpenAI_Logo.svg/200px-OpenAI_Logo.svg.png")!
        let imageContent = ImageContent.url(imageURL, mediaType: .png)
        let message = LLMMessage.user(
            "この画像に何が写っていますか？会社のロゴですか？色と形を説明してください。",
            image: imageContent
        )

        let analysis: ImageAnalysisResult = try await client.generate(
            messages: [message],
            model: .gpt4o,
            systemPrompt: "画像を分析し、指定されたJSON形式で回答してください。"
        )

        #expect(!analysis.dominantColor.isEmpty)
        #expect(!analysis.mainShape.isEmpty)
        #expect(!analysis.description.isEmpty)
    }

    // MARK: - Base64 Image Analysis

    @Test("Analyze base64 image")
    func testAnalyzeBase64Image() async throws {
        // 小さなテスト画像（赤いピクセル）を作成
        let testImageData = createTestImageData()

        let imageContent = ImageContent.base64(testImageData, mediaType: .png)
        let message = LLMMessage.user(
            "What color is this image? Answer with just the color name.",
            image: imageContent
        )

        let response: ColorAnalysisResult = try await client.generate(
            messages: [message],
            model: .gpt4o
        )

        #expect(!response.color.isEmpty)
    }

    // MARK: - Message Content Verification

    @Test("Message with image has correct properties")
    func testMessageProperties() {
        let testImageData = createTestImageData()
        let imageContent = ImageContent.base64(testImageData, mediaType: .png)
        let message = LLMMessage.user("Describe this image", image: imageContent)

        #expect(message.hasMediaContent == true)
        #expect(message.hasImage == true)
        #expect(message.images.count == 1)
    }
}
