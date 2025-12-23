import XCTest
@testable import LLMClient

/// 画像生成機能のテスト
final class ImageGenerationTests: XCTestCase {

    // MARK: - ImageSize Tests

    func testImageSizeDimensions() {
        XCTAssertEqual(ImageSize.square256.width, 256)
        XCTAssertEqual(ImageSize.square256.height, 256)

        XCTAssertEqual(ImageSize.square1024.width, 1024)
        XCTAssertEqual(ImageSize.square1024.height, 1024)

        XCTAssertEqual(ImageSize.landscape1792x1024.width, 1792)
        XCTAssertEqual(ImageSize.landscape1792x1024.height, 1024)

        XCTAssertEqual(ImageSize.portrait1024x1792.width, 1024)
        XCTAssertEqual(ImageSize.portrait1024x1792.height, 1792)
    }

    func testImageSizeOrientation() {
        // Square
        XCTAssertTrue(ImageSize.square256.isSquare)
        XCTAssertTrue(ImageSize.square512.isSquare)
        XCTAssertTrue(ImageSize.square1024.isSquare)
        XCTAssertFalse(ImageSize.square1024.isLandscape)
        XCTAssertFalse(ImageSize.square1024.isPortrait)

        // Landscape
        XCTAssertTrue(ImageSize.landscape1792x1024.isLandscape)
        XCTAssertFalse(ImageSize.landscape1792x1024.isPortrait)
        XCTAssertFalse(ImageSize.landscape1792x1024.isSquare)

        // Portrait
        XCTAssertTrue(ImageSize.portrait1024x1792.isPortrait)
        XCTAssertFalse(ImageSize.portrait1024x1792.isLandscape)
        XCTAssertFalse(ImageSize.portrait1024x1792.isSquare)
    }

    func testImageSizeProviderSupport() {
        // DALL-E 3 sizes
        XCTAssertTrue(ImageSize.dalle3Sizes.contains(.square1024))
        XCTAssertTrue(ImageSize.dalle3Sizes.contains(.landscape1792x1024))
        XCTAssertTrue(ImageSize.dalle3Sizes.contains(.portrait1024x1792))
        XCTAssertFalse(ImageSize.dalle3Sizes.contains(.square256))

        // GPT-Image sizes
        XCTAssertTrue(ImageSize.gptImageSizes.contains(.square1024))
        XCTAssertTrue(ImageSize.gptImageSizes.contains(.square256))
        XCTAssertTrue(ImageSize.gptImageSizes.contains(.landscape1536x1024))

        // Imagen 3 sizes
        XCTAssertTrue(ImageSize.imagen3Sizes.contains(.square1024))
        XCTAssertTrue(ImageSize.imagen3Sizes.contains(.landscape1536x1024))
        XCTAssertFalse(ImageSize.imagen3Sizes.contains(.square256))
    }

    func testImageSizeCodable() throws {
        let original = ImageSize.landscape1792x1024
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ImageSize.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - ImageQuality Tests

    func testImageQualityRawValues() {
        XCTAssertEqual(ImageQuality.standard.rawValue, "standard")
        XCTAssertEqual(ImageQuality.hd.rawValue, "hd")
    }

    func testImageQualityCodable() throws {
        let original = ImageQuality.hd
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ImageQuality.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - ImageStyle Tests

    func testImageStyleRawValues() {
        XCTAssertEqual(ImageStyle.vivid.rawValue, "vivid")
        XCTAssertEqual(ImageStyle.natural.rawValue, "natural")
    }

    // MARK: - OpenAIImageModel Tests

    func testOpenAIImageModelIds() {
        XCTAssertEqual(OpenAIImageModel.dalle3.id, "dall-e-3")
        XCTAssertEqual(OpenAIImageModel.dalle2.id, "dall-e-2")
        XCTAssertEqual(OpenAIImageModel.gptImage.id, "gpt-image-1")
    }

    func testOpenAIImageModelDisplayNames() {
        XCTAssertEqual(OpenAIImageModel.dalle3.displayName, "DALL-E 3")
        XCTAssertEqual(OpenAIImageModel.dalle2.displayName, "DALL-E 2")
        XCTAssertEqual(OpenAIImageModel.gptImage.displayName, "GPT-Image")
    }

    func testOpenAIImageModelSupportedSizes() {
        // DALL-E 3
        XCTAssertEqual(OpenAIImageModel.dalle3.supportedSizes.count, 3)
        XCTAssertTrue(OpenAIImageModel.dalle3.supportedSizes.contains(.square1024))

        // DALL-E 2
        XCTAssertEqual(OpenAIImageModel.dalle2.supportedSizes.count, 3)
        XCTAssertTrue(OpenAIImageModel.dalle2.supportedSizes.contains(.square256))

        // GPT-Image
        XCTAssertEqual(OpenAIImageModel.gptImage.supportedSizes.count, 5)
        XCTAssertTrue(OpenAIImageModel.gptImage.supportedSizes.contains(.landscape1536x1024))
    }

    func testOpenAIImageModelMaxImages() {
        XCTAssertEqual(OpenAIImageModel.dalle3.maxImages, 1)
        XCTAssertEqual(OpenAIImageModel.dalle2.maxImages, 10)
        XCTAssertEqual(OpenAIImageModel.gptImage.maxImages, 4)
    }

    func testOpenAIImageModelCodable() throws {
        let original = OpenAIImageModel.dalle3
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenAIImageModel.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - GeminiImageModel Tests

    func testGeminiImageModelIds() {
        XCTAssertEqual(GeminiImageModel.imagen4.id, "imagen-4.0-generate-001")
        XCTAssertEqual(GeminiImageModel.imagen4Fast.id, "imagen-4.0-fast-generate-001")
    }

    func testGeminiImageModelDisplayNames() {
        XCTAssertEqual(GeminiImageModel.imagen4.displayName, "Imagen 4")
        XCTAssertEqual(GeminiImageModel.imagen4Fast.displayName, "Imagen 4 Fast")
    }

    func testGeminiImageModelSupportedSizes() {
        XCTAssertEqual(GeminiImageModel.imagen4.supportedSizes.count, 3)
        XCTAssertTrue(GeminiImageModel.imagen4.supportedSizes.contains(.square1024))
    }

    func testGeminiImageModelMaxImages() {
        XCTAssertEqual(GeminiImageModel.imagen4.maxImages, 4)
        XCTAssertEqual(GeminiImageModel.imagen4Fast.maxImages, 4)
    }

    func testGeminiImageModelCodable() throws {
        let original = GeminiImageModel.imagen4
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GeminiImageModel.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - ImageGenerationError Tests

    func testImageGenerationErrorDescriptions() {
        let policyError = ImageGenerationError.contentPolicyViolation("unsafe content")
        XCTAssertTrue(policyError.errorDescription?.contains("Content policy") ?? false)

        let sizeError = ImageGenerationError.unsupportedSize(.square256, model: "DALL-E 3")
        XCTAssertTrue(sizeError.errorDescription?.contains("256x256") ?? false)
        XCTAssertTrue(sizeError.errorDescription?.contains("DALL-E 3") ?? false)

        let formatError = ImageGenerationError.unsupportedFormat(.webp, model: "Imagen 3")
        XCTAssertTrue(formatError.errorDescription?.contains("webp") ?? false)

        let countError = ImageGenerationError.exceedsMaxImages(requested: 5, maximum: 1)
        XCTAssertTrue(countError.errorDescription?.contains("5") ?? false)
        XCTAssertTrue(countError.errorDescription?.contains("1") ?? false)

        let providerError = ImageGenerationError.notSupportedByProvider("Anthropic")
        XCTAssertTrue(providerError.errorDescription?.contains("Anthropic") ?? false)
    }

    // MARK: - CaseIterable Tests

    func testImageSizeCaseIterable() {
        XCTAssertEqual(ImageSize.allCases.count, 7)
    }

    func testImageQualityCaseIterable() {
        XCTAssertEqual(ImageQuality.allCases.count, 2)
    }

    func testImageStyleCaseIterable() {
        XCTAssertEqual(ImageStyle.allCases.count, 2)
    }

    func testOpenAIImageModelCaseIterable() {
        XCTAssertEqual(OpenAIImageModel.allCases.count, 3)
    }

    func testGeminiImageModelCaseIterable() {
        XCTAssertEqual(GeminiImageModel.allCases.count, 4)
    }

    // MARK: - Protocol Conformance Tests

    func testOpenAIClientConformsToImageGenerationCapable() {
        // This test verifies at compile time that OpenAIClient conforms to ImageGenerationCapable
        func verifyConformance<T: ImageGenerationCapable>(_: T.Type) {}
        verifyConformance(OpenAIClient.self)
    }

    func testGeminiClientConformsToImageGenerationCapable() {
        // This test verifies at compile time that GeminiClient conforms to ImageGenerationCapable
        func verifyConformance<T: ImageGenerationCapable>(_: T.Type) {}
        verifyConformance(GeminiClient.self)
    }
}
