import XCTest
@testable import LLMStructuredOutputs
@testable import LLMClient

/// 動画生成機能のテスト
final class VideoGenerationTests: XCTestCase {

    // MARK: - OpenAIVideoModel Tests

    func testOpenAIVideoModelIds() {
        XCTAssertEqual(OpenAIVideoModel.sora2.id, "sora-2")
        XCTAssertEqual(OpenAIVideoModel.sora2Pro.id, "sora-2-pro")
    }

    func testOpenAIVideoModelDisplayNames() {
        XCTAssertEqual(OpenAIVideoModel.sora2.displayName, "Sora 2")
        XCTAssertEqual(OpenAIVideoModel.sora2Pro.displayName, "Sora 2 Pro")
    }

    func testOpenAIVideoModelMaxDuration() {
        XCTAssertEqual(OpenAIVideoModel.sora2.maxDuration, 12)
        XCTAssertEqual(OpenAIVideoModel.sora2Pro.maxDuration, 12)
    }

    func testOpenAIVideoModelSupportedAspectRatios() {
        let ratios = OpenAIVideoModel.sora2.supportedAspectRatios
        XCTAssertTrue(ratios.contains(.landscape16x9))
        XCTAssertTrue(ratios.contains(.portrait9x16))
    }

    func testOpenAIVideoModelSupportedResolutions() {
        let resolutions = OpenAIVideoModel.sora2.supportedResolutions
        XCTAssertTrue(resolutions.contains(.hd720p))

        let proResolutions = OpenAIVideoModel.sora2Pro.supportedResolutions
        XCTAssertTrue(proResolutions.contains(.hd720p))
        XCTAssertTrue(proResolutions.contains(.fhd1080p))
    }

    func testOpenAIVideoModelCodable() throws {
        let original = OpenAIVideoModel.sora2
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenAIVideoModel.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - GeminiVideoModel Tests

    func testGeminiVideoModelIds() {
        XCTAssertEqual(GeminiVideoModel.veo31.id, "veo-3.1-generate-preview")
        XCTAssertEqual(GeminiVideoModel.veo20.id, "veo-2.0-generate-001")
    }

    func testGeminiVideoModelDisplayNames() {
        XCTAssertEqual(GeminiVideoModel.veo31.displayName, "Veo 3.1")
        XCTAssertEqual(GeminiVideoModel.veo20.displayName, "Veo 2.0")
    }

    func testGeminiVideoModelMaxDuration() {
        XCTAssertEqual(GeminiVideoModel.veo31.maxDuration, 8)
        XCTAssertEqual(GeminiVideoModel.veo20.maxDuration, 8)
    }

    func testGeminiVideoModelSupportedAspectRatios() {
        let ratios = GeminiVideoModel.veo31.supportedAspectRatios
        XCTAssertTrue(ratios.contains(.landscape16x9))
        XCTAssertTrue(ratios.contains(.portrait9x16))
    }

    func testGeminiVideoModelSupportedResolutions() {
        let resolutions = GeminiVideoModel.veo31.supportedResolutions
        XCTAssertTrue(resolutions.contains(.hd720p))
        XCTAssertTrue(resolutions.contains(.fhd1080p))

        let veo20Resolutions = GeminiVideoModel.veo20.supportedResolutions
        XCTAssertTrue(veo20Resolutions.contains(.hd720p))
    }

    func testGeminiVideoModelCodable() throws {
        let original = GeminiVideoModel.veo31
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

        let ratioError = VideoGenerationError.unsupportedAspectRatio(.cinematic21x9, model: "Sora 2")
        XCTAssertTrue(ratioError.errorDescription?.contains("21:9") ?? false)

        let resolutionError = VideoGenerationError.unsupportedResolution(.uhd4k, model: "Sora 2")
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
        XCTAssertEqual(OpenAIVideoModel.allCases.count, 2)
    }

    func testGeminiVideoModelCaseIterable() {
        XCTAssertEqual(GeminiVideoModel.allCases.count, 5)
    }
}
