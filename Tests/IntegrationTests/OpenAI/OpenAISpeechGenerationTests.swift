// SpeechGenerationTests.swift
// swift-llm-structured-outputs
//
// OpenAI 音声生成 (TTS) のインテグレーションテスト

import Foundation
import Testing
@testable import LLMStructuredOutputs

@Suite("OpenAI Speech Generation", .tags(.integration, .openai, .speechGeneration))
struct OpenAISpeechGenerationTests {
    let client: OpenAIClient

    init() throws {
        let apiKey = try TestConfiguration.requireOpenAIKey()
        client = OpenAIClient(apiKey: apiKey)
    }

    // MARK: - Basic TTS Tests

    @Test("TTS-1 basic generation (MP3)")
    func testBasicGeneration() async throws {
        let audio = try await client.generateSpeech(
            input: "Hello, this is a test.",
            model: .tts1,
            voice: .alloy,
            speed: 1.0,
            format: .mp3
        )

        #expect(audio.data.count > 0)
        #expect(audio.format == .mp3)
        #expect(audio.mimeType == "audio/mpeg")
        assertValidAudioData(audio.data, context: "TTS-1 basic")
    }

    @Test("TTS-1 HD generation (MP3)")
    func testHDGeneration() async throws {
        let audio = try await client.generateSpeech(
            input: "This is high quality audio.",
            model: .tts1HD,
            voice: .nova,
            speed: 1.0,
            format: .mp3
        )

        #expect(audio.data.count > 0)
        assertValidAudioData(audio.data, context: "TTS-1 HD")
    }

    // MARK: - Voice Tests

    @Test("All voices generate audio", arguments: OpenAIVoice.allCases)
    func testAllVoices(voice: OpenAIVoice) async throws {
        let audio = try await client.generateSpeech(
            input: "Test",
            model: .tts1,
            voice: voice,
            speed: 1.0,
            format: .mp3
        )

        #expect(audio.data.count > 0, "Voice \(voice.displayName) should generate audio")
    }

    // MARK: - Speed Tests

    @Test("Speed variations", arguments: [0.5, 1.0, 1.5, 2.0])
    func testSpeedVariations(speed: Double) async throws {
        let audio = try await client.generateSpeech(
            input: "Speed test",
            model: .tts1,
            voice: .alloy,
            speed: speed,
            format: .mp3
        )

        #expect(audio.data.count > 0, "Speed \(speed)x should generate audio")
    }

    // MARK: - Format Tests

    @Test("Output format test", arguments: [AudioOutputFormat.mp3, .wav, .opus, .aac, .flac])
    func testOutputFormats(format: AudioOutputFormat) async throws {
        let audio = try await client.generateSpeech(
            input: "Format test",
            model: .tts1,
            voice: .alloy,
            speed: 1.0,
            format: format
        )

        #expect(audio.data.count > 0, "Format \(format.rawValue) should generate audio")
        #expect(audio.format == format)
    }

    // MARK: - Multilingual Tests

    @Test("Japanese text TTS")
    func testJapaneseText() async throws {
        let audio = try await client.generateSpeech(
            input: "こんにちは、世界！これはテストです。",
            model: .tts1HD,
            voice: .nova,
            speed: 1.0,
            format: .mp3
        )

        #expect(audio.data.count > 0)
        assertValidAudioData(audio.data, context: "Japanese TTS")
    }

    // MARK: - Long Text Tests

    @Test("Long text TTS")
    func testLongText() async throws {
        let longText = """
        The quick brown fox jumps over the lazy dog. This is a longer text to test the text-to-speech API. \
        We want to verify that longer texts are processed correctly without any issues. \
        The API should handle this text efficiently and return high-quality audio output.
        """

        let audio = try await client.generateSpeech(
            input: LLMInput(longText),
            model: .tts1,
            voice: .echo,
            speed: 1.0,
            format: .mp3
        )

        #expect(audio.data.count > 0)
        assertValidAudioData(audio.data, context: "Long text TTS")
    }

    // MARK: - Error Handling Tests

    @Test("Empty text should throw error")
    func testEmptyText() async throws {
        await #expect(throws: (any Error).self) {
            _ = try await client.generateSpeech(
                input: "",
                model: .tts1,
                voice: .alloy,
                speed: 1.0,
                format: .mp3
            )
        }
    }

    @Test("Invalid speed should throw error")
    func testInvalidSpeed() async throws {
        await #expect(throws: (any Error).self) {
            _ = try await client.generateSpeech(
                input: "Test",
                model: .tts1,
                voice: .alloy,
                speed: 10.0,  // Invalid: max is 4.0
                format: .mp3
            )
        }
    }
}
