// VideoGeneration.swift
// swift-llm-structured-outputs
//
// 動画生成機能のプロトコルと関連型

import Foundation

// MARK: - VideoGenerationCapable Protocol

/// 動画生成機能を持つクライアントのプロトコル
///
/// 動画生成は非同期ジョブとして処理されます。
/// ジョブを開始し、ステータスをポーリングして完了を待ちます。
///
/// ## 使用例
/// ```swift
/// // 動画生成ジョブを開始
/// let job = try await client.startVideoGeneration(
///     prompt: "A cat playing with a ball in slow motion",
///     model: .sora
/// )
///
/// // ステータスをポーリング
/// var currentJob = job
/// while !currentJob.status.isTerminal {
///     try await Task.sleep(nanoseconds: 5_000_000_000)  // 5秒
///     currentJob = try await client.checkVideoStatus(currentJob)
/// }
///
/// // 動画を取得
/// if currentJob.status.isSuccessful {
///     let video = try await client.getGeneratedVideo(currentJob)
///     try video.save(to: URL(fileURLWithPath: "output.mp4"))
/// }
/// ```
public protocol VideoGenerationCapable<VideoModel>: Sendable {
    /// 動画生成で使用可能なモデル型
    associatedtype VideoModel: Sendable

    /// 動画生成ジョブを開始
    ///
    /// - Parameters:
    ///   - prompt: 動画を説明するプロンプト
    ///   - model: 使用する動画生成モデル
    ///   - duration: 動画の長さ（秒）
    ///   - aspectRatio: アスペクト比
    ///   - resolution: 解像度
    /// - Returns: 生成ジョブ
    func startVideoGeneration(
        prompt: String,
        model: VideoModel,
        duration: Int?,
        aspectRatio: VideoAspectRatio?,
        resolution: VideoResolution?
    ) async throws -> VideoGenerationJob

    /// 動画生成ジョブのステータスを確認
    ///
    /// - Parameter job: 確認するジョブ
    /// - Returns: 更新されたジョブ
    func checkVideoStatus(_ job: VideoGenerationJob) async throws -> VideoGenerationJob

    /// 生成された動画を取得
    ///
    /// ジョブが完了（`status == .completed`）している場合のみ動画を取得できます。
    ///
    /// - Parameter job: 完了したジョブ
    /// - Returns: 生成された動画
    func getGeneratedVideo(_ job: VideoGenerationJob) async throws -> GeneratedVideo
}

// MARK: - Default Implementations

extension VideoGenerationCapable {
    /// 動画生成ジョブを開始（デフォルト引数付き）
    public func startVideoGeneration(
        prompt: String,
        model: VideoModel,
        duration: Int? = nil,
        aspectRatio: VideoAspectRatio? = nil,
        resolution: VideoResolution? = nil
    ) async throws -> VideoGenerationJob {
        try await startVideoGeneration(
            prompt: prompt,
            model: model,
            duration: duration,
            aspectRatio: aspectRatio,
            resolution: resolution
        )
    }

    /// 動画生成を実行し完了まで待機
    ///
    /// - Parameters:
    ///   - prompt: 動画を説明するプロンプト
    ///   - model: 使用する動画生成モデル
    ///   - duration: 動画の長さ（秒）
    ///   - aspectRatio: アスペクト比
    ///   - resolution: 解像度
    ///   - pollingInterval: ポーリング間隔（秒、デフォルト: 5）
    ///   - timeout: タイムアウト（秒、デフォルト: 600）
    /// - Returns: 生成された動画
    public func generateVideo(
        prompt: String,
        model: VideoModel,
        duration: Int? = nil,
        aspectRatio: VideoAspectRatio? = nil,
        resolution: VideoResolution? = nil,
        pollingInterval: TimeInterval = 5,
        timeout: TimeInterval = 600
    ) async throws -> GeneratedVideo {
        var job = try await startVideoGeneration(
            prompt: prompt,
            model: model,
            duration: duration,
            aspectRatio: aspectRatio,
            resolution: resolution
        )

        let startTime = Date()

        while !job.status.isTerminal {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > timeout {
                throw VideoGenerationError.timeout(elapsed: elapsed)
            }

            try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
            job = try await checkVideoStatus(job)
        }

        if job.status == .failed {
            throw VideoGenerationError.generationFailed(job.errorMessage ?? "Unknown error")
        }

        if job.status == .cancelled {
            throw VideoGenerationError.cancelled
        }

        return try await getGeneratedVideo(job)
    }
}

// MARK: - OpenAI Video Models

/// OpenAI 動画生成モデル（Sora 2）
///
/// Sora 2 は OpenAI の第2世代動画生成モデルです。
/// 2025年9月にリリースされ、API経由で利用可能です。
public enum OpenAIVideoModel: String, Sendable, Codable, CaseIterable, Equatable {
    /// Sora 2（標準版・高速）
    ///
    /// 高速な生成が可能で、プロトタイプやソーシャルメディア向けに最適。
    /// 解像度: 720p (1280x720)
    case sora2 = "sora-2"

    /// Sora 2 Pro（高品質版）
    ///
    /// より高品質な出力を生成。本番環境やマーケティング向けに最適。
    /// 解像度: 1080p (1792x1024)
    case sora2Pro = "sora-2-pro"

    /// モデル ID
    public var id: String { rawValue }

    /// 表示名
    public var displayName: String {
        switch self {
        case .sora2: return "Sora 2"
        case .sora2Pro: return "Sora 2 Pro"
        }
    }

    /// サポートされる動画長オプション（秒）
    public var supportedDurations: [Int] {
        [4, 8, 12]
    }

    /// サポートされる最大動画長（秒）
    public var maxDuration: Int { 12 }

    /// サポートされるアスペクト比
    public var supportedAspectRatios: [VideoAspectRatio] {
        [.landscape16x9, .portrait9x16]
    }

    /// サポートされる解像度
    public var supportedResolutions: [VideoResolution] {
        switch self {
        case .sora2:
            return [.hd720p]
        case .sora2Pro:
            return [.hd720p, .fhd1080p]
        }
    }

    /// デフォルト解像度
    public var defaultResolution: VideoResolution {
        switch self {
        case .sora2: return .hd720p
        case .sora2Pro: return .fhd1080p
        }
    }
}

// MARK: - Gemini Video Models

/// Gemini 動画生成モデル（Veo）
public enum GeminiVideoModel: String, Sendable, Codable, CaseIterable, Equatable {
    /// Veo 3.1（最新・高品質）
    case veo31 = "veo-3.1-generate-preview"
    /// Veo 3.1 Fast（高速版）
    case veo31Fast = "veo-3.1-fast-generate-preview"
    /// Veo 3.0（安定版）
    case veo30 = "veo-3.0-generate-001"
    /// Veo 3.0 Fast（高速版）
    case veo30Fast = "veo-3.0-fast-generate-001"
    /// Veo 2.0
    case veo20 = "veo-2.0-generate-001"

    /// モデル ID
    public var id: String { rawValue }

    /// 表示名
    public var displayName: String {
        switch self {
        case .veo31: return "Veo 3.1"
        case .veo31Fast: return "Veo 3.1 Fast"
        case .veo30: return "Veo 3.0"
        case .veo30Fast: return "Veo 3.0 Fast"
        case .veo20: return "Veo 2.0"
        }
    }

    /// サポートされる最大動画長（秒）
    public var maxDuration: Int { 8 }

    /// サポートされる動画長オプション
    public var supportedDurations: [Int] {
        switch self {
        case .veo31, .veo31Fast, .veo30, .veo30Fast:
            return [4, 6, 8]
        case .veo20:
            return [5, 6, 8]  // Veo 2.0 は 5-8 秒のみサポート
        }
    }

    /// サポートされるアスペクト比
    public var supportedAspectRatios: [VideoAspectRatio] {
        [.landscape16x9, .portrait9x16]
    }

    /// サポートされる解像度
    public var supportedResolutions: [VideoResolution] {
        switch self {
        case .veo31, .veo31Fast, .veo30, .veo30Fast:
            return [.hd720p, .fhd1080p]  // 1080pは8秒のみ
        case .veo20:
            return [.hd720p]
        }
    }
}

// MARK: - VideoGenerationError

/// 動画生成固有のエラー
public enum VideoGenerationError: Error, Sendable, LocalizedError {
    /// プロンプトが安全性ポリシーに違反
    case contentPolicyViolation(String?)
    /// 動画の長さが上限を超えている
    case durationExceedsLimit(requested: Int, maximum: Int)
    /// アスペクト比がサポートされていない
    case unsupportedAspectRatio(VideoAspectRatio, model: String)
    /// 解像度がサポートされていない
    case unsupportedResolution(VideoResolution, model: String)
    /// 生成に失敗
    case generationFailed(String)
    /// タイムアウト
    case timeout(elapsed: TimeInterval)
    /// キャンセルされた
    case cancelled
    /// ジョブが完了していない
    case jobNotCompleted(status: VideoGenerationStatus)
    /// 動画生成がこのプロバイダーでサポートされていない
    case notSupportedByProvider(String)

    public var errorDescription: String? {
        switch self {
        case .contentPolicyViolation(let reason):
            return "Content policy violation\(reason.map { ": \($0)" } ?? "")"
        case .durationExceedsLimit(let requested, let maximum):
            return "Requested duration (\(requested)s) exceeds maximum (\(maximum)s)"
        case .unsupportedAspectRatio(let ratio, let model):
            return "Aspect ratio \(ratio.rawValue) is not supported by \(model)"
        case .unsupportedResolution(let resolution, let model):
            return "Resolution \(resolution.rawValue) is not supported by \(model)"
        case .generationFailed(let message):
            return "Video generation failed: \(message)"
        case .timeout(let elapsed):
            return "Video generation timed out after \(Int(elapsed)) seconds"
        case .cancelled:
            return "Video generation was cancelled"
        case .jobNotCompleted(let status):
            return "Video job is not completed (status: \(status.rawValue))"
        case .notSupportedByProvider(let provider):
            return "Video generation is not supported by \(provider)"
        }
    }
}
