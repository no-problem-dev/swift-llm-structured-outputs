import XCTest
@testable import LLMStructuredOutputs
@testable import LLMClient

/// 生成メディア型のテスト
final class GeneratedMediaTests: XCTestCase {

    // MARK: - ImageOutputFormat Tests

    func testImageOutputFormatRawValues() {
        XCTAssertEqual(ImageOutputFormat.png.rawValue, "image/png")
        XCTAssertEqual(ImageOutputFormat.jpeg.rawValue, "image/jpeg")
        XCTAssertEqual(ImageOutputFormat.webp.rawValue, "image/webp")
    }

    func testImageOutputFormatFileExtensions() {
        XCTAssertEqual(ImageOutputFormat.png.fileExtension, "png")
        XCTAssertEqual(ImageOutputFormat.jpeg.fileExtension, "jpg")
        XCTAssertEqual(ImageOutputFormat.webp.fileExtension, "webp")
    }

    func testImageOutputFormatMimeType() {
        XCTAssertEqual(ImageOutputFormat.png.mimeType, "image/png")
        XCTAssertEqual(ImageOutputFormat.jpeg.mimeType, "image/jpeg")
        XCTAssertEqual(ImageOutputFormat.webp.mimeType, "image/webp")
    }

    func testImageOutputFormatProviderSupport() {
        // OpenAI supports all formats
        XCTAssertTrue(ImageOutputFormat.png.isSupported(by: .openai))
        XCTAssertTrue(ImageOutputFormat.jpeg.isSupported(by: .openai))
        XCTAssertTrue(ImageOutputFormat.webp.isSupported(by: .openai))

        // Gemini supports only PNG
        XCTAssertTrue(ImageOutputFormat.png.isSupported(by: .gemini))
        XCTAssertFalse(ImageOutputFormat.jpeg.isSupported(by: .gemini))
        XCTAssertFalse(ImageOutputFormat.webp.isSupported(by: .gemini))

        // Anthropic does not support image generation
        XCTAssertFalse(ImageOutputFormat.png.isSupported(by: .anthropic))
    }

    func testImageOutputFormatFromFileExtension() {
        XCTAssertEqual(ImageOutputFormat.from(fileExtension: "png"), .png)
        XCTAssertEqual(ImageOutputFormat.from(fileExtension: "jpg"), .jpeg)
        XCTAssertEqual(ImageOutputFormat.from(fileExtension: "jpeg"), .jpeg)
        XCTAssertEqual(ImageOutputFormat.from(fileExtension: "webp"), .webp)
        XCTAssertEqual(ImageOutputFormat.from(fileExtension: "PNG"), .png)  // Case insensitive
        XCTAssertNil(ImageOutputFormat.from(fileExtension: "bmp"))  // Unsupported
    }

    func testImageOutputFormatProviderLists() {
        XCTAssertEqual(ImageOutputFormat.openaiFormats.count, 3)
        XCTAssertEqual(ImageOutputFormat.geminiFormats.count, 1)
        XCTAssertTrue(ImageOutputFormat.geminiFormats.contains(.png))
    }

    // MARK: - AudioOutputFormat Tests

    func testAudioOutputFormatRawValues() {
        XCTAssertEqual(AudioOutputFormat.mp3.rawValue, "audio/mp3")
        XCTAssertEqual(AudioOutputFormat.wav.rawValue, "audio/wav")
        XCTAssertEqual(AudioOutputFormat.opus.rawValue, "audio/opus")
        XCTAssertEqual(AudioOutputFormat.aac.rawValue, "audio/aac")
        XCTAssertEqual(AudioOutputFormat.flac.rawValue, "audio/flac")
        XCTAssertEqual(AudioOutputFormat.pcm.rawValue, "audio/pcm")
    }

    func testAudioOutputFormatFileExtensions() {
        XCTAssertEqual(AudioOutputFormat.mp3.fileExtension, "mp3")
        XCTAssertEqual(AudioOutputFormat.wav.fileExtension, "wav")
        XCTAssertEqual(AudioOutputFormat.opus.fileExtension, "opus")
        XCTAssertEqual(AudioOutputFormat.aac.fileExtension, "aac")
        XCTAssertEqual(AudioOutputFormat.flac.fileExtension, "flac")
        XCTAssertEqual(AudioOutputFormat.pcm.fileExtension, "pcm")
    }

    func testAudioOutputFormatProviderSupport() {
        // OpenAI supports all TTS formats
        XCTAssertTrue(AudioOutputFormat.mp3.isSupported(by: .openai))
        XCTAssertTrue(AudioOutputFormat.wav.isSupported(by: .openai))
        XCTAssertTrue(AudioOutputFormat.opus.isSupported(by: .openai))
        XCTAssertTrue(AudioOutputFormat.aac.isSupported(by: .openai))
        XCTAssertTrue(AudioOutputFormat.flac.isSupported(by: .openai))
        XCTAssertTrue(AudioOutputFormat.pcm.isSupported(by: .openai))

        // Gemini supports only PCM
        XCTAssertTrue(AudioOutputFormat.pcm.isSupported(by: .gemini))
        XCTAssertFalse(AudioOutputFormat.mp3.isSupported(by: .gemini))

        // Anthropic does not support audio generation
        XCTAssertFalse(AudioOutputFormat.mp3.isSupported(by: .anthropic))
    }

    func testAudioOutputFormatFromFileExtension() {
        XCTAssertEqual(AudioOutputFormat.from(fileExtension: "mp3"), .mp3)
        XCTAssertEqual(AudioOutputFormat.from(fileExtension: "wav"), .wav)
        XCTAssertEqual(AudioOutputFormat.from(fileExtension: "opus"), .opus)
        XCTAssertEqual(AudioOutputFormat.from(fileExtension: "aac"), .aac)
        XCTAssertEqual(AudioOutputFormat.from(fileExtension: "m4a"), .aac)  // m4a maps to aac
        XCTAssertEqual(AudioOutputFormat.from(fileExtension: "flac"), .flac)
        XCTAssertEqual(AudioOutputFormat.from(fileExtension: "pcm"), .pcm)
        XCTAssertEqual(AudioOutputFormat.from(fileExtension: "raw"), .pcm)  // raw maps to pcm
        XCTAssertNil(AudioOutputFormat.from(fileExtension: "wma"))  // Unsupported
    }

    // MARK: - VideoOutputFormat Tests

    func testVideoOutputFormatRawValues() {
        XCTAssertEqual(VideoOutputFormat.mp4.rawValue, "video/mp4")
    }

    func testVideoOutputFormatFileExtensions() {
        XCTAssertEqual(VideoOutputFormat.mp4.fileExtension, "mp4")
    }

    func testVideoOutputFormatProviderSupport() {
        // OpenAI and Gemini support video generation
        XCTAssertTrue(VideoOutputFormat.mp4.isSupported(by: .openai))
        XCTAssertTrue(VideoOutputFormat.mp4.isSupported(by: .gemini))

        // Anthropic does not support video generation
        XCTAssertFalse(VideoOutputFormat.mp4.isSupported(by: .anthropic))
    }

    func testVideoOutputFormatFromFileExtension() {
        XCTAssertEqual(VideoOutputFormat.from(fileExtension: "mp4"), .mp4)
        XCTAssertEqual(VideoOutputFormat.from(fileExtension: "m4v"), .mp4)  // m4v maps to mp4
        XCTAssertNil(VideoOutputFormat.from(fileExtension: "avi"))  // Not a supported output format
    }

    // MARK: - GeneratedImage Tests

    func testGeneratedImageInitialization() {
        let data = Data([0x89, 0x50, 0x4E, 0x47])  // PNG magic bytes
        let image = GeneratedImage(data: data, format: .png, revisedPrompt: "A cat")

        XCTAssertEqual(image.data, data)
        XCTAssertEqual(image.format, .png)
        XCTAssertEqual(image.revisedPrompt, "A cat")
        XCTAssertEqual(image.mimeType, "image/png")
        XCTAssertEqual(image.fileExtension, "png")
        XCTAssertEqual(image.dataSize, 4)
    }

    func testGeneratedImageBase64Initialization() throws {
        let originalData = Data([0x89, 0x50, 0x4E, 0x47])
        let base64String = originalData.base64EncodedString()

        let image = try GeneratedImage(base64String: base64String, format: .png)

        XCTAssertEqual(image.data, originalData)
        XCTAssertEqual(image.format, .png)
    }

    func testGeneratedImageBase64InitializationFailure() {
        XCTAssertThrowsError(try GeneratedImage(base64String: "invalid!", format: .png)) { error in
            guard case GeneratedMediaError.invalidBase64Data = error else {
                XCTFail("Expected invalidBase64Data error")
                return
            }
        }
    }

    func testGeneratedImageBase64String() {
        let data = Data([0x89, 0x50, 0x4E, 0x47])
        let image = GeneratedImage(data: data, format: .png)

        XCTAssertEqual(image.base64String, data.base64EncodedString())
    }

    func testGeneratedImageDataURL() {
        let data = Data([0x89, 0x50, 0x4E, 0x47])
        let image = GeneratedImage(data: data, format: .png)
        let expectedDataURL = "data:image/png;base64,\(data.base64EncodedString())"

        XCTAssertEqual(image.dataURL, expectedDataURL)
    }

    func testGeneratedImageSuggestedFileName() {
        let image = GeneratedImage(data: Data(), format: .jpeg)

        XCTAssertEqual(image.suggestedFileName(), "generated.jpg")
        XCTAssertEqual(image.suggestedFileName(baseName: "cat"), "cat.jpg")
    }

    func testGeneratedImageCodable() throws {
        let data = Data([0x89, 0x50, 0x4E, 0x47])
        let original = GeneratedImage(data: data, format: .png, revisedPrompt: "Test prompt")

        let encoder = JSONEncoder()
        let encoded = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GeneratedImage.self, from: encoded)

        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.data, data)
        XCTAssertEqual(decoded.format, .png)
        XCTAssertEqual(decoded.revisedPrompt, "Test prompt")
    }

    // MARK: - GeneratedAudio Tests

    func testGeneratedAudioInitialization() {
        let data = Data([0x49, 0x44, 0x33])  // ID3 tag header
        let audio = GeneratedAudio(
            data: data,
            format: .mp3,
            transcript: "Hello, world!",
            id: "audio_123",
            expiresAt: Date()
        )

        XCTAssertEqual(audio.data, data)
        XCTAssertEqual(audio.format, .mp3)
        XCTAssertEqual(audio.transcript, "Hello, world!")
        XCTAssertEqual(audio.id, "audio_123")
        XCTAssertNotNil(audio.expiresAt)
        XCTAssertEqual(audio.mimeType, "audio/mp3")
        XCTAssertEqual(audio.fileExtension, "mp3")
    }

    func testGeneratedAudioBase64Initialization() throws {
        let originalData = Data([0x49, 0x44, 0x33])
        let base64String = originalData.base64EncodedString()

        let audio = try GeneratedAudio(base64String: base64String, format: .mp3)

        XCTAssertEqual(audio.data, originalData)
        XCTAssertEqual(audio.format, .mp3)
    }

    func testGeneratedAudioIsExpired() {
        let futureDate = Date().addingTimeInterval(3600)  // 1 hour from now
        let pastDate = Date().addingTimeInterval(-3600)  // 1 hour ago

        let notExpiredAudio = GeneratedAudio(data: Data(), format: .mp3, expiresAt: futureDate)
        let expiredAudio = GeneratedAudio(data: Data(), format: .mp3, expiresAt: pastDate)
        let noExpirationAudio = GeneratedAudio(data: Data(), format: .mp3)

        XCTAssertFalse(notExpiredAudio.isExpired)
        XCTAssertTrue(expiredAudio.isExpired)
        XCTAssertFalse(noExpirationAudio.isExpired)
    }

    func testGeneratedAudioEstimatedDuration() {
        // 128 kbps MP3, 16000 bytes = ~1 second
        let mp3Data = Data(count: 16000)
        let mp3Audio = GeneratedAudio(data: mp3Data, format: .mp3)
        XCTAssertNotNil(mp3Audio.estimatedDuration)
        XCTAssertEqual(mp3Audio.estimatedDuration!, 1.0, accuracy: 0.1)

        // PCM 24kHz 16-bit mono, 48000 bytes = 1 second
        let pcmData = Data(count: 48000)
        let pcmAudio = GeneratedAudio(data: pcmData, format: .pcm)
        XCTAssertNotNil(pcmAudio.estimatedDuration)
        XCTAssertEqual(pcmAudio.estimatedDuration!, 1.0, accuracy: 0.1)
    }

    func testGeneratedAudioCodable() throws {
        let data = Data([0x49, 0x44, 0x33])
        let original = GeneratedAudio(
            data: data,
            format: .mp3,
            transcript: "Test",
            id: "id_123"
        )

        let encoder = JSONEncoder()
        let encoded = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GeneratedAudio.self, from: encoded)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - VideoGenerationStatus Tests

    func testVideoGenerationStatusTerminal() {
        XCTAssertFalse(VideoGenerationStatus.queued.isTerminal)
        XCTAssertFalse(VideoGenerationStatus.processing.isTerminal)
        XCTAssertTrue(VideoGenerationStatus.completed.isTerminal)
        XCTAssertTrue(VideoGenerationStatus.failed.isTerminal)
        XCTAssertTrue(VideoGenerationStatus.cancelled.isTerminal)
    }

    func testVideoGenerationStatusSuccessful() {
        XCTAssertFalse(VideoGenerationStatus.queued.isSuccessful)
        XCTAssertFalse(VideoGenerationStatus.processing.isSuccessful)
        XCTAssertTrue(VideoGenerationStatus.completed.isSuccessful)
        XCTAssertFalse(VideoGenerationStatus.failed.isSuccessful)
        XCTAssertFalse(VideoGenerationStatus.cancelled.isSuccessful)
    }

    // MARK: - VideoGenerationJob Tests

    func testVideoGenerationJobInitialization() {
        let job = VideoGenerationJob(
            id: "job_123",
            status: .queued,
            prompt: "A cat playing"
        )

        XCTAssertEqual(job.id, "job_123")
        XCTAssertEqual(job.status, .queued)
        XCTAssertEqual(job.prompt, "A cat playing")
        XCTAssertNil(job.videoURL)
        XCTAssertNil(job.errorMessage)
    }

    func testVideoGenerationJobUpdate() {
        let job = VideoGenerationJob(
            id: "job_123",
            status: .queued,
            prompt: "A cat playing"
        )

        let updatedJob = job.updated(
            status: .completed,
            videoURL: URL(string: "https://example.com/video.mp4")!
        )

        XCTAssertEqual(updatedJob.status, .completed)
        XCTAssertNotNil(updatedJob.videoURL)
        XCTAssertNotNil(updatedJob.completedAt)
        XCTAssertEqual(updatedJob.id, job.id)
    }

    func testVideoGenerationJobProgress() {
        var job = VideoGenerationJob(
            id: "job_123",
            status: .processing,
            prompt: "A cat playing"
        )

        // Simulate some time passing
        job = job.updated(status: .processing, progress: 0.5)

        XCTAssertEqual(job.progress, 0.5)
        XCTAssertNotNil(job.estimatedRemainingTime)
    }

    // MARK: - VideoResolution Tests

    func testVideoResolutionDimensions() {
        XCTAssertEqual(VideoResolution.sd480p.width, 854)
        XCTAssertEqual(VideoResolution.sd480p.height, 480)

        XCTAssertEqual(VideoResolution.hd720p.width, 1280)
        XCTAssertEqual(VideoResolution.hd720p.height, 720)

        XCTAssertEqual(VideoResolution.fhd1080p.width, 1920)
        XCTAssertEqual(VideoResolution.fhd1080p.height, 1080)

        XCTAssertEqual(VideoResolution.uhd4k.width, 3840)
        XCTAssertEqual(VideoResolution.uhd4k.height, 2160)
    }

    // MARK: - VideoAspectRatio Tests

    func testVideoAspectRatioOrientation() {
        XCTAssertTrue(VideoAspectRatio.landscape16x9.isLandscape)
        XCTAssertFalse(VideoAspectRatio.landscape16x9.isPortrait)

        XCTAssertFalse(VideoAspectRatio.portrait9x16.isLandscape)
        XCTAssertTrue(VideoAspectRatio.portrait9x16.isPortrait)

        XCTAssertFalse(VideoAspectRatio.square1x1.isLandscape)
        XCTAssertFalse(VideoAspectRatio.square1x1.isPortrait)
    }

    func testVideoAspectRatioRatios() {
        XCTAssertEqual(VideoAspectRatio.landscape16x9.widthRatio, 16)
        XCTAssertEqual(VideoAspectRatio.landscape16x9.heightRatio, 9)

        XCTAssertEqual(VideoAspectRatio.cinematic21x9.widthRatio, 21)
        XCTAssertEqual(VideoAspectRatio.cinematic21x9.heightRatio, 9)
    }

    // MARK: - GeneratedVideo Tests

    func testGeneratedVideoInitializationFromData() {
        let data = Data([0x00, 0x00, 0x00, 0x1C])  // MP4 ftyp header start
        let video = GeneratedVideo(
            data: data,
            format: .mp4,
            duration: 30.0,
            resolution: .hd720p
        )

        XCTAssertEqual(video.data, data)
        XCTAssertEqual(video.format, .mp4)
        XCTAssertEqual(video.duration, 30.0)
        XCTAssertEqual(video.resolution, .hd720p)
        XCTAssertTrue(video.hasLocalData)
    }

    func testGeneratedVideoInitializationFromURL() {
        let url = URL(string: "https://example.com/video.mp4")!
        let video = GeneratedVideo(
            remoteURL: url,
            format: .mp4,
            duration: 60.0
        )

        XCTAssertTrue(video.data.isEmpty)
        XCTAssertFalse(video.hasLocalData)
        XCTAssertEqual(video.remoteURL, url)
    }

    func testGeneratedVideoCodable() throws {
        let data = Data([0x00, 0x00, 0x00, 0x1C])
        let original = GeneratedVideo(
            data: data,
            format: .mp4,
            remoteURL: URL(string: "https://example.com/video.mp4"),
            duration: 30.0,
            resolution: .hd720p,
            jobId: "job_123",
            prompt: "A cat playing"
        )

        let encoder = JSONEncoder()
        let encoded = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GeneratedVideo.self, from: encoded)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - GeneratedMediaError Tests

    func testGeneratedMediaErrorDescriptions() {
        XCTAssertNotNil(GeneratedMediaError.invalidBase64Data.errorDescription)
        XCTAssertNotNil(GeneratedMediaError.invalidImageData.errorDescription)

        let saveError = GeneratedMediaError.saveError(NSError(domain: "test", code: 1))
        XCTAssertTrue(saveError.errorDescription?.contains("Failed to save") ?? false)

        let downloadError = GeneratedMediaError.downloadError(NSError(domain: "test", code: 2))
        XCTAssertTrue(downloadError.errorDescription?.contains("Failed to download") ?? false)
    }

    // MARK: - OutputMediaFormat Protocol Tests

    func testOutputMediaFormatProtocolConformance() {
        func testConformance<T: OutputMediaFormat>(_ format: T) -> Bool {
            return !format.fileExtension.isEmpty && !format.mimeType.isEmpty
        }

        XCTAssertTrue(testConformance(ImageOutputFormat.png))
        XCTAssertTrue(testConformance(AudioOutputFormat.mp3))
        XCTAssertTrue(testConformance(VideoOutputFormat.mp4))
    }

    // MARK: - CaseIterable Tests

    func testImageOutputFormatCaseIterable() {
        XCTAssertEqual(ImageOutputFormat.allCases.count, 3)
    }

    func testAudioOutputFormatCaseIterable() {
        XCTAssertEqual(AudioOutputFormat.allCases.count, 6)
    }

    func testVideoOutputFormatCaseIterable() {
        XCTAssertEqual(VideoOutputFormat.allCases.count, 1)
    }

    // MARK: - LLMResponse ContentBlock Tests

    func testLLMResponseContentBlockImage() {
        let image = GeneratedImage(data: Data([0x89, 0x50]), format: .png)
        let block = LLMResponse.ContentBlock.image(image)

        XCTAssertNil(block.text)
        XCTAssertNotNil(block.generatedImage)
        XCTAssertNil(block.generatedAudio)
        XCTAssertEqual(block.generatedImage?.format, .png)
    }

    func testLLMResponseContentBlockAudio() {
        let audio = GeneratedAudio(data: Data([0x49, 0x44]), format: .mp3)
        let block = LLMResponse.ContentBlock.audio(audio)

        XCTAssertNil(block.text)
        XCTAssertNil(block.generatedImage)
        XCTAssertNotNil(block.generatedAudio)
        XCTAssertEqual(block.generatedAudio?.format, .mp3)
    }

    func testLLMResponseMediaAccessors() {
        let image1 = GeneratedImage(data: Data([0x89, 0x50]), format: .png)
        let image2 = GeneratedImage(data: Data([0xFF, 0xD8]), format: .jpeg)
        let audio = GeneratedAudio(data: Data([0x49, 0x44]), format: .mp3)
        let text = "Hello, world!"

        let response = LLMResponse(
            content: [
                .text(text),
                .image(image1),
                .image(image2),
                .audio(audio)
            ],
            model: "test-model",
            usage: TokenUsage(inputTokens: 10, outputTokens: 20)
        )

        XCTAssertEqual(response.text, text)
        XCTAssertEqual(response.generatedImages.count, 2)
        XCTAssertEqual(response.firstGeneratedImage?.format, .png)
        XCTAssertEqual(response.generatedAudioFiles.count, 1)
        XCTAssertEqual(response.firstGeneratedAudio?.format, .mp3)
        XCTAssertTrue(response.hasImages)
        XCTAssertTrue(response.hasAudio)
        XCTAssertTrue(response.hasMedia)
    }

    func testLLMResponseNoMedia() {
        let response = LLMResponse(
            content: [.text("Just text")],
            model: "test-model",
            usage: TokenUsage(inputTokens: 5, outputTokens: 10)
        )

        XCTAssertEqual(response.generatedImages.count, 0)
        XCTAssertNil(response.firstGeneratedImage)
        XCTAssertEqual(response.generatedAudioFiles.count, 0)
        XCTAssertNil(response.firstGeneratedAudio)
        XCTAssertFalse(response.hasImages)
        XCTAssertFalse(response.hasAudio)
        XCTAssertFalse(response.hasMedia)
    }
}
