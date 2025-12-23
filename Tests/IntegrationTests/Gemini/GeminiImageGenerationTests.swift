// GeminiImageGenerationTests.swift
// swift-llm-structured-outputs
//
// Gemini 画像生成 (Imagen) のインテグレーションテスト

import Foundation
import Testing
@testable import LLMStructuredOutputs

@Suite("Gemini Image Generation", .tags(.integration, .gemini, .imageGeneration))
struct GeminiImageGenerationTests {
    let client: GeminiClient

    init() throws {
        let apiKey = try TestConfiguration.requireGeminiKey()
        client = GeminiClient(apiKey: apiKey)
    }

    // MARK: - Imagen 4 Tests

    @Test("Imagen 4 basic generation")
    func testBasicGeneration() async throws {
        let image = try await client.generateImage(
            input: "A simple red circle on white background",
            model: .imagen4,
            size: .square1024,
            quality: nil,
            format: .png,
            n: 1
        )

        #expect(image.data.count > 0)
        #expect(image.format == .png)
        #expect(image.mimeType == "image/png")
        assertValidImageData(image.data, context: "Imagen 4 basic")
    }

    @Test("Imagen 4 Fast generation")
    func testFastGeneration() async throws {
        let image = try await client.generateImage(
            input: "A blue square",
            model: .imagen4Fast,
            size: .square1024,
            quality: nil,
            format: .png,
            n: 1
        )

        #expect(image.data.count > 0)
        assertValidImageData(image.data, context: "Imagen 4 Fast")
    }

    @Test("Imagen 4 landscape image")
    func testLandscapeImage() async throws {
        let image = try await client.generateImage(
            input: "A horizontal landscape with mountains",
            model: .imagen4Fast,
            size: .landscape1792x1024,
            quality: nil,
            format: .png,
            n: 1
        )

        #expect(image.data.count > 0)
        assertValidImageData(image.data, context: "Imagen 4 landscape")
    }

    @Test("Imagen 4 portrait image")
    func testPortraitImage() async throws {
        let image = try await client.generateImage(
            input: "A vertical portrait of a tree",
            model: .imagen4Fast,
            size: .portrait1024x1792,
            quality: nil,
            format: .png,
            n: 1
        )

        #expect(image.data.count > 0)
        assertValidImageData(image.data, context: "Imagen 4 portrait")
    }

    // MARK: - Multiple Images

    @Test("Imagen 4 multiple images")
    func testMultipleImages() async throws {
        let images = try await client.generateImages(
            input: "A green triangle",
            model: .imagen4Fast,
            size: .square1024,
            quality: nil,
            format: .png,
            n: 2
        )

        #expect(images.count == 2)
        for (index, image) in images.enumerated() {
            assertValidImageData(image.data, context: "Imagen 4 image \(index + 1)")
        }
    }

    // MARK: - Model Properties Tests (No API Call)

    @Test("Imagen 4 model properties")
    func testImagen4ModelProperties() {
        let model = GeminiImageModel.imagen4

        #expect(model.id == "imagen-4.0-generate-001")
        #expect(model.displayName == "Imagen 4")
        #expect(model.maxImages == 4)
        #expect(model.isImagenModel == true)
        #expect(model.supportedSizes.contains(ImageSize.square1024))
        #expect(model.supportedSizes.contains(ImageSize.landscape1792x1024))
        #expect(model.supportedSizes.contains(ImageSize.portrait1024x1792))
    }

    @Test("Imagen 4 Fast model properties")
    func testImagen4FastModelProperties() {
        let model = GeminiImageModel.imagen4Fast

        #expect(model.id == "imagen-4.0-fast-generate-001")
        #expect(model.displayName == "Imagen 4 Fast")
        #expect(model.maxImages == 4)
        #expect(model.isImagenModel == true)
    }

    @Test("Imagen 4 Ultra model properties")
    func testImagen4UltraModelProperties() {
        let model = GeminiImageModel.imagen4Ultra

        #expect(model.id == "imagen-4.0-ultra-generate-001")
        #expect(model.displayName == "Imagen 4 Ultra")
        #expect(model.maxImages == 4)
        #expect(model.isImagenModel == true)
    }

    @Test("Gemini Flash Image model properties")
    func testGeminiFlashImageModelProperties() {
        let model = GeminiImageModel.gemini20FlashImage

        #expect(model.id == "gemini-2.0-flash-exp-image-generation")
        #expect(model.displayName == "Gemini 2.0 Flash Image")
        #expect(model.maxImages == 1)  // Gemini Image は1枚のみ
        #expect(model.isImagenModel == false)
    }

    // MARK: - Error Handling Tests

    @Test("Unsupported format should throw error")
    func testUnsupportedFormat() async throws {
        // Gemini は PNG のみサポート
        await #expect(throws: (any Error).self) {
            _ = try await client.generateImage(
                input: "A test image",
                model: .imagen4Fast,
                size: .square1024,
                quality: nil,
                format: .jpeg,  // Unsupported
                n: 1
            )
        }
    }

    @Test("Exceeding max images should throw error")
    func testExceedingMaxImages() async throws {
        await #expect(throws: (any Error).self) {
            _ = try await client.generateImages(
                input: "A test image",
                model: .imagen4Fast,
                size: .square1024,
                quality: nil,
                format: .png,
                n: 10  // Max is 4
            )
        }
    }
}
