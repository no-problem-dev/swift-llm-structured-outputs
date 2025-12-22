// VisionTests.swift
// swift-llm-structured-outputs
//
// Anthropic Vision (画像入力) のインテグレーションテスト

import Foundation
import Testing
@testable import LLMStructuredOutputs

@Suite("Anthropic Vision", .tags(.integration, .anthropic, .vision))
struct AnthropicVisionTests {
    let client: AnthropicClient

    init() throws {
        let apiKey = try TestConfiguration.requireAnthropicKey()
        client = AnthropicClient(apiKey: apiKey)
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
            model: .haiku  // 最も安価なモデルを使用
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
            model: .haiku,
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
            model: .haiku,
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
            model: .haiku,
            systemPrompt: "Analyze and compare the images. Respond in the specified JSON format."
        )

        #expect(!analysis.description.isEmpty)
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

    @Test("Claude models for vision")
    func testClaudeModelsForVision() {
        // Vision対応モデルの確認
        let opus = ClaudeModel.opus
        let sonnet = ClaudeModel.sonnet
        let haiku = ClaudeModel.haiku

        // 全てのClaudeモデルがVisionをサポート
        #expect(opus.id.contains("claude"))
        #expect(sonnet.id.contains("claude"))
        #expect(haiku.id.contains("claude"))
    }
}
