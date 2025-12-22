// VisionTests.swift
// swift-llm-structured-outputs
//
// Gemini Vision (画像入力) のインテグレーションテスト

import Foundation
import Testing
@testable import LLMStructuredOutputs

@Suite("Gemini Vision", .tags(.integration, .gemini, .vision))
struct GeminiVisionTests {
    let client: GeminiClient

    init() throws {
        let apiKey = try TestConfiguration.requireGeminiKey()
        client = GeminiClient(apiKey: apiKey)
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
            model: .flash25  // 最も安価なモデルを使用
        )

        #expect(!response.color.isEmpty)
    }

    @Test("Analyze image with detailed response")
    func testAnalyzeImageDetailed() async throws {
        let testImageData = createTestImageData()

        let imageContent = ImageContent.base64(testImageData, mediaType: .png)
        let message = LLMMessage.user(
            "この画像を分析してください。主な色、形状、簡単な説明を教えてください。",
            image: imageContent
        )

        let analysis: ImageAnalysisResult = try await client.generate(
            messages: [message],
            model: .flash25,
            systemPrompt: "画像を分析し、指定されたJSON形式で回答してください。"
        )

        #expect(!analysis.dominantColor.isEmpty)
        #expect(!analysis.mainShape.isEmpty)
        #expect(!analysis.description.isEmpty)
    }

    // MARK: - URL Image Analysis

    @Test("Analyze image from URL")
    func testAnalyzeURLImage() async throws {
        // 公開されているテスト画像を使用
        let imageURL = URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0c/GoldenGateBridge-001.jpg/200px-GoldenGateBridge-001.jpg")!
        let imageContent = ImageContent.url(imageURL, mediaType: .jpeg)
        let message = LLMMessage.user(
            "What is shown in this image? Describe the main object or scene.",
            image: imageContent
        )

        let analysis: ImageAnalysisResult = try await client.generate(
            messages: [message],
            model: .flash25,
            systemPrompt: "Analyze the image and respond in the specified JSON format."
        )

        #expect(!analysis.description.isEmpty)
    }

    // MARK: - Multiple Images

    @Test("Analyze multiple images")
    func testAnalyzeMultipleImages() async throws {
        let testImageData = createTestImageData()

        // 同じ画像を2つ送信（実際のテストでは異なる画像を使用）
        let images = [
            ImageContent.base64(testImageData, mediaType: .png),
            ImageContent.base64(testImageData, mediaType: .png)
        ]
        let message = LLMMessage.user(
            "Compare these two images. What are the similarities?",
            images: images
        )

        let analysis: ImageAnalysisResult = try await client.generate(
            messages: [message],
            model: .flash25,
            systemPrompt: "Analyze and compare the images. Respond in the specified JSON format."
        )

        #expect(!analysis.description.isEmpty)
    }

    // MARK: - Different Models

    @Test("Vision with Gemini Flash 2.0")
    func testVisionWithFlash20() async throws {
        let testImageData = createTestImageData()

        let imageContent = ImageContent.base64(testImageData, mediaType: .png)
        let message = LLMMessage.user(
            "What color is this image?",
            image: imageContent
        )

        let response: ColorAnalysisResult = try await client.generate(
            messages: [message],
            model: .flash20
        )

        #expect(!response.color.isEmpty)
    }

    @Test("Vision with Gemini Pro 2.5")
    func testVisionWithPro25() async throws {
        let testImageData = createTestImageData()

        let imageContent = ImageContent.base64(testImageData, mediaType: .png)
        let message = LLMMessage.user(
            "What color is this image?",
            image: imageContent
        )

        let response: ColorAnalysisResult = try await client.generate(
            messages: [message],
            model: .pro25
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

    // MARK: - Model Selection Tests (No API Call)

    @Test("Gemini models for vision")
    func testGeminiModelsForVision() {
        // Vision対応モデルの確認
        let flash25 = GeminiModel.flash25
        let flash20 = GeminiModel.flash20
        let pro25 = GeminiModel.pro25

        // 全てのGeminiモデルがVisionをサポート
        #expect(flash25.id.contains("gemini"))
        #expect(flash20.id.contains("gemini"))
        #expect(pro25.id.contains("gemini"))
    }
}
