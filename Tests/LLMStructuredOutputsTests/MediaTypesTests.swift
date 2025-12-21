import XCTest
@testable import LLMStructuredOutputs
@testable import LLMClient

final class MediaTypesTests: XCTestCase {

    // MARK: - ImageMediaType Tests

    func testImageMediaTypeRawValues() {
        XCTAssertEqual(ImageMediaType.jpeg.rawValue, "image/jpeg")
        XCTAssertEqual(ImageMediaType.png.rawValue, "image/png")
        XCTAssertEqual(ImageMediaType.gif.rawValue, "image/gif")
        XCTAssertEqual(ImageMediaType.webp.rawValue, "image/webp")
        XCTAssertEqual(ImageMediaType.heic.rawValue, "image/heic")
        XCTAssertEqual(ImageMediaType.heif.rawValue, "image/heif")
    }

    func testImageMediaTypeFileExtensions() {
        XCTAssertEqual(ImageMediaType.jpeg.fileExtension, "jpg")
        XCTAssertEqual(ImageMediaType.png.fileExtension, "png")
        XCTAssertEqual(ImageMediaType.gif.fileExtension, "gif")
        XCTAssertEqual(ImageMediaType.webp.fileExtension, "webp")
        XCTAssertEqual(ImageMediaType.heic.fileExtension, "heic")
        XCTAssertEqual(ImageMediaType.heif.fileExtension, "heif")
    }

    func testImageMediaTypeMimeType() {
        XCTAssertEqual(ImageMediaType.jpeg.mimeType, "image/jpeg")
        XCTAssertEqual(ImageMediaType.png.mimeType, "image/png")
    }

    func testImageMediaTypeUniversalTypes() {
        let universalTypes = ImageMediaType.universalTypes
        XCTAssertTrue(universalTypes.contains(.jpeg))
        XCTAssertTrue(universalTypes.contains(.png))
        XCTAssertTrue(universalTypes.contains(.gif))
        XCTAssertTrue(universalTypes.contains(.webp))
        XCTAssertFalse(universalTypes.contains(.heic))
        XCTAssertFalse(universalTypes.contains(.heif))
    }

    func testImageMediaTypeGeminiOnlyTypes() {
        let geminiOnlyTypes = ImageMediaType.geminiOnlyTypes
        XCTAssertTrue(geminiOnlyTypes.contains(.heic))
        XCTAssertTrue(geminiOnlyTypes.contains(.heif))
        XCTAssertFalse(geminiOnlyTypes.contains(.jpeg))
    }

    func testImageMediaTypeProviderSupport() {
        // Universal types
        XCTAssertTrue(ImageMediaType.jpeg.isSupported(by: .anthropic))
        XCTAssertTrue(ImageMediaType.jpeg.isSupported(by: .openai))
        XCTAssertTrue(ImageMediaType.jpeg.isSupported(by: .gemini))

        XCTAssertTrue(ImageMediaType.png.isSupported(by: .anthropic))
        XCTAssertTrue(ImageMediaType.png.isSupported(by: .openai))
        XCTAssertTrue(ImageMediaType.png.isSupported(by: .gemini))

        // Gemini-only types
        XCTAssertFalse(ImageMediaType.heic.isSupported(by: .anthropic))
        XCTAssertFalse(ImageMediaType.heic.isSupported(by: .openai))
        XCTAssertTrue(ImageMediaType.heic.isSupported(by: .gemini))

        XCTAssertFalse(ImageMediaType.heif.isSupported(by: .anthropic))
        XCTAssertFalse(ImageMediaType.heif.isSupported(by: .openai))
        XCTAssertTrue(ImageMediaType.heif.isSupported(by: .gemini))
    }

    func testImageMediaTypeFromFileExtension() {
        XCTAssertEqual(ImageMediaType.from(fileExtension: "jpg"), .jpeg)
        XCTAssertEqual(ImageMediaType.from(fileExtension: "jpeg"), .jpeg)
        XCTAssertEqual(ImageMediaType.from(fileExtension: "JPG"), .jpeg)  // Case insensitive
        XCTAssertEqual(ImageMediaType.from(fileExtension: "png"), .png)
        XCTAssertEqual(ImageMediaType.from(fileExtension: "gif"), .gif)
        XCTAssertEqual(ImageMediaType.from(fileExtension: "webp"), .webp)
        XCTAssertEqual(ImageMediaType.from(fileExtension: "heic"), .heic)
        XCTAssertEqual(ImageMediaType.from(fileExtension: "heif"), .heif)
        XCTAssertNil(ImageMediaType.from(fileExtension: "bmp"))  // Unsupported
    }

    // MARK: - AudioMediaType Tests

    func testAudioMediaTypeRawValues() {
        XCTAssertEqual(AudioMediaType.wav.rawValue, "audio/wav")
        XCTAssertEqual(AudioMediaType.mp3.rawValue, "audio/mp3")
        XCTAssertEqual(AudioMediaType.aac.rawValue, "audio/aac")
        XCTAssertEqual(AudioMediaType.flac.rawValue, "audio/flac")
        XCTAssertEqual(AudioMediaType.ogg.rawValue, "audio/ogg")
        XCTAssertEqual(AudioMediaType.aiff.rawValue, "audio/aiff")
    }

    func testAudioMediaTypeFileExtensions() {
        XCTAssertEqual(AudioMediaType.wav.fileExtension, "wav")
        XCTAssertEqual(AudioMediaType.mp3.fileExtension, "mp3")
        XCTAssertEqual(AudioMediaType.aac.fileExtension, "aac")
        XCTAssertEqual(AudioMediaType.flac.fileExtension, "flac")
        XCTAssertEqual(AudioMediaType.ogg.fileExtension, "ogg")
        XCTAssertEqual(AudioMediaType.aiff.fileExtension, "aiff")
    }

    func testAudioMediaTypeOpenAIChatTypes() {
        let openaiTypes = AudioMediaType.openaiChatTypes
        XCTAssertEqual(openaiTypes.count, 2)
        XCTAssertTrue(openaiTypes.contains(.wav))
        XCTAssertTrue(openaiTypes.contains(.mp3))
        XCTAssertFalse(openaiTypes.contains(.flac))
    }

    func testAudioMediaTypeProviderSupport() {
        // Anthropic does not support audio
        XCTAssertFalse(AudioMediaType.wav.isSupported(by: .anthropic))
        XCTAssertFalse(AudioMediaType.mp3.isSupported(by: .anthropic))

        // OpenAI supports wav and mp3 only
        XCTAssertTrue(AudioMediaType.wav.isSupported(by: .openai))
        XCTAssertTrue(AudioMediaType.mp3.isSupported(by: .openai))
        XCTAssertFalse(AudioMediaType.flac.isSupported(by: .openai))
        XCTAssertFalse(AudioMediaType.aac.isSupported(by: .openai))

        // Gemini supports all audio types
        XCTAssertTrue(AudioMediaType.wav.isSupported(by: .gemini))
        XCTAssertTrue(AudioMediaType.mp3.isSupported(by: .gemini))
        XCTAssertTrue(AudioMediaType.flac.isSupported(by: .gemini))
        XCTAssertTrue(AudioMediaType.aiff.isSupported(by: .gemini))
    }

    func testAudioMediaTypeFromFileExtension() {
        XCTAssertEqual(AudioMediaType.from(fileExtension: "wav"), .wav)
        XCTAssertEqual(AudioMediaType.from(fileExtension: "mp3"), .mp3)
        XCTAssertEqual(AudioMediaType.from(fileExtension: "aac"), .aac)
        XCTAssertEqual(AudioMediaType.from(fileExtension: "m4a"), .aac)  // m4a maps to aac
        XCTAssertEqual(AudioMediaType.from(fileExtension: "flac"), .flac)
        XCTAssertEqual(AudioMediaType.from(fileExtension: "ogg"), .ogg)
        XCTAssertEqual(AudioMediaType.from(fileExtension: "oga"), .ogg)  // oga maps to ogg
        XCTAssertEqual(AudioMediaType.from(fileExtension: "aiff"), .aiff)
        XCTAssertEqual(AudioMediaType.from(fileExtension: "aif"), .aiff)  // aif maps to aiff
        XCTAssertNil(AudioMediaType.from(fileExtension: "wma"))  // Unsupported
    }

    // MARK: - VideoMediaType Tests

    func testVideoMediaTypeRawValues() {
        XCTAssertEqual(VideoMediaType.mp4.rawValue, "video/mp4")
        XCTAssertEqual(VideoMediaType.avi.rawValue, "video/avi")
        XCTAssertEqual(VideoMediaType.mov.rawValue, "video/quicktime")
        XCTAssertEqual(VideoMediaType.mkv.rawValue, "video/x-matroska")
        XCTAssertEqual(VideoMediaType.webm.rawValue, "video/webm")
        XCTAssertEqual(VideoMediaType.flv.rawValue, "video/x-flv")
        XCTAssertEqual(VideoMediaType.mpeg.rawValue, "video/mpeg")
        XCTAssertEqual(VideoMediaType.threegpp.rawValue, "video/3gpp")
        XCTAssertEqual(VideoMediaType.wmv.rawValue, "video/x-ms-wmv")
    }

    func testVideoMediaTypeFileExtensions() {
        XCTAssertEqual(VideoMediaType.mp4.fileExtension, "mp4")
        XCTAssertEqual(VideoMediaType.avi.fileExtension, "avi")
        XCTAssertEqual(VideoMediaType.mov.fileExtension, "mov")
        XCTAssertEqual(VideoMediaType.mkv.fileExtension, "mkv")
        XCTAssertEqual(VideoMediaType.webm.fileExtension, "webm")
        XCTAssertEqual(VideoMediaType.flv.fileExtension, "flv")
        XCTAssertEqual(VideoMediaType.mpeg.fileExtension, "mpeg")
        XCTAssertEqual(VideoMediaType.threegpp.fileExtension, "3gp")
        XCTAssertEqual(VideoMediaType.wmv.fileExtension, "wmv")
    }

    func testVideoMediaTypeProviderSupport() {
        // Only Gemini supports video input
        XCTAssertFalse(VideoMediaType.mp4.isSupported(by: .anthropic))
        XCTAssertFalse(VideoMediaType.mp4.isSupported(by: .openai))
        XCTAssertTrue(VideoMediaType.mp4.isSupported(by: .gemini))

        // All video types supported by Gemini
        for videoType in VideoMediaType.allCases {
            XCTAssertTrue(videoType.isSupported(by: .gemini))
            XCTAssertFalse(videoType.isSupported(by: .anthropic))
            XCTAssertFalse(videoType.isSupported(by: .openai))
        }
    }

    func testVideoMediaTypeFromFileExtension() {
        XCTAssertEqual(VideoMediaType.from(fileExtension: "mp4"), .mp4)
        XCTAssertEqual(VideoMediaType.from(fileExtension: "m4v"), .mp4)  // m4v maps to mp4
        XCTAssertEqual(VideoMediaType.from(fileExtension: "avi"), .avi)
        XCTAssertEqual(VideoMediaType.from(fileExtension: "mov"), .mov)
        XCTAssertEqual(VideoMediaType.from(fileExtension: "mkv"), .mkv)
        XCTAssertEqual(VideoMediaType.from(fileExtension: "webm"), .webm)
        XCTAssertEqual(VideoMediaType.from(fileExtension: "flv"), .flv)
        XCTAssertEqual(VideoMediaType.from(fileExtension: "mpeg"), .mpeg)
        XCTAssertEqual(VideoMediaType.from(fileExtension: "mpg"), .mpeg)  // mpg maps to mpeg
        XCTAssertEqual(VideoMediaType.from(fileExtension: "3gp"), .threegpp)
        XCTAssertEqual(VideoMediaType.from(fileExtension: "3gpp"), .threegpp)
        XCTAssertEqual(VideoMediaType.from(fileExtension: "wmv"), .wmv)
        XCTAssertNil(VideoMediaType.from(fileExtension: "rm"))  // Unsupported
    }

    // MARK: - ProviderType Tests

    func testProviderTypeRawValues() {
        XCTAssertEqual(ProviderType.anthropic.rawValue, "anthropic")
        XCTAssertEqual(ProviderType.openai.rawValue, "openai")
        XCTAssertEqual(ProviderType.gemini.rawValue, "gemini")
    }

    func testProviderTypeDisplayNames() {
        XCTAssertEqual(ProviderType.anthropic.displayName, "Anthropic")
        XCTAssertEqual(ProviderType.openai.displayName, "OpenAI")
        XCTAssertEqual(ProviderType.gemini.displayName, "Google Gemini")
    }

    // MARK: - MediaType Protocol Tests

    func testMediaTypeProtocolConformance() {
        // Test that all types conform to MediaType protocol
        func testConformance<T: MediaType>(_ type: T) -> Bool {
            return !type.fileExtension.isEmpty && !type.mimeType.isEmpty
        }

        XCTAssertTrue(testConformance(ImageMediaType.jpeg))
        XCTAssertTrue(testConformance(AudioMediaType.wav))
        XCTAssertTrue(testConformance(VideoMediaType.mp4))
    }

    // MARK: - Codable Tests

    func testImageMediaTypeCodable() throws {
        let original = ImageMediaType.jpeg
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ImageMediaType.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    func testAudioMediaTypeCodable() throws {
        let original = AudioMediaType.mp3
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AudioMediaType.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    func testVideoMediaTypeCodable() throws {
        let original = VideoMediaType.mov
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VideoMediaType.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    func testProviderTypeCodable() throws {
        let original = ProviderType.gemini
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProviderType.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Sendable Tests

    func testMediaTypesSendable() {
        let imageType: ImageMediaType = .png
        let audioType: AudioMediaType = .wav
        let videoType: VideoMediaType = .mp4
        let providerType: ProviderType = .gemini

        Task {
            _ = imageType
            _ = audioType
            _ = videoType
            _ = providerType
        }

        XCTAssertTrue(true)  // If this compiles, Sendable conformance works
    }

    // MARK: - CaseIterable Tests

    func testImageMediaTypeCaseIterable() {
        XCTAssertEqual(ImageMediaType.allCases.count, 6)
    }

    func testAudioMediaTypeCaseIterable() {
        XCTAssertEqual(AudioMediaType.allCases.count, 6)
    }

    func testVideoMediaTypeCaseIterable() {
        XCTAssertEqual(VideoMediaType.allCases.count, 9)
    }
}
