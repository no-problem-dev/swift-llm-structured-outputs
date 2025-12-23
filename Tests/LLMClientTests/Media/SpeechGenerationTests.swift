import XCTest
@testable import LLMClient

/// 音声生成機能のテスト
final class SpeechGenerationTests: XCTestCase {

    // MARK: - OpenAITTSModel Tests

    func testOpenAITTSModelIds() {
        XCTAssertEqual(OpenAITTSModel.tts1.id, "tts-1")
        XCTAssertEqual(OpenAITTSModel.tts1HD.id, "tts-1-hd")
    }

    func testOpenAITTSModelDisplayNames() {
        XCTAssertEqual(OpenAITTSModel.tts1.displayName, "TTS-1")
        XCTAssertEqual(OpenAITTSModel.tts1HD.displayName, "TTS-1 HD")
    }

    func testOpenAITTSModelSupportedFormats() {
        let formats = OpenAITTSModel.tts1.supportedFormats
        XCTAssertTrue(formats.contains(.mp3))
        XCTAssertTrue(formats.contains(.wav))
        XCTAssertTrue(formats.contains(.opus))
        XCTAssertTrue(formats.contains(.aac))
        XCTAssertTrue(formats.contains(.flac))
        XCTAssertTrue(formats.contains(.pcm))
    }

    func testOpenAITTSModelCodable() throws {
        let original = OpenAITTSModel.tts1HD
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenAITTSModel.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - OpenAIVoice Tests

    func testOpenAIVoiceIds() {
        XCTAssertEqual(OpenAIVoice.alloy.id, "alloy")
        XCTAssertEqual(OpenAIVoice.echo.id, "echo")
        XCTAssertEqual(OpenAIVoice.fable.id, "fable")
        XCTAssertEqual(OpenAIVoice.onyx.id, "onyx")
        XCTAssertEqual(OpenAIVoice.nova.id, "nova")
        XCTAssertEqual(OpenAIVoice.shimmer.id, "shimmer")
    }

    func testOpenAIVoiceDisplayNames() {
        XCTAssertEqual(OpenAIVoice.alloy.displayName, "Alloy")
        XCTAssertEqual(OpenAIVoice.nova.displayName, "Nova")
    }

    func testOpenAIVoiceCodable() throws {
        let original = OpenAIVoice.shimmer
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenAIVoice.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - GeminiTTSModel Tests

    func testGeminiTTSModelIds() {
        XCTAssertEqual(GeminiTTSModel.geminiTTS.id, "gemini-tts-preview")
    }

    func testGeminiTTSModelDisplayNames() {
        XCTAssertEqual(GeminiTTSModel.geminiTTS.displayName, "Gemini TTS")
    }

    func testGeminiTTSModelSupportedFormats() {
        let formats = GeminiTTSModel.geminiTTS.supportedFormats
        XCTAssertTrue(formats.contains(.pcm))
        XCTAssertFalse(formats.contains(.mp3))
    }

    // MARK: - SpeechGenerationError Tests

    func testSpeechGenerationErrorDescriptions() {
        let textTooLongError = SpeechGenerationError.textTooLong(length: 5000, maximum: 4096)
        XCTAssertTrue(textTooLongError.errorDescription?.contains("5000") ?? false)
        XCTAssertTrue(textTooLongError.errorDescription?.contains("4096") ?? false)

        let emptyTextError = SpeechGenerationError.emptyText
        XCTAssertTrue(emptyTextError.errorDescription?.contains("empty") ?? false)

        let invalidSpeedError = SpeechGenerationError.invalidSpeed(5.0)
        XCTAssertTrue(invalidSpeedError.errorDescription?.contains("5.0") ?? false)

        let formatError = SpeechGenerationError.unsupportedFormat(.pcm, model: "TTS-1")
        XCTAssertTrue(formatError.errorDescription?.contains("pcm") ?? false)

        let providerError = SpeechGenerationError.notSupportedByProvider("Anthropic")
        XCTAssertTrue(providerError.errorDescription?.contains("Anthropic") ?? false)
    }

    // MARK: - CaseIterable Tests

    func testOpenAITTSModelCaseIterable() {
        XCTAssertEqual(OpenAITTSModel.allCases.count, 2)
    }

    func testOpenAIVoiceCaseIterable() {
        XCTAssertEqual(OpenAIVoice.allCases.count, 6)
    }

    func testGeminiTTSModelCaseIterable() {
        XCTAssertEqual(GeminiTTSModel.allCases.count, 1)
    }

    // MARK: - Protocol Conformance Tests

    func testOpenAIClientConformsToSpeechGenerationCapable() {
        // This test verifies at compile time that OpenAIClient conforms to SpeechGenerationCapable
        func verifyConformance<T: SpeechGenerationCapable>(_: T.Type) {}
        verifyConformance(OpenAIClient.self)
    }
}
