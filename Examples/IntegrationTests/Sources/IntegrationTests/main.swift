import Foundation
import LLMStructuredOutputs

// MARK: - Environment Configuration

enum Config {
    static var anthropicKey: String? {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
    }
    static var openAIKey: String? {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
    }
    static var geminiKey: String? {
        ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
    }

    static func loadEnvFile() {
        let envPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".env")

        guard let contents = try? String(contentsOf: envPath, encoding: .utf8) else {
            return
        }

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            var value = String(parts[1]).trimmingCharacters(in: .whitespaces)

            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }

            setenv(key, value, 1)
        }
    }
}

// MARK: - Test Runner

actor TestRunner {
    private var passedTests = 0
    private var failedTests = 0
    private var skippedTests = 0

    func recordPass() { passedTests += 1 }
    func recordFail() { failedTests += 1 }
    func recordSkip() { skippedTests += 1 }

    func summary() -> (passed: Int, failed: Int, skipped: Int) {
        (passedTests, failedTests, skippedTests)
    }
}

func printHeader(_ title: String) {
    print("\n" + String(repeating: "=", count: 60))
    print(title)
    print(String(repeating: "=", count: 60))
}

func printTestStart(_ name: String) {
    print("\n🧪 Testing: \(name)")
    print("   " + String(repeating: "-", count: 50))
}

// MARK: - Image Generation Tests

@MainActor
func runImageGenerationTests(runner: TestRunner) async {
    printHeader("🖼️  IMAGE GENERATION TESTS")

    guard let apiKey = Config.openAIKey, !apiKey.isEmpty else {
        print("⚠️  OPENAI_API_KEY not set - skipping image generation tests")
        await runner.recordSkip()
        return
    }

    let client = OpenAIClient(apiKey: apiKey)

    // Test 1: Basic Image Generation with DALL-E 3
    printTestStart("DALL-E 3 Basic Generation")
    do {
        let image = try await client.generateImage(
            prompt: "A simple red circle on white background",
            model: .dalle3,
            size: .square1024,
            quality: .standard,
            format: .png,
            n: 1
        )

        print("   ✅ PASSED")
        print("   Format: \(image.format.rawValue)")
        print("   Size: \(image.data.count) bytes")
        print("   MIME Type: \(image.mimeType)")
        if let revised = image.revisedPrompt {
            print("   Revised Prompt: \(revised.prefix(80))...")
        }
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }

    // Test 2: HD Quality Image
    printTestStart("DALL-E 3 HD Quality")
    do {
        let image = try await client.generateImage(
            prompt: "A minimalist blue square",
            model: .dalle3,
            size: .square1024,
            quality: .hd,
            format: .png,
            n: 1
        )

        print("   ✅ PASSED")
        print("   Format: \(image.format.rawValue)")
        print("   Size: \(image.data.count) bytes")
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }

    // Test 3: Portrait Size
    printTestStart("DALL-E 3 Portrait Size (1024x1792)")
    do {
        let image = try await client.generateImage(
            prompt: "A vertical green line",
            model: .dalle3,
            size: .portrait1024x1792,
            quality: .standard,
            format: .png,
            n: 1
        )

        print("   ✅ PASSED")
        print("   Size: \(image.data.count) bytes")
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }

    // Test 4: Landscape Size
    printTestStart("DALL-E 3 Landscape Size (1792x1024)")
    do {
        let image = try await client.generateImage(
            prompt: "A horizontal purple line",
            model: .dalle3,
            size: .landscape1792x1024,
            quality: .standard,
            format: .png,
            n: 1
        )

        print("   ✅ PASSED")
        print("   Size: \(image.data.count) bytes")
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }

    // Test 5: DALL-E 2 (Multiple Images)
    printTestStart("DALL-E 2 Multiple Images (n=2)")
    do {
        let images = try await client.generateImages(
            prompt: "A simple yellow triangle",
            model: .dalle2,
            size: .square1024,
            quality: nil,
            format: .png,
            n: 2
        )

        print("   ✅ PASSED")
        print("   Generated: \(images.count) images")
        for (i, img) in images.enumerated() {
            print("   Image \(i+1): \(img.data.count) bytes")
        }
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }
}

// MARK: - Gemini Image Generation Tests

@MainActor
func runGeminiImageGenerationTests(runner: TestRunner) async {
    printHeader("🖼️  GEMINI IMAGE GENERATION TESTS")

    guard let apiKey = Config.geminiKey, !apiKey.isEmpty else {
        print("⚠️  GEMINI_API_KEY not set - skipping Gemini image generation tests")
        await runner.recordSkip()
        return
    }

    let client = GeminiClient(apiKey: apiKey)

    // Test 1: Gemini 2.0 Flash Image (generateContent API)
    printTestStart("Gemini 2.0 Flash Image Generation")
    do {
        let image = try await client.generateImage(
            prompt: "A simple red circle on white background",
            model: .gemini20FlashImage,
            size: .square1024,
            quality: nil,
            format: .png,
            n: 1
        )

        print("   ✅ PASSED")
        print("   Format: \(image.format.rawValue)")
        print("   Size: \(image.data.count) bytes")
        print("   MIME Type: \(image.mimeType)")
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }

    // Test 2: Imagen 4 (predict API)
    printTestStart("Imagen 4 Basic Generation")
    do {
        let image = try await client.generateImage(
            prompt: "A simple blue square",
            model: .imagen4,
            size: .square1024,
            quality: nil,
            format: .png,
            n: 1
        )

        print("   ✅ PASSED")
        print("   Format: \(image.format.rawValue)")
        print("   Size: \(image.data.count) bytes")
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }

    // Test 3: Imagen 4 Fast
    printTestStart("Imagen 4 Fast Generation")
    do {
        let image = try await client.generateImage(
            prompt: "A horizontal green line",
            model: .imagen4Fast,
            size: .square1024,
            quality: nil,
            format: .png,
            n: 1
        )

        print("   ✅ PASSED")
        print("   Size: \(image.data.count) bytes")
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }

    // Test 4: Imagen 4 Ultra
    printTestStart("Imagen 4 Ultra Generation")
    do {
        let image = try await client.generateImage(
            prompt: "A vertical purple line",
            model: .imagen4Ultra,
            size: .square1024,
            quality: nil,
            format: .png,
            n: 1
        )

        print("   ✅ PASSED")
        print("   Size: \(image.data.count) bytes")
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }
}

// MARK: - Speech Generation Tests

@MainActor
func runSpeechGenerationTests(runner: TestRunner) async {
    printHeader("🔊 SPEECH GENERATION (TTS) TESTS")

    guard let apiKey = Config.openAIKey, !apiKey.isEmpty else {
        print("⚠️  OPENAI_API_KEY not set - skipping speech generation tests")
        await runner.recordSkip()
        return
    }

    let client = OpenAIClient(apiKey: apiKey)

    // Test 1: Basic TTS with TTS-1
    printTestStart("TTS-1 Basic Generation (MP3)")
    do {
        let audio = try await client.generateSpeech(
            text: "Hello, this is a test.",
            model: .tts1,
            voice: .alloy,
            speed: 1.0,
            format: .mp3
        )

        print("   ✅ PASSED")
        print("   Format: \(audio.format.rawValue)")
        print("   Size: \(audio.data.count) bytes")
        print("   MIME Type: \(audio.mimeType)")
        if let duration = audio.estimatedDuration {
            print("   Estimated Duration: \(String(format: "%.1f", duration)) seconds")
        }
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }

    // Test 2: TTS-1 HD
    printTestStart("TTS-1 HD Generation (MP3)")
    do {
        let audio = try await client.generateSpeech(
            text: "This is high quality audio.",
            model: .tts1HD,
            voice: .nova,
            speed: 1.0,
            format: .mp3
        )

        print("   ✅ PASSED")
        print("   Format: \(audio.format.rawValue)")
        print("   Size: \(audio.data.count) bytes")
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }

    // Test 3: Different Voices
    printTestStart("All Voices Test")
    let voices: [OpenAIVoice] = [.alloy, .echo, .fable, .onyx, .nova, .shimmer]

    for voice in voices {
        do {
            let audio = try await client.generateSpeech(
                text: "Test",
                model: .tts1,
                voice: voice,
                speed: 1.0,
                format: .mp3
            )
            print("   ✅ \(voice.displayName): \(audio.data.count) bytes")
        } catch {
            print("   ❌ \(voice.displayName): \(error)")
            await runner.recordFail()
        }
    }
    await runner.recordPass()

    // Test 4: Speed Variations
    printTestStart("Speed Variations")
    let speeds: [Double] = [0.5, 1.0, 1.5, 2.0]

    for speed in speeds {
        do {
            let audio = try await client.generateSpeech(
                text: "Speed test",
                model: .tts1,
                voice: .alloy,
                speed: speed,
                format: .mp3
            )
            print("   ✅ Speed \(speed)x: \(audio.data.count) bytes")
        } catch {
            print("   ❌ Speed \(speed)x: \(error)")
            await runner.recordFail()
        }
    }
    await runner.recordPass()

    // Test 5: Different Formats
    printTestStart("Output Format Test")
    let formats: [AudioOutputFormat] = [.mp3, .wav, .opus, .aac, .flac]

    for format in formats {
        do {
            let audio = try await client.generateSpeech(
                text: "Format test",
                model: .tts1,
                voice: .alloy,
                speed: 1.0,
                format: format
            )
            print("   ✅ \(format.rawValue.uppercased()): \(audio.data.count) bytes")
        } catch {
            print("   ❌ \(format.rawValue.uppercased()): \(error)")
            await runner.recordFail()
        }
    }
    await runner.recordPass()

    // Test 6: Japanese Text
    printTestStart("Japanese Text TTS")
    do {
        let audio = try await client.generateSpeech(
            text: "こんにちは、世界！これはテストです。",
            model: .tts1HD,
            voice: .nova,
            speed: 1.0,
            format: .mp3
        )

        print("   ✅ PASSED")
        print("   Size: \(audio.data.count) bytes")
        print("   Transcript: \(audio.transcript ?? "N/A")")
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }

    // Test 7: Long Text
    printTestStart("Long Text TTS")
    let longText = """
    The quick brown fox jumps over the lazy dog. This is a longer text to test the text-to-speech API. \
    We want to verify that longer texts are processed correctly without any issues. \
    The API should handle this text efficiently and return high-quality audio output.
    """
    do {
        let audio = try await client.generateSpeech(
            text: longText,
            model: .tts1,
            voice: .echo,
            speed: 1.0,
            format: .mp3
        )

        print("   ✅ PASSED")
        print("   Text Length: \(longText.count) chars")
        print("   Audio Size: \(audio.data.count) bytes")
        if let duration = audio.estimatedDuration {
            print("   Estimated Duration: \(String(format: "%.1f", duration)) seconds")
        }
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }

    // Test 8: Edge Case - Empty Text (should fail)
    printTestStart("Error Handling - Empty Text")
    do {
        _ = try await client.generateSpeech(
            text: "",
            model: .tts1,
            voice: .alloy,
            speed: 1.0,
            format: .mp3
        )
        print("   ❌ FAILED: Should have thrown an error")
        await runner.recordFail()
    } catch let error as SpeechGenerationError {
        print("   ✅ PASSED: Correctly threw error")
        print("   Error: \(error.errorDescription ?? "Unknown")")
        await runner.recordPass()
    } catch {
        print("   ✅ PASSED: Threw error (different type)")
        print("   Error: \(error)")
        await runner.recordPass()
    }

    // Test 9: Edge Case - Invalid Speed (should fail)
    printTestStart("Error Handling - Invalid Speed")
    do {
        _ = try await client.generateSpeech(
            text: "Test",
            model: .tts1,
            voice: .alloy,
            speed: 10.0,  // Invalid: max is 4.0
            format: .mp3
        )
        print("   ❌ FAILED: Should have thrown an error")
        await runner.recordFail()
    } catch let error as SpeechGenerationError {
        print("   ✅ PASSED: Correctly threw error")
        print("   Error: \(error.errorDescription ?? "Unknown")")
        await runner.recordPass()
    } catch {
        print("   ✅ PASSED: Threw error (different type)")
        print("   Error: \(error)")
        await runner.recordPass()
    }
}

// MARK: - Video Generation Model Tests (No API calls)

@MainActor
func runVideoModelTests(runner: TestRunner) async {
    printHeader("🎬 VIDEO GENERATION MODEL TESTS (Local)")

    // Test OpenAI Video Models (Sora 2)
    printTestStart("OpenAIVideoModel Properties - Sora 2")
    let sora2Model = OpenAIVideoModel.sora2
    print("   Model ID: \(sora2Model.id)")
    print("   Display Name: \(sora2Model.displayName)")
    print("   Max Duration: \(sora2Model.maxDuration) seconds")
    print("   Supported Durations: \(sora2Model.supportedDurations)")
    print("   Supported Aspect Ratios: \(sora2Model.supportedAspectRatios.map { $0.rawValue })")
    print("   Supported Resolutions: \(sora2Model.supportedResolutions.map { $0.rawValue })")
    print("   Default Resolution: \(sora2Model.defaultResolution.rawValue)")
    print("   ✅ PASSED")
    await runner.recordPass()

    // Test OpenAI Video Models (Sora 2 Pro)
    printTestStart("OpenAIVideoModel Properties - Sora 2 Pro")
    let sora2ProModel = OpenAIVideoModel.sora2Pro
    print("   Model ID: \(sora2ProModel.id)")
    print("   Display Name: \(sora2ProModel.displayName)")
    print("   Max Duration: \(sora2ProModel.maxDuration) seconds")
    print("   Supported Durations: \(sora2ProModel.supportedDurations)")
    print("   Supported Aspect Ratios: \(sora2ProModel.supportedAspectRatios.map { $0.rawValue })")
    print("   Supported Resolutions: \(sora2ProModel.supportedResolutions.map { $0.rawValue })")
    print("   Default Resolution: \(sora2ProModel.defaultResolution.rawValue)")
    print("   ✅ PASSED")
    await runner.recordPass()

    // Test Gemini Video Models (Veo)
    printTestStart("GeminiVideoModel Properties - All Models")
    for veoModel in GeminiVideoModel.allCases {
        print("   \(veoModel.displayName):")
        print("     ID: \(veoModel.id)")
        print("     Max Duration: \(veoModel.maxDuration)s")
        print("     Resolutions: \(veoModel.supportedResolutions.map { $0.rawValue })")
    }
    print("   ✅ PASSED")
    await runner.recordPass()

    // Test Video Generation Status
    printTestStart("VideoGenerationStatus")
    let statuses: [VideoGenerationStatus] = [.queued, .processing, .completed, .failed, .cancelled]
    for status in statuses {
        let isTerminal = status.isTerminal
        let isSuccessful = status.isSuccessful
        print("   \(status.rawValue): isTerminal=\(isTerminal), isSuccessful=\(isSuccessful)")
    }
    print("   ✅ PASSED")
    await runner.recordPass()

    // Test Video Aspect Ratios
    printTestStart("VideoAspectRatio")
    let ratios: [VideoAspectRatio] = [.landscape16x9, .portrait9x16, .square1x1, .cinematic21x9]
    for ratio in ratios {
        print("   \(ratio.rawValue): widthRatio=\(ratio.widthRatio), heightRatio=\(ratio.heightRatio)")
    }
    print("   ✅ PASSED")
    await runner.recordPass()

    // Test Video Resolutions
    printTestStart("VideoResolution")
    let resolutions: [VideoResolution] = [.hd720p, .fhd1080p, .uhd4k]
    for res in resolutions {
        print("   \(res.rawValue): \(res.width)x\(res.height)")
    }
    print("   ✅ PASSED")
    await runner.recordPass()
}

// MARK: - Video Generation API Tests

@MainActor
func runVideoGenerationTests(runner: TestRunner) async {
    printHeader("🎬 VIDEO GENERATION API TESTS (OpenAI Sora 2)")
    print("⚠️  Note: Video generation is expensive and time-consuming (1-3 minutes)")

    guard let apiKey = Config.openAIKey, !apiKey.isEmpty else {
        print("⚠️  OPENAI_API_KEY not set - skipping video generation tests")
        await runner.recordSkip()
        return
    }

    let client = OpenAIClient(apiKey: apiKey)

    // Test 1: Start Video Generation Job
    printTestStart("Sora 2 - Start Video Generation Job")
    do {
        let job = try await client.startVideoGeneration(
            prompt: "A simple animation of a red ball bouncing on a white floor",
            model: .sora2,
            duration: 4,
            aspectRatio: .landscape16x9,
            resolution: .hd720p
        )

        print("   ✅ Job Started")
        print("   Job ID: \(job.id)")
        print("   Status: \(job.status.rawValue)")
        print("   Prompt: \(job.prompt.prefix(50))...")

        // Poll for completion (with timeout)
        print("   Polling for completion...")
        var currentJob = job
        let startTime = Date()
        let timeout: TimeInterval = 180  // 3 minutes

        while !currentJob.status.isTerminal {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > timeout {
                print("   ⚠️ Timeout after \(Int(elapsed)) seconds")
                break
            }

            try await Task.sleep(nanoseconds: 10_000_000_000)  // 10 seconds
            currentJob = try await client.checkVideoStatus(currentJob)
            print("   Status: \(currentJob.status.rawValue), Progress: \(currentJob.progress.map { String(format: "%.0f%%", $0 * 100) } ?? "N/A")")
        }

        if currentJob.status == .completed {
            print("   ✅ Video Generation Completed")

            // Download the video
            let video = try await client.getGeneratedVideo(currentJob)
            print("   Video Size: \(video.data.count) bytes")
            print("   Format: \(video.format.rawValue)")
            if let duration = video.duration {
                print("   Duration: \(duration) seconds")
            }
            await runner.recordPass()
        } else if currentJob.status == .failed {
            print("   ❌ FAILED: \(currentJob.errorMessage ?? "Unknown error")")
            await runner.recordFail()
        } else {
            print("   ⚠️ Job did not complete within timeout")
            await runner.recordSkip()
        }
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }
}

@MainActor
func runGeminiVideoGenerationTests(runner: TestRunner) async {
    printHeader("🎬 GEMINI VIDEO GENERATION API TESTS (Veo)")
    print("⚠️  Note: Video generation is expensive and time-consuming (1-3 minutes)")

    guard let apiKey = Config.geminiKey, !apiKey.isEmpty else {
        print("⚠️  GEMINI_API_KEY not set - skipping Gemini video generation tests")
        await runner.recordSkip()
        return
    }

    let client = GeminiClient(apiKey: apiKey)

    // Test 1: Start Video Generation Job with Veo 3.1 Fast
    printTestStart("Veo 3.1 Fast - Start Video Generation Job")
    do {
        let job = try await client.startVideoGeneration(
            prompt: "A simple animation of a blue sphere floating in space",
            model: .veo31Fast,
            duration: 4,
            aspectRatio: .landscape16x9,
            resolution: .hd720p
        )

        print("   ✅ Job Started")
        print("   Job ID: \(job.id)")
        print("   Status: \(job.status.rawValue)")
        print("   Prompt: \(job.prompt.prefix(50))...")

        // Poll for completion (with timeout)
        print("   Polling for completion...")
        var currentJob = job
        let startTime = Date()
        let timeout: TimeInterval = 180  // 3 minutes

        while !currentJob.status.isTerminal {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > timeout {
                print("   ⚠️ Timeout after \(Int(elapsed)) seconds")
                break
            }

            try await Task.sleep(nanoseconds: 10_000_000_000)  // 10 seconds
            currentJob = try await client.checkVideoStatus(currentJob)
            print("   Status: \(currentJob.status.rawValue), Progress: \(currentJob.progress.map { String(format: "%.0f%%", $0 * 100) } ?? "N/A")")
        }

        if currentJob.status == .completed {
            print("   ✅ Video Generation Completed")

            // Download the video
            let video = try await client.getGeneratedVideo(currentJob)
            print("   Video Size: \(video.data.count) bytes")
            print("   Format: \(video.format.rawValue)")
            if let duration = video.duration {
                print("   Duration: \(duration) seconds")
            }
            await runner.recordPass()
        } else if currentJob.status == .failed {
            print("   ❌ FAILED: \(currentJob.errorMessage ?? "Unknown error")")
            await runner.recordFail()
        } else {
            print("   ⚠️ Job did not complete within timeout")
            await runner.recordSkip()
        }
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }
}

// MARK: - Output Format Tests (Local)

@MainActor
func runOutputFormatTests(runner: TestRunner) async {
    printHeader("📁 OUTPUT FORMAT TESTS (Local)")

    // Image Output Formats
    printTestStart("ImageOutputFormat")
    let imageFormats: [ImageOutputFormat] = [.png, .jpeg, .webp]
    for format in imageFormats {
        print("   \(format.rawValue): mimeType=\(format.mimeType), ext=\(format.fileExtension)")
    }
    print("   ✅ PASSED")
    await runner.recordPass()

    // Audio Output Formats
    printTestStart("AudioOutputFormat")
    let audioFormats: [AudioOutputFormat] = [.mp3, .wav, .opus, .aac, .flac, .pcm]
    for format in audioFormats {
        print("   \(format.rawValue): mimeType=\(format.mimeType), ext=\(format.fileExtension)")
    }
    print("   ✅ PASSED")
    await runner.recordPass()

    // Video Output Formats
    printTestStart("VideoOutputFormat")
    let videoFormats: [VideoOutputFormat] = [.mp4]
    for format in videoFormats {
        print("   \(format.rawValue): mimeType=\(format.mimeType), ext=\(format.fileExtension)")
    }
    print("   ✅ PASSED")
    await runner.recordPass()

    // OpenAI Supported Formats
    printTestStart("OpenAI Format Compatibility")
    print("   Image Formats: \(ImageOutputFormat.openaiFormats.map { $0.rawValue })")
    print("   Audio Formats: \(AudioOutputFormat.openaiFormats.map { $0.rawValue })")
    print("   ✅ PASSED")
    await runner.recordPass()

    // Gemini Supported Formats
    printTestStart("Gemini Format Compatibility")
    print("   Image Formats: \(ImageOutputFormat.geminiFormats.map { $0.rawValue })")
    print("   Audio Formats: \(AudioOutputFormat.geminiFormats.map { $0.rawValue })")
    print("   ✅ PASSED")
    await runner.recordPass()
}

// MARK: - Vision (Image Input) Tests

/// 画像分析結果
@Structured("画像分析結果")
struct ImageAnalysis {
    @StructuredField("画像の主な色")
    var dominantColor: String

    @StructuredField("画像に含まれる主な形状")
    var mainShape: String

    @StructuredField("画像の簡単な説明")
    var description: String
}

/// 色の分析結果
@Structured("色の分析")
struct ColorResponse {
    @StructuredField("検出された色")
    var color: String
}

@MainActor
func runVisionTests(runner: TestRunner) async {
    printHeader("👁️  VISION (IMAGE INPUT) TESTS")

    guard let apiKey = Config.openAIKey, !apiKey.isEmpty else {
        print("⚠️  OPENAI_API_KEY not set - skipping vision tests")
        await runner.recordSkip()
        return
    }

    let client = OpenAIClient(apiKey: apiKey)

    // Test 1: 生成した画像を分析
    printTestStart("Analyze Generated Image")
    do {
        // まず簡単な画像を生成
        print("   Generating test image...")
        let generatedImage = try await client.generateImage(
            prompt: "A solid blue square on white background, simple geometric shape",
            model: .dalle3,
            size: .square1024,
            quality: .standard,
            format: .png,
            n: 1
        )
        print("   Image generated: \(generatedImage.data.count) bytes")

        // 生成した画像を分析
        print("   Analyzing image with Vision...")
        let imageContent = ImageContent.base64(generatedImage.data, mediaType: .png)
        let message = LLMMessage.user("この画像を分析してください。主な色、形状、簡単な説明を教えてください。", image: imageContent)

        let analysis: ImageAnalysis = try await client.generate(
            messages: [message],
            model: .gpt4o,
            systemPrompt: "画像を分析し、指定されたJSON形式で回答してください。"
        )

        print("   ✅ PASSED")
        print("   Dominant Color: \(analysis.dominantColor)")
        print("   Main Shape: \(analysis.mainShape)")
        print("   Description: \(analysis.description.prefix(100))...")
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }

    // Test 2: URL画像を分析
    printTestStart("Analyze Image from URL")
    do {
        // OpenAI の公開ロゴ画像を使用
        let imageURL = URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4d/OpenAI_Logo.svg/200px-OpenAI_Logo.svg.png")!
        let imageContent = ImageContent.url(imageURL, mediaType: .png)
        let message = LLMMessage.user("この画像に何が写っていますか？会社のロゴですか？色と形を説明してください。", image: imageContent)

        let analysis: ImageAnalysis = try await client.generate(
            messages: [message],
            model: .gpt4o,
            systemPrompt: "画像を分析し、指定されたJSON形式で回答してください。"
        )

        print("   ✅ PASSED")
        print("   Dominant Color: \(analysis.dominantColor)")
        print("   Main Shape: \(analysis.mainShape)")
        print("   Description: \(analysis.description.prefix(100))...")
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }

    // Test 3: デバッグ - リクエスト内容を確認
    printTestStart("Debug: Check Request Content")
    do {
        // 小さなテスト画像を作成（赤い1x1ピクセルのPNG）
        // PNG header + IHDR + IDAT + IEND
        let redPixelPNG = Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,  // PNG signature
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,  // IHDR chunk
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,  // 1x1 pixels
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,  // 8-bit RGB
            0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,  // IDAT chunk
            0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,  // Red pixel data
            0x00, 0x00, 0x03, 0x00, 0x01, 0x00, 0x18, 0xDD,
            0x8D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,  // IEND chunk
            0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
        ])

        let imageContent = ImageContent.base64(redPixelPNG, mediaType: .png)
        let message = LLMMessage.user("What color is this image? Answer with just the color name.", image: imageContent)

        print("   Image size: \(redPixelPNG.count) bytes")
        print("   Base64 length: \(redPixelPNG.base64EncodedString().count) characters")
        print("   MIME type: \(imageContent.mimeType)")

        // メッセージ構造を確認
        print("   Message has media: \(message.hasMediaContent)")
        print("   Message has image: \(message.hasImage)")
        print("   Number of images: \(message.images.count)")

        // API呼び出し
        let response: ColorResponse = try await client.generate(
            messages: [message],
            model: .gpt4o
        )

        print("   ✅ PASSED")
        print("   Detected color: \(response.color)")
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }
}

// MARK: - Anthropic Vision Tests

@MainActor
func runAnthropicVisionTests(runner: TestRunner) async {
    printHeader("👁️  ANTHROPIC VISION (IMAGE INPUT) TESTS")

    guard let apiKey = Config.anthropicKey, !apiKey.isEmpty else {
        print("⚠️  ANTHROPIC_API_KEY not set - skipping Anthropic vision tests")
        await runner.recordSkip()
        return
    }

    let client = AnthropicClient(apiKey: apiKey)

    // Test 1: Analyze image from URL
    printTestStart("Anthropic Vision - URL Image")
    do {
        let imageURL = URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4d/OpenAI_Logo.svg/200px-OpenAI_Logo.svg.png")!
        let imageContent = ImageContent.url(imageURL, mediaType: .png)
        let message = LLMMessage.user("この画像に何が写っていますか？色と形を簡潔に説明してください。", image: imageContent)

        let analysis: ImageAnalysis = try await client.generate(
            messages: [message],
            model: .sonnet,
            systemPrompt: "画像を分析し、指定されたJSON形式で回答してください。"
        )

        print("   ✅ PASSED")
        print("   Dominant Color: \(analysis.dominantColor)")
        print("   Main Shape: \(analysis.mainShape)")
        print("   Description: \(analysis.description.prefix(100))...")
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }

    // Test 2: Analyze base64 image
    printTestStart("Anthropic Vision - Base64 Image")
    do {
        // 小さなテスト画像（赤いピクセル）
        let redPixelPNG = Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
            0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
            0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
            0x00, 0x00, 0x03, 0x00, 0x01, 0x00, 0x18, 0xDD,
            0x8D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
            0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
        ])

        let imageContent = ImageContent.base64(redPixelPNG, mediaType: .png)
        let message = LLMMessage.user("What color is this image? Answer with just the color name.", image: imageContent)

        let response: ColorResponse = try await client.generate(
            messages: [message],
            model: .sonnet
        )

        print("   ✅ PASSED")
        print("   Detected color: \(response.color)")
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }
}

// MARK: - Gemini Vision Tests

@MainActor
func runGeminiVisionTests(runner: TestRunner) async {
    printHeader("👁️  GEMINI VISION (IMAGE INPUT) TESTS")

    guard let apiKey = Config.geminiKey, !apiKey.isEmpty else {
        print("⚠️  GEMINI_API_KEY not set - skipping Gemini vision tests")
        await runner.recordSkip()
        return
    }

    let client = GeminiClient(apiKey: apiKey)

    // Test 1: Analyze image from URL
    printTestStart("Gemini Vision - URL Image")
    do {
        let imageURL = URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4d/OpenAI_Logo.svg/200px-OpenAI_Logo.svg.png")!
        let imageContent = ImageContent.url(imageURL, mediaType: .png)
        let message = LLMMessage.user("この画像に何が写っていますか？色と形を簡潔に説明してください。", image: imageContent)

        let analysis: ImageAnalysis = try await client.generate(
            messages: [message],
            model: .flash25,
            systemPrompt: "画像を分析し、指定されたJSON形式で回答してください。"
        )

        print("   ✅ PASSED")
        print("   Dominant Color: \(analysis.dominantColor)")
        print("   Main Shape: \(analysis.mainShape)")
        print("   Description: \(analysis.description.prefix(100))...")
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }

    // Test 2: Analyze base64 image
    printTestStart("Gemini Vision - Base64 Image")
    do {
        // 小さなテスト画像（赤いピクセル）
        let redPixelPNG = Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
            0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
            0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
            0x00, 0x00, 0x03, 0x00, 0x01, 0x00, 0x18, 0xDD,
            0x8D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
            0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
        ])

        let imageContent = ImageContent.base64(redPixelPNG, mediaType: .png)
        let message = LLMMessage.user("What color is this image? Answer with just the color name.", image: imageContent)

        let response: ColorResponse = try await client.generate(
            messages: [message],
            model: .flash25
        )

        print("   ✅ PASSED")
        print("   Detected color: \(response.color)")
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }
}

// MARK: - Main Entry Point

print("""

╔══════════════════════════════════════════════════════════════╗
║     MULTIMODAL API INTEGRATION TESTS                         ║
║     Image Generation, Speech Generation, Vision, Video       ║
║     OpenAI, Anthropic, Gemini Provider Tests                 ║
╚══════════════════════════════════════════════════════════════╝
""")

// Load .env file if present
Config.loadEnvFile()

// Check API keys
print("\n📋 API Key Status:")
print("   ANTHROPIC_API_KEY: \(Config.anthropicKey != nil ? "✅ Set" : "❌ Not set")")
print("   OPENAI_API_KEY: \(Config.openAIKey != nil ? "✅ Set" : "❌ Not set")")
print("   GEMINI_API_KEY: \(Config.geminiKey != nil ? "✅ Set" : "❌ Not set")")

let runner = TestRunner()

// Run local tests (no API calls)
await runOutputFormatTests(runner: runner)
await runVideoModelTests(runner: runner)

// Run OpenAI API tests
await runImageGenerationTests(runner: runner)
await runSpeechGenerationTests(runner: runner)
await runVisionTests(runner: runner)

// Run Gemini API tests
await runGeminiImageGenerationTests(runner: runner)
await runGeminiVisionTests(runner: runner)

// Run Anthropic API tests
await runAnthropicVisionTests(runner: runner)

// Run Video Generation API tests (expensive, run last)
// Note: These tests are time-consuming and costly, uncomment to run
// await runVideoGenerationTests(runner: runner)
// await runGeminiVideoGenerationTests(runner: runner)

// Print summary
let summary = await runner.summary()
print("\n" + String(repeating: "=", count: 60))
print("📊 TEST SUMMARY")
print(String(repeating: "=", count: 60))
print("   ✅ Passed:  \(summary.passed)")
print("   ❌ Failed:  \(summary.failed)")
print("   ⏭️  Skipped: \(summary.skipped)")
print(String(repeating: "=", count: 60))

if summary.failed > 0 {
    print("\n⚠️  Some tests failed. Check the output above for details.")
} else if summary.passed > 0 {
    print("\n🎉 All executed tests passed!")
} else {
    print("\n⚠️  No tests were executed. Set OPENAI_API_KEY to run API tests.")
}
print("")
