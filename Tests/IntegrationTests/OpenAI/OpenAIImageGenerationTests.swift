// ImageGenerationTests.swift
// swift-llm-structured-outputs
//
// OpenAI 画像生成 (DALL-E) のインテグレーションテスト

import Foundation
import Testing
@testable import LLMStructuredOutputs

@Suite("OpenAI Image Generation", .tags(.integration, .openai, .imageGeneration))
struct OpenAIImageGenerationTests {
    let client: OpenAIClient

    init() throws {
        let apiKey = try TestConfiguration.requireOpenAIKey()
        client = OpenAIClient(apiKey: apiKey)
    }

    // MARK: - DALL-E 3 Tests

    @Test("DALL-E 3 basic generation")
    func testBasicGeneration() async throws {
        let image = try await client.generateImage(
            input: "A simple red circle on white background",
            model: .dalle3,
            size: .square1024,
            quality: .standard,
            format: .png,
            n: 1
        )

        #expect(image.data.count > 0)
        #expect(image.format == .png)
        #expect(image.mimeType == "image/png")
        assertValidImageData(image.data, context: "DALL-E 3 basic")
    }

    @Test("DALL-E 3 HD quality")
    func testHDQuality() async throws {
        let image = try await client.generateImage(
            input: "A minimalist blue square",
            model: .dalle3,
            size: .square1024,
            quality: .hd,
            format: .png,
            n: 1
        )

        #expect(image.data.count > 0)
        assertValidImageData(image.data, context: "DALL-E 3 HD")
    }

    @Test("DALL-E 3 portrait size (1024x1792)")
    func testPortraitSize() async throws {
        let image = try await client.generateImage(
            input: "A vertical green line",
            model: .dalle3,
            size: .portrait1024x1792,
            quality: .standard,
            format: .png,
            n: 1
        )

        #expect(image.data.count > 0)
        assertValidImageData(image.data, context: "DALL-E 3 portrait")
    }

    @Test("DALL-E 3 landscape size (1792x1024)")
    func testLandscapeSize() async throws {
        let image = try await client.generateImage(
            input: "A horizontal purple line",
            model: .dalle3,
            size: .landscape1792x1024,
            quality: .standard,
            format: .png,
            n: 1
        )

        #expect(image.data.count > 0)
        assertValidImageData(image.data, context: "DALL-E 3 landscape")
    }

    // MARK: - DALL-E 2 Tests

    @Test("DALL-E 2 multiple images (n=2)")
    func testMultipleImages() async throws {
        let images = try await client.generateImages(
            input: "A simple yellow triangle",
            model: .dalle2,
            size: .square1024,
            quality: nil,
            format: .png,
            n: 2
        )

        #expect(images.count == 2)
        for (index, image) in images.enumerated() {
            assertValidImageData(image.data, context: "DALL-E 2 image \(index + 1)")
        }
    }
}
