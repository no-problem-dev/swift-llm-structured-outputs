// VideoGenerationTests.swift
// swift-llm-structured-outputs
//
// OpenAI 動画生成 (Sora 2) のインテグレーションテスト

import Foundation
import Testing
@testable import LLMStructuredOutputs

@Suite("OpenAI Video Generation (Sora 2)", .tags(.integration, .openai, .videoGeneration, .slow, .expensive))
struct OpenAIVideoGenerationTests {
    let client: OpenAIClient

    init() throws {
        let apiKey = try TestConfiguration.requireOpenAIKey()
        client = OpenAIClient(apiKey: apiKey)
    }

    // MARK: - Sora 2 Tests

    @Test("Sora 2 basic video generation (4 seconds)")
    func testBasicVideoGeneration() async throws {
        // ジョブを開始
        let job = try await client.startVideoGeneration(
            input: "A simple animation of a red ball bouncing on a white floor",
            model: .sora2,
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
        #expect(video.duration == 4.0)
    }

    @Test("Sora 2 portrait video (9:16)")
    func testPortraitVideo() async throws {
        let job = try await client.startVideoGeneration(
            input: "A simple vertical animation of falling leaves",
            model: .sora2,
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

    @Test("Sora 2 model properties")
    func testSora2ModelProperties() {
        let model = OpenAIVideoModel.sora2

        #expect(model.id == "sora-2")
        #expect(model.displayName == "Sora 2")
        #expect(model.maxDuration == 12)
        #expect(model.supportedDurations == [4, 8, 12])
        #expect(model.supportedAspectRatios == [.landscape16x9, .portrait9x16])
        #expect(model.supportedResolutions == [.hd720p])
        #expect(model.defaultResolution == .hd720p)
    }

    @Test("Sora 2 Pro model properties")
    func testSora2ProModelProperties() {
        let model = OpenAIVideoModel.sora2Pro

        #expect(model.id == "sora-2-pro")
        #expect(model.displayName == "Sora 2 Pro")
        #expect(model.maxDuration == 12)
        #expect(model.supportedResolutions == [.hd720p, .fhd1080p])
        #expect(model.defaultResolution == .fhd1080p)
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
}
