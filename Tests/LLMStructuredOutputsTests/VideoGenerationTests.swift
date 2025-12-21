import XCTest
@testable import LLMStructuredOutputs
@testable import LLMClient

/// 動画生成機能のテスト
final class VideoGenerationTests: XCTestCase {

    // MARK: - OpenAIVideoModel Tests

    func testOpenAIVideoModelIds() {
        XCTAssertEqual(OpenAIVideoModel.sora.id, "sora")
    }

    func testOpenAIVideoModelDisplayNames() {
        XCTAssertEqual(OpenAIVideoModel.sora.displayName, "Sora")
    }

    func testOpenAIVideoModelMaxDuration() {
        XCTAssertEqual(OpenAIVideoModel.sora.maxDuration, 60)
    }

    func testOpenAIVideoModelSupportedAspectRatios() {
        let ratios = OpenAIVideoModel.sora.supportedAspectRatios
        XCTAssertTrue(ratios.contains(.landscape16x9))
        XCTAssertTrue(ratios.contains(.portrait9x16))
        XCTAssertTrue(ratios.contains(.square1x1))
    }

    func testOpenAIVideoModelSupportedResolutions() {
        let resolutions = OpenAIVideoModel.sora.supportedResolutions
        XCTAssertTrue(resolutions.contains(.hd720p))
        XCTAssertTrue(resolutions.contains(.fhd1080p))
    }

    func testOpenAIVideoModelCodable() throws {
        let original = OpenAIVideoModel.sora
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenAIVideoModel.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - GeminiVideoModel Tests

    func testGeminiVideoModelIds() {
        XCTAssertEqual(GeminiVideoModel.veo2.id, "veo-002")
    }

    func testGeminiVideoModelDisplayNames() {
        XCTAssertEqual(GeminiVideoModel.veo2.displayName, "Veo 2")
    }

    func testGeminiVideoModelMaxDuration() {
        XCTAssertEqual(GeminiVideoModel.veo2.maxDuration, 60)
    }

    func testGeminiVideoModelSupportedAspectRatios() {
        let ratios = GeminiVideoModel.veo2.supportedAspectRatios
        XCTAssertTrue(ratios.contains(.landscape16x9))
        XCTAssertTrue(ratios.contains(.portrait9x16))
    }

    func testGeminiVideoModelSupportedResolutions() {
        let resolutions = GeminiVideoModel.veo2.supportedResolutions
        XCTAssertTrue(resolutions.contains(.fhd1080p))
        XCTAssertTrue(resolutions.contains(.uhd4k))
    }

    func testGeminiVideoModelCodable() throws {
        let original = GeminiVideoModel.veo2
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GeminiVideoModel.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - VideoGenerationError Tests

    func testVideoGenerationErrorDescriptions() {
        let policyError = VideoGenerationError.contentPolicyViolation("unsafe content")
        XCTAssertTrue(policyError.errorDescription?.contains("Content policy") ?? false)

        let durationError = VideoGenerationError.durationExceedsLimit(requested: 120, maximum: 60)
        XCTAssertTrue(durationError.errorDescription?.contains("120") ?? false)
        XCTAssertTrue(durationError.errorDescription?.contains("60") ?? false)

        let ratioError = VideoGenerationError.unsupportedAspectRatio(.cinematic21x9, model: "Sora")
        XCTAssertTrue(ratioError.errorDescription?.contains("21:9") ?? false)

        let resolutionError = VideoGenerationError.unsupportedResolution(.uhd4k, model: "Sora")
        XCTAssertTrue(resolutionError.errorDescription?.contains("4k") ?? false)

        let failedError = VideoGenerationError.generationFailed("Server error")
        XCTAssertTrue(failedError.errorDescription?.contains("Server error") ?? false)

        let timeoutError = VideoGenerationError.timeout(elapsed: 300)
        XCTAssertTrue(timeoutError.errorDescription?.contains("300") ?? false)

        let cancelledError = VideoGenerationError.cancelled
        XCTAssertTrue(cancelledError.errorDescription?.contains("cancelled") ?? false)

        let notCompletedError = VideoGenerationError.jobNotCompleted(status: .processing)
        XCTAssertTrue(notCompletedError.errorDescription?.contains("processing") ?? false)

        let providerError = VideoGenerationError.notSupportedByProvider("Anthropic")
        XCTAssertTrue(providerError.errorDescription?.contains("Anthropic") ?? false)
    }

    // MARK: - CaseIterable Tests

    func testOpenAIVideoModelCaseIterable() {
        XCTAssertEqual(OpenAIVideoModel.allCases.count, 1)
    }

    func testGeminiVideoModelCaseIterable() {
        XCTAssertEqual(GeminiVideoModel.allCases.count, 1)
    }
}
