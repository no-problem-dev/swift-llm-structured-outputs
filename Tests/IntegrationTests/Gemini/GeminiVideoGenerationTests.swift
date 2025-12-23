// GeminiVideoGenerationTests.swift
// swift-llm-structured-outputs
//
// Gemini 動画生成 (Veo) のインテグレーションテスト

import Foundation
import Testing
@testable import LLMStructuredOutputs

@Suite("Gemini Video Generation (Veo)", .tags(.integration, .gemini, .videoGeneration, .slow, .expensive))
struct GeminiVideoGenerationTests {
    let client: GeminiClient

    init() throws {
        let apiKey = try TestConfiguration.requireGeminiKey()
        client = GeminiClient(apiKey: apiKey)
    }

    // MARK: - Veo 3.0 Tests

    @Test("Veo 3.0 basic video generation")
    func testBasicVideoGeneration() async throws {
        // ジョブを開始
        let job = try await client.startVideoGeneration(
            input: "A simple animation of a bouncing ball",
            model: .veo30,
            duration: 4,
            aspectRatio: .landscape16x9,
            resolution: .hd720p
        )

        #expect(!job.id.isEmpty)
        #expect(job.status == .queued || job.status == .processing)

        // 完了を待機
        let completedJob = try await waitForVideoCompletion(
            job: job,
            client: client,
            timeout: TestConfiguration.videoGenerationTimeout,
            pollingInterval: TestConfiguration.videoPollingInterval
        )

        #expect(completedJob.status == .completed)

        // 動画をダウンロード
        let video = try await client.getGeneratedVideo(completedJob)

        #expect(video.data.count > 0)
        #expect(video.format == .mp4)
    }

    @Test("Veo 3.0 Fast video generation")
    func testFastVideoGeneration() async throws {
        let job = try await client.startVideoGeneration(
            input: "A simple animation of falling leaves",
            model: .veo30Fast,
            duration: 4,
            aspectRatio: .landscape16x9,
            resolution: .hd720p
        )

        #expect(!job.id.isEmpty)

        let completedJob = try await waitForVideoCompletion(
            job: job,
            client: client
        )

        #expect(completedJob.status == .completed)

        let video = try await client.getGeneratedVideo(completedJob)
        #expect(video.data.count > 0)
    }

    @Test("Veo 3.0 portrait video (9:16)")
    func testPortraitVideo() async throws {
        let job = try await client.startVideoGeneration(
            input: "A simple vertical animation of falling rain",
            model: .veo30Fast,
            duration: 4,
            aspectRatio: .portrait9x16,
            resolution: .hd720p
        )

        #expect(!job.id.isEmpty)

        let completedJob = try await waitForVideoCompletion(
            job: job,
            client: client
        )

        #expect(completedJob.status == .completed)

        let video = try await client.getGeneratedVideo(completedJob)
        #expect(video.data.count > 0)
    }

    // MARK: - Model Properties Tests (No API Call)

    @Test("Veo 3.1 model properties")
    func testVeo31ModelProperties() {
        let model = GeminiVideoModel.veo31

        #expect(model.id == "veo-3.1-generate-preview")
        #expect(model.displayName == "Veo 3.1")
        #expect(model.maxDuration == 8)
        #expect(model.supportedDurations == [4, 6, 8])
        #expect(model.supportedAspectRatios.contains(.landscape16x9))
        #expect(model.supportedAspectRatios.contains(.portrait9x16))
        #expect(model.supportedResolutions.contains(.hd720p))
        #expect(model.supportedResolutions.contains(.fhd1080p))
    }

    @Test("Veo 3.0 model properties")
    func testVeo30ModelProperties() {
        let model = GeminiVideoModel.veo30

        #expect(model.id == "veo-3.0-generate-001")
        #expect(model.displayName == "Veo 3.0")
        #expect(model.maxDuration == 8)
        #expect(model.supportedDurations == [4, 6, 8])
        #expect(model.supportedResolutions.contains(.hd720p))
        #expect(model.supportedResolutions.contains(.fhd1080p))
    }

    @Test("Veo 2.0 model properties")
    func testVeo20ModelProperties() {
        let model = GeminiVideoModel.veo20

        #expect(model.id == "veo-2.0-generate-001")
        #expect(model.displayName == "Veo 2.0")
        #expect(model.maxDuration == 8)
        #expect(model.supportedDurations == [5, 6, 8])  // Veo 2.0 は 5-8 秒
        #expect(model.supportedResolutions == [.hd720p])  // 720p のみ
    }

    // MARK: - Video Generation Status Tests (No API Call)

    @Test("Video generation status properties")
    func testVideoGenerationStatus() {
        // Terminal states
        #expect(VideoGenerationStatus.completed.isTerminal == true)
        #expect(VideoGenerationStatus.failed.isTerminal == true)
        #expect(VideoGenerationStatus.cancelled.isTerminal == true)

        // Non-terminal states
        #expect(VideoGenerationStatus.queued.isTerminal == false)
        #expect(VideoGenerationStatus.processing.isTerminal == false)

        // Successful state
        #expect(VideoGenerationStatus.completed.isSuccessful == true)
        #expect(VideoGenerationStatus.failed.isSuccessful == false)
    }

    // MARK: - Error Handling Tests

    @Test("Unsupported duration should throw error")
    func testUnsupportedDuration() async throws {
        await #expect(throws: (any Error).self) {
            _ = try await client.startVideoGeneration(
                input: "A test video",
                model: .veo30,
                duration: 60,  // Not supported
                aspectRatio: .landscape16x9,
                resolution: .hd720p
            )
        }
    }

    @Test("Unsupported resolution should throw error")
    func testUnsupportedResolution() async throws {
        await #expect(throws: (any Error).self) {
            _ = try await client.startVideoGeneration(
                input: "A test video",
                model: .veo20,
                duration: 5,
                aspectRatio: .landscape16x9,
                resolution: .fhd1080p  // Veo 2.0 は 720p のみ
            )
        }
    }
}
