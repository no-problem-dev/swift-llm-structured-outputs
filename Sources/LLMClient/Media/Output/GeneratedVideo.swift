// GeneratedVideo.swift
// swift-llm-structured-outputs
//
// 生成された動画コンテンツおよびジョブの定義

import Foundation

// MARK: - VideoGenerationStatus

/// 動画生成ジョブのステータス
///
/// 動画生成は非同期で行われるため、ジョブのステータスを追跡します。
public enum VideoGenerationStatus: String, Sendable, Codable, Equatable {
    /// 生成がキューに入っている
    case queued

    /// 生成中
    case processing

    /// 生成完了
    case completed

    /// 生成失敗
    case failed

    /// キャンセル済み
    case cancelled

    /// ジョブが完了したかどうか（成功・失敗・キャンセルを含む）
    public var isTerminal: Bool {
        switch self {
        case .queued, .processing:
            return false
        case .completed, .failed, .cancelled:
            return true
        }
    }

    /// ジョブが成功したかどうか
    public var isSuccessful: Bool {
        self == .completed
    }
}

// MARK: - VideoGenerationJob

/// 動画生成ジョブ
///
/// 動画生成は時間がかかるため、非同期ジョブとして処理されます。
/// このジョブオブジェクトを使用してステータスを確認し、完了後に動画を取得します。
///
/// ## プロバイダー別の特性
/// - **OpenAI Sora**: ジョブベースの非同期生成
/// - **Gemini Veo**: ジョブベースの非同期生成
///
/// ## 使用例
/// ```swift
/// // 動画生成ジョブを開始
/// let job = try await client.generateVideo(
///     prompt: "A cat playing with a ball",
///     model: .sora
/// )
///
/// // ステータスをポーリング
/// while !job.status.isTerminal {
///     try await Task.sleep(nanoseconds: 5_000_000_000)  // 5秒待機
///     job = try await client.checkVideoGenerationStatus(job)
/// }
///
/// // 動画を取得
/// if let video = try await client.getGeneratedVideo(job) {
///     try video.save(to: URL(fileURLWithPath: "output.mp4"))
/// }
/// ```
public struct VideoGenerationJob: Sendable, Codable, Equatable, Identifiable {
    // MARK: - Properties

    /// ジョブ識別子
    public let id: String

    /// 現在のステータス
    public var status: VideoGenerationStatus

    /// 生成に使用されたプロンプト
    public let prompt: String

    /// 生成設定
    public let configuration: VideoGenerationConfiguration?

    /// 作成日時
    public let createdAt: Date

    /// 更新日時
    public var updatedAt: Date?

    /// 完了日時
    public var completedAt: Date?

    /// 生成された動画の URL（完了時のみ）
    public var videoURL: URL?

    /// エラーメッセージ（失敗時のみ）
    public var errorMessage: String?

    /// 進捗率（0.0〜1.0、サポートされている場合）
    public var progress: Double?

    // MARK: - Initializers

    /// 初期化
    ///
    /// - Parameters:
    ///   - id: ジョブ識別子
    ///   - status: ステータス
    ///   - prompt: プロンプト
    ///   - configuration: 生成設定
    ///   - createdAt: 作成日時
    public init(
        id: String,
        status: VideoGenerationStatus = .queued,
        prompt: String,
        configuration: VideoGenerationConfiguration? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.status = status
        self.prompt = prompt
        self.configuration = configuration
        self.createdAt = createdAt
    }

    // MARK: - Status Updates

    /// ステータスを更新した新しいジョブを返す
    ///
    /// - Parameters:
    ///   - status: 新しいステータス
    ///   - videoURL: 動画URL（完了時）
    ///   - errorMessage: エラーメッセージ（失敗時）
    ///   - progress: 進捗率
    /// - Returns: 更新されたジョブ
    public func updated(
        status: VideoGenerationStatus,
        videoURL: URL? = nil,
        errorMessage: String? = nil,
        progress: Double? = nil
    ) -> VideoGenerationJob {
        var job = self
        job.status = status
        job.updatedAt = Date()
        job.videoURL = videoURL ?? self.videoURL
        job.errorMessage = errorMessage ?? self.errorMessage
        job.progress = progress ?? self.progress
        if status == .completed || status == .failed || status == .cancelled {
            job.completedAt = Date()
        }
        return job
    }

    // MARK: - Convenience

    /// 経過時間（秒）
    public var elapsedTime: TimeInterval {
        let endTime = completedAt ?? Date()
        return endTime.timeIntervalSince(createdAt)
    }

    /// 推定残り時間（秒、進捗率が利用可能な場合）
    public var estimatedRemainingTime: TimeInterval? {
        guard let progress = progress, progress > 0, progress < 1 else {
            return nil
        }
        let elapsed = elapsedTime
        let totalEstimated = elapsed / progress
        return totalEstimated - elapsed
    }
}

// MARK: - VideoGenerationConfiguration

/// 動画生成設定
///
/// 動画生成時の各種パラメータを指定します。
public struct VideoGenerationConfiguration: Sendable, Codable, Equatable {
    /// 動画の長さ（秒）
    public let duration: Int?

    /// 解像度
    public let resolution: VideoResolution?

    /// フレームレート
    public let frameRate: Int?

    /// アスペクト比
    public let aspectRatio: VideoAspectRatio?

    /// 出力フォーマット
    public let format: VideoOutputFormat

    /// 初期化
    ///
    /// - Parameters:
    ///   - duration: 動画の長さ（秒）
    ///   - resolution: 解像度
    ///   - frameRate: フレームレート
    ///   - aspectRatio: アスペクト比
    ///   - format: 出力フォーマット
    public init(
        duration: Int? = nil,
        resolution: VideoResolution? = nil,
        frameRate: Int? = nil,
        aspectRatio: VideoAspectRatio? = nil,
        format: VideoOutputFormat = .mp4
    ) {
        self.duration = duration
        self.resolution = resolution
        self.frameRate = frameRate
        self.aspectRatio = aspectRatio
        self.format = format
    }
}

// MARK: - VideoResolution

/// 動画解像度
public enum VideoResolution: String, Sendable, Codable, CaseIterable, Equatable {
    /// 480p (854x480)
    case sd480p = "480p"

    /// 720p (1280x720)
    case hd720p = "720p"

    /// 1080p (1920x1080)
    case fhd1080p = "1080p"

    /// 4K (3840x2160)
    case uhd4k = "4k"

    /// 横幅（ピクセル）
    public var width: Int {
        switch self {
        case .sd480p: return 854
        case .hd720p: return 1280
        case .fhd1080p: return 1920
        case .uhd4k: return 3840
        }
    }

    /// 縦幅（ピクセル）
    public var height: Int {
        switch self {
        case .sd480p: return 480
        case .hd720p: return 720
        case .fhd1080p: return 1080
        case .uhd4k: return 2160
        }
    }
}

// MARK: - VideoAspectRatio

/// 動画アスペクト比
public enum VideoAspectRatio: String, Sendable, Codable, CaseIterable, Equatable {
    /// 16:9（ワイドスクリーン、横長）
    case landscape16x9 = "16:9"

    /// 9:16（縦長、スマートフォン向け）
    case portrait9x16 = "9:16"

    /// 1:1（正方形）
    case square1x1 = "1:1"

    /// 4:3（標準）
    case standard4x3 = "4:3"

    /// 21:9（シネマスコープ）
    case cinematic21x9 = "21:9"

    /// 横幅の比率
    public var widthRatio: Int {
        switch self {
        case .landscape16x9: return 16
        case .portrait9x16: return 9
        case .square1x1: return 1
        case .standard4x3: return 4
        case .cinematic21x9: return 21
        }
    }

    /// 縦幅の比率
    public var heightRatio: Int {
        switch self {
        case .landscape16x9: return 9
        case .portrait9x16: return 16
        case .square1x1: return 1
        case .standard4x3: return 3
        case .cinematic21x9: return 9
        }
    }

    /// 横長かどうか
    public var isLandscape: Bool {
        widthRatio > heightRatio
    }

    /// 縦長かどうか
    public var isPortrait: Bool {
        heightRatio > widthRatio
    }
}

// MARK: - GeneratedVideo

/// 生成された動画
///
/// LLM によって生成された動画データを表現します。
/// 動画生成ジョブが完了した後に取得できます。
///
/// ## 使用例
/// ```swift
/// // 動画を取得
/// let video = try await client.getGeneratedVideo(job)
///
/// // ファイルに保存
/// try video.save(to: URL(fileURLWithPath: "output.mp4"))
///
/// // URL から直接再生（AVPlayer で使用可能）
/// if let url = video.remoteURL {
///     let player = AVPlayer(url: url)
///     player.play()
/// }
/// ```
public struct GeneratedVideo: GeneratedMediaProtocol {
    // MARK: - Properties

    /// 動画データ
    ///
    /// ローカルにダウンロード済みの場合は動画データが格納されます。
    /// リモート URL のみの場合は空のデータになります。
    public let data: Data

    /// 動画フォーマット
    public let format: VideoOutputFormat

    /// リモート URL
    ///
    /// 動画がサーバー上に保存されている場合の URL です。
    /// ストリーミング再生に使用できます。
    public let remoteURL: URL?

    /// 動画の長さ（秒）
    public let duration: TimeInterval?

    /// 解像度
    public let resolution: VideoResolution?

    /// ジョブ ID
    public let jobId: String?

    /// 生成に使用されたプロンプト
    public let prompt: String?

    // MARK: - GeneratedMediaProtocol

    /// MIME タイプ文字列
    public var mimeType: String { format.mimeType }

    /// ファイル拡張子
    public var fileExtension: String { format.fileExtension }

    // MARK: - Initializers

    /// 初期化（データから）
    ///
    /// - Parameters:
    ///   - data: 動画データ
    ///   - format: 動画フォーマット
    ///   - remoteURL: リモート URL（オプション）
    ///   - duration: 動画の長さ（オプション）
    ///   - resolution: 解像度（オプション）
    ///   - jobId: ジョブ ID（オプション）
    ///   - prompt: プロンプト（オプション）
    public init(
        data: Data,
        format: VideoOutputFormat = .mp4,
        remoteURL: URL? = nil,
        duration: TimeInterval? = nil,
        resolution: VideoResolution? = nil,
        jobId: String? = nil,
        prompt: String? = nil
    ) {
        self.data = data
        self.format = format
        self.remoteURL = remoteURL
        self.duration = duration
        self.resolution = resolution
        self.jobId = jobId
        self.prompt = prompt
    }

    /// 初期化（URL から）
    ///
    /// - Parameters:
    ///   - remoteURL: リモート URL
    ///   - format: 動画フォーマット
    ///   - duration: 動画の長さ（オプション）
    ///   - resolution: 解像度（オプション）
    ///   - jobId: ジョブ ID（オプション）
    ///   - prompt: プロンプト（オプション）
    public init(
        remoteURL: URL,
        format: VideoOutputFormat = .mp4,
        duration: TimeInterval? = nil,
        resolution: VideoResolution? = nil,
        jobId: String? = nil,
        prompt: String? = nil
    ) {
        self.data = Data()
        self.format = format
        self.remoteURL = remoteURL
        self.duration = duration
        self.resolution = resolution
        self.jobId = jobId
        self.prompt = prompt
    }

    // MARK: - Data Access

    /// データサイズ（バイト）
    public var dataSize: Int {
        data.count
    }

    /// ローカルデータが利用可能かどうか
    public var hasLocalData: Bool {
        !data.isEmpty
    }

    /// リモート URL からデータをダウンロード
    ///
    /// - Returns: ダウンロードされたデータを含む新しい GeneratedVideo
    /// - Throws: ダウンロードに失敗した場合
    public func downloadData() async throws -> GeneratedVideo {
        guard let url = remoteURL else {
            return self
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return GeneratedVideo(
                data: data,
                format: format,
                remoteURL: remoteURL,
                duration: duration,
                resolution: resolution,
                jobId: jobId,
                prompt: prompt
            )
        } catch {
            throw GeneratedMediaError.downloadError(error)
        }
    }
}

// MARK: - Codable

extension GeneratedVideo {
    private enum CodingKeys: String, CodingKey {
        case data
        case format
        case remoteURL
        case duration
        case resolution
        case jobId
        case prompt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.data = try container.decode(Data.self, forKey: .data)
        self.format = try container.decode(VideoOutputFormat.self, forKey: .format)
        self.remoteURL = try container.decodeIfPresent(URL.self, forKey: .remoteURL)
        self.duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        self.resolution = try container.decodeIfPresent(VideoResolution.self, forKey: .resolution)
        self.jobId = try container.decodeIfPresent(String.self, forKey: .jobId)
        self.prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
        try container.encode(format, forKey: .format)
        try container.encodeIfPresent(remoteURL, forKey: .remoteURL)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(resolution, forKey: .resolution)
        try container.encodeIfPresent(jobId, forKey: .jobId)
        try container.encodeIfPresent(prompt, forKey: .prompt)
    }
}
