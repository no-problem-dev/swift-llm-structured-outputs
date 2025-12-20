import XCTest
@testable import LLMStructuredOutputs
@testable import LLMClient

final class MediaContentTests: XCTestCase {

    // MARK: - ImageContent Tests

    func testImageContentInit() {
        let source = MediaSource.base64(Data("test".utf8))
        let image = ImageContent(source: source, mediaType: .jpeg, detail: .high)

        XCTAssertEqual(image.source, source)
        XCTAssertEqual(image.mediaType, .jpeg)
        XCTAssertEqual(image.detail, .high)
    }

    func testImageContentBase64Convenience() {
        let data = Data("test image".utf8)
        let image = ImageContent.base64(data, mediaType: .png, detail: .low)

        XCTAssertTrue(image.source.isBase64)
        XCTAssertEqual(image.mediaType, .png)
        XCTAssertEqual(image.detail, .low)
    }

    func testImageContentURLConvenience() {
        let url = URL(string: "https://example.com/image.jpg")!
        let image = ImageContent.url(url, mediaType: .jpeg)

        XCTAssertTrue(image.source.isURL)
        XCTAssertEqual(image.source.urlValue, url)
        XCTAssertEqual(image.mediaType, .jpeg)
        XCTAssertNil(image.detail)
    }

    func testImageContentFileReferenceConvenience() {
        let image = ImageContent.fileReference("files/abc123", mediaType: .webp, detail: .auto)

        XCTAssertTrue(image.source.isFileReference)
        XCTAssertEqual(image.source.fileReferenceId, "files/abc123")
        XCTAssertEqual(image.mediaType, .webp)
        XCTAssertEqual(image.detail, .auto)
    }

    func testImageContentMimeType() {
        let image = ImageContent.base64(Data(), mediaType: .png)
        XCTAssertEqual(image.mimeType, "image/png")
    }

    func testImageContentValidation() throws {
        let image = ImageContent.base64(Data(), mediaType: .jpeg)

        // Should pass for all providers that support images
        XCTAssertNoThrow(try image.validate(for: .anthropic))
        XCTAssertNoThrow(try image.validate(for: .openai))
        XCTAssertNoThrow(try image.validate(for: .gemini))
    }

    func testImageContentValidationGeminiOnly() throws {
        let image = ImageContent.base64(Data(), mediaType: .heic)

        // Should fail for Anthropic and OpenAI
        XCTAssertThrowsError(try image.validate(for: .anthropic))
        XCTAssertThrowsError(try image.validate(for: .openai))
        XCTAssertNoThrow(try image.validate(for: .gemini))
    }

    func testImageContentFileReferenceValidation() throws {
        let image = ImageContent.fileReference("files/abc", mediaType: .jpeg)

        // File reference not supported by Anthropic
        XCTAssertThrowsError(try image.validate(for: .anthropic)) { error in
            guard case MediaError.notSupportedByProvider(let feature, _) = error else {
                XCTFail("Expected notSupportedByProvider error")
                return
            }
            XCTAssertTrue(feature.contains("File reference"))
        }

        // OK for OpenAI and Gemini
        XCTAssertNoThrow(try image.validate(for: .openai))
        XCTAssertNoThrow(try image.validate(for: .gemini))
    }

    func testImageContentCodable() throws {
        let original = ImageContent.base64(Data("test".utf8), mediaType: .png, detail: .high)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ImageContent.self, from: encoded)

        XCTAssertEqual(original, decoded)
    }

    func testImageDetailAllCases() {
        XCTAssertEqual(ImageContent.ImageDetail.allCases.count, 3)
        XCTAssertTrue(ImageContent.ImageDetail.allCases.contains(.low))
        XCTAssertTrue(ImageContent.ImageDetail.allCases.contains(.high))
        XCTAssertTrue(ImageContent.ImageDetail.allCases.contains(.auto))
    }

    // MARK: - AudioContent Tests

    func testAudioContentInit() {
        let source = MediaSource.base64(Data("audio".utf8))
        let audio = AudioContent(source: source, mediaType: .wav)

        XCTAssertEqual(audio.source, source)
        XCTAssertEqual(audio.mediaType, .wav)
    }

    func testAudioContentBase64Convenience() {
        let data = Data("audio data".utf8)
        let audio = AudioContent.base64(data, mediaType: .mp3)

        XCTAssertTrue(audio.source.isBase64)
        XCTAssertEqual(audio.mediaType, .mp3)
    }

    func testAudioContentURLConvenience() {
        let url = URL(string: "https://example.com/audio.wav")!
        let audio = AudioContent.url(url, mediaType: .wav)

        XCTAssertTrue(audio.source.isURL)
        XCTAssertEqual(audio.mediaType, .wav)
    }

    func testAudioContentFileReferenceConvenience() {
        let audio = AudioContent.fileReference("files/audio123", mediaType: .flac)

        XCTAssertTrue(audio.source.isFileReference)
        XCTAssertEqual(audio.mediaType, .flac)
    }

    func testAudioContentMimeType() {
        let audio = AudioContent.base64(Data(), mediaType: .mp3)
        XCTAssertEqual(audio.mimeType, "audio/mp3")
    }

    func testAudioContentValidation() throws {
        let audio = AudioContent.base64(Data(), mediaType: .wav)

        // Should fail for Anthropic (no audio support)
        XCTAssertThrowsError(try audio.validate(for: .anthropic)) { error in
            guard case MediaError.notSupportedByProvider(let feature, _) = error else {
                XCTFail("Expected notSupportedByProvider error")
                return
            }
            XCTAssertTrue(feature.contains("Audio"))
        }

        // Should pass for OpenAI and Gemini
        XCTAssertNoThrow(try audio.validate(for: .openai))
        XCTAssertNoThrow(try audio.validate(for: .gemini))
    }

    func testAudioContentOpenAIURLValidation() throws {
        let audio = AudioContent.url(URL(string: "https://example.com/audio.wav")!, mediaType: .wav)

        // OpenAI only supports base64 for audio
        XCTAssertThrowsError(try audio.validate(for: .openai)) { error in
            guard case MediaError.notSupportedByProvider(let feature, _) = error else {
                XCTFail("Expected notSupportedByProvider error")
                return
            }
            XCTAssertTrue(feature.contains("URL"))
        }

        // Gemini accepts URLs
        XCTAssertNoThrow(try audio.validate(for: .gemini))
    }

    func testAudioContentOpenAIFormatValidation() throws {
        // FLAC not supported by OpenAI
        let audio = AudioContent.base64(Data(), mediaType: .flac)

        XCTAssertThrowsError(try audio.validate(for: .openai))
        XCTAssertNoThrow(try audio.validate(for: .gemini))
    }

    func testAudioContentCodable() throws {
        let original = AudioContent.base64(Data("audio".utf8), mediaType: .wav)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AudioContent.self, from: encoded)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - VideoContent Tests

    func testVideoContentInit() {
        let source = MediaSource.base64(Data("video".utf8))
        let video = VideoContent(source: source, mediaType: .mp4)

        XCTAssertEqual(video.source, source)
        XCTAssertEqual(video.mediaType, .mp4)
    }

    func testVideoContentBase64Convenience() {
        let data = Data("video data".utf8)
        let video = VideoContent.base64(data, mediaType: .mov)

        XCTAssertTrue(video.source.isBase64)
        XCTAssertEqual(video.mediaType, .mov)
    }

    func testVideoContentURLConvenience() {
        let url = URL(string: "https://example.com/video.mp4")!
        let video = VideoContent.url(url, mediaType: .mp4)

        XCTAssertTrue(video.source.isURL)
        XCTAssertEqual(video.mediaType, .mp4)
    }

    func testVideoContentFileReferenceConvenience() {
        let video = VideoContent.fileReference("files/video123", mediaType: .webm)

        XCTAssertTrue(video.source.isFileReference)
        XCTAssertEqual(video.mediaType, .webm)
    }

    func testVideoContentMimeType() {
        let video = VideoContent.base64(Data(), mediaType: .mp4)
        XCTAssertEqual(video.mimeType, "video/mp4")
    }

    func testVideoContentValidation() throws {
        let video = VideoContent.base64(Data(), mediaType: .mp4)

        // Should fail for Anthropic and OpenAI (no video support)
        XCTAssertThrowsError(try video.validate(for: .anthropic)) { error in
            guard case MediaError.notSupportedByProvider(let feature, _) = error else {
                XCTFail("Expected notSupportedByProvider error")
                return
            }
            XCTAssertTrue(feature.contains("Video"))
        }

        XCTAssertThrowsError(try video.validate(for: .openai))

        // Should pass for Gemini only
        XCTAssertNoThrow(try video.validate(for: .gemini))
    }

    func testVideoContentCodable() throws {
        let original = VideoContent.fileReference("files/video", mediaType: .mkv)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VideoContent.self, from: encoded)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - MediaContentProtocol Tests

    func testMediaContentProtocolConformance() {
        let image: any MediaContentProtocol = ImageContent.base64(Data(), mediaType: .jpeg)
        let audio: any MediaContentProtocol = AudioContent.base64(Data(), mediaType: .wav)
        let video: any MediaContentProtocol = VideoContent.base64(Data(), mediaType: .mp4)

        XCTAssertEqual(image.mimeType, "image/jpeg")
        XCTAssertEqual(audio.mimeType, "audio/wav")
        XCTAssertEqual(video.mimeType, "video/mp4")
    }

    // MARK: - Sendable Tests

    func testMediaContentSendable() {
        let image = ImageContent.base64(Data(), mediaType: .png)
        let audio = AudioContent.base64(Data(), mediaType: .wav)
        let video = VideoContent.base64(Data(), mediaType: .mp4)

        Task {
            _ = image
            _ = audio
            _ = video
        }

        XCTAssertTrue(true)  // If this compiles, Sendable conformance works
    }

    // MARK: - Equatable Tests

    func testImageContentEquality() {
        let data = Data("test".utf8)

        let image1 = ImageContent.base64(data, mediaType: .jpeg, detail: .high)
        let image2 = ImageContent.base64(data, mediaType: .jpeg, detail: .high)
        let image3 = ImageContent.base64(data, mediaType: .jpeg, detail: .low)
        let image4 = ImageContent.base64(data, mediaType: .png, detail: .high)

        XCTAssertEqual(image1, image2)
        XCTAssertNotEqual(image1, image3)  // Different detail
        XCTAssertNotEqual(image1, image4)  // Different mediaType
    }

    func testAudioContentEquality() {
        let data = Data("audio".utf8)

        let audio1 = AudioContent.base64(data, mediaType: .wav)
        let audio2 = AudioContent.base64(data, mediaType: .wav)
        let audio3 = AudioContent.base64(data, mediaType: .mp3)

        XCTAssertEqual(audio1, audio2)
        XCTAssertNotEqual(audio1, audio3)
    }

    func testVideoContentEquality() {
        let data = Data("video".utf8)

        let video1 = VideoContent.base64(data, mediaType: .mp4)
        let video2 = VideoContent.base64(data, mediaType: .mp4)
        let video3 = VideoContent.base64(data, mediaType: .mov)

        XCTAssertEqual(video1, video2)
        XCTAssertNotEqual(video1, video3)
    }
}
