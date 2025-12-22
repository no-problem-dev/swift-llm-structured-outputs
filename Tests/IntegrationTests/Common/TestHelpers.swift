// TestHelpers.swift
// swift-llm-structured-outputs
//
// インテグレーションテスト用のヘルパー関数とユーティリティ

import Foundation
import Testing
@testable import LLMStructuredOutputs

// MARK: - Test Output Helpers

/// テスト結果の詳細を出力
func logTestResult(_ message: String) {
    print("   \(message)")
}

/// テスト開始のログ出力
func logTestStart(_ testName: String) {
    print("\n🧪 Testing: \(testName)")
    print("   " + String(repeating: "-", count: 50))
}

/// セクションヘッダーの出力
func logSection(_ title: String) {
    print("\n" + String(repeating: "=", count: 60))
    print(title)
    print(String(repeating: "=", count: 60))
}

// MARK: - Image Test Helpers

/// テスト用の小さな PNG 画像データを生成
///
/// 赤い1x1ピクセルのPNG画像を返します。
/// Vision テストなどで使用できます。
func createTestImageData() -> Data {
    // 赤い1x1ピクセルのPNG
    Data([
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
}

// MARK: - Structured Response Types for Tests

/// 画像分析結果（Vision テスト用）
@Structured("画像分析結果")
struct ImageAnalysisResult {
    @StructuredField("画像の主な色")
    var dominantColor: String

    @StructuredField("画像に含まれる主な形状")
    var mainShape: String

    @StructuredField("画像の簡単な説明")
    var description: String
}

/// 色の分析結果（シンプルな Vision テスト用）
@Structured("色の分析")
struct ColorAnalysisResult {
    @StructuredField("検出された色")
    var color: String
}

// MARK: - Async Helpers

/// 指定秒数待機
func wait(seconds: TimeInterval) async throws {
    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
}

/// タイムアウト付きで非同期操作を実行
func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError(seconds: seconds)
        }

        guard let result = try await group.next() else {
            throw TimeoutError(seconds: seconds)
        }

        group.cancelAll()
        return result
    }
}

/// タイムアウトエラー
struct TimeoutError: Error, CustomStringConvertible {
    let seconds: TimeInterval

    var description: String {
        "Operation timed out after \(Int(seconds)) seconds"
    }
}

// MARK: - Video Generation Helpers

/// 動画生成ジョブをポーリングして完了を待機
func waitForVideoCompletion<Client: VideoGenerationCapable>(
    job: VideoGenerationJob,
    client: Client,
    timeout: TimeInterval = TestConfiguration.videoGenerationTimeout,
    pollingInterval: TimeInterval = TestConfiguration.videoPollingInterval
) async throws -> VideoGenerationJob {
    var currentJob = job
    let startTime = Date()

    while !currentJob.status.isTerminal {
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed > timeout {
            throw TimeoutError(seconds: timeout)
        }

        try await wait(seconds: pollingInterval)
        currentJob = try await client.checkVideoStatus(currentJob)

        let progressStr = currentJob.progress.map { String(format: "%.0f%%", $0 * 100) } ?? "N/A"
        logTestResult("Status: \(currentJob.status.rawValue), Progress: \(progressStr)")
    }

    return currentJob
}

// MARK: - Assertion Helpers

/// データサイズが妥当かどうかを検証
func assertValidDataSize(_ data: Data, minBytes: Int = 100, context: String = "") {
    #expect(data.count >= minBytes, "Data size too small\(context.isEmpty ? "" : ": \(context)")")
}

/// 画像データが有効かどうかを検証
func assertValidImageData(_ data: Data, context: String = "") {
    assertValidDataSize(data, minBytes: 100, context: context)

    // PNG または JPEG のマジックバイトをチェック
    let isPNG = data.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    let isJPEG = data.prefix(2) == Data([0xFF, 0xD8])
    let isWebP = data.prefix(4) == Data([0x52, 0x49, 0x46, 0x46]) // RIFF

    #expect(isPNG || isJPEG || isWebP, "Invalid image format\(context.isEmpty ? "" : ": \(context)")")
}

/// 音声データが有効かどうかを検証
func assertValidAudioData(_ data: Data, context: String = "") {
    assertValidDataSize(data, minBytes: 100, context: context)
}
