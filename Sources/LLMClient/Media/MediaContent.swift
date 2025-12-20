// MediaContent.swift
// swift-llm-structured-outputs
//
// Created by Claude on 2025-12-20.

import Foundation

// MARK: - Image Content

/// 画像コンテンツ
///
/// LLMに送信する画像データを表現します。
///
/// ## サポートされるプロバイダー
/// - **Anthropic**: JPEG, PNG, GIF, WebP（Base64またはURL）
/// - **OpenAI**: JPEG, PNG, GIF, WebP（Base64またはURL、detailオプション付き）
/// - **Gemini**: JPEG, PNG, GIF, WebP, HEIC, HEIF（Base64、URL、またはFile API）
///
/// ## 使用例
/// ```swift
/// // Base64データから
/// let imageData = try Data(contentsOf: imageFileURL)
/// let image = ImageContent.base64(imageData, mediaType: .jpeg)
///
/// // URLから
/// let image = ImageContent.url(URL(string: "https://example.com/image.jpg")!, mediaType: .jpeg)
///
/// // ファイルパスから（自動推論）
/// let image = try ImageContent.file(at: "/path/to/image.jpg")
/// ```
public struct ImageContent: Sendable, Equatable, Codable {
    /// データソース
    public let source: MediaSource

    /// メディアタイプ
    public let mediaType: ImageMediaType

    /// 詳細レベル（OpenAI専用）
    ///
    /// 画像の解析詳細度を指定します。
    /// - `low`: 低解像度処理（高速）
    /// - `high`: 高解像度処理（詳細）
    /// - `auto`: モデルが自動選択（デフォルト）
    public let detail: ImageDetail?

    /// 詳細レベル
    public enum ImageDetail: String, Sendable, Codable, CaseIterable {
        case low
        case high
        case auto
    }

    // MARK: - Initializers

    /// 初期化
    ///
    /// - Parameters:
    ///   - source: データソース
    ///   - mediaType: 画像のMIMEタイプ
    ///   - detail: 解析詳細度（OpenAI専用、省略可）
    public init(
        source: MediaSource,
        mediaType: ImageMediaType,
        detail: ImageDetail? = nil
    ) {
        self.source = source
        self.mediaType = mediaType
        self.detail = detail
    }

    // MARK: - Convenience Initializers

    /// Base64データから初期化
    ///
    /// - Parameters:
    ///   - data: 画像のバイナリデータ
    ///   - mediaType: 画像のMIMEタイプ
    ///   - detail: 解析詳細度（OpenAI専用）
    /// - Returns: 画像コンテンツ
    public static func base64(
        _ data: Data,
        mediaType: ImageMediaType,
        detail: ImageDetail? = nil
    ) -> ImageContent {
        ImageContent(source: .base64(data), mediaType: mediaType, detail: detail)
    }

    /// URLから初期化
    ///
    /// - Parameters:
    ///   - url: 画像のURL
    ///   - mediaType: 画像のMIMEタイプ
    ///   - detail: 解析詳細度（OpenAI専用）
    /// - Returns: 画像コンテンツ
    public static func url(
        _ url: URL,
        mediaType: ImageMediaType,
        detail: ImageDetail? = nil
    ) -> ImageContent {
        ImageContent(source: .url(url), mediaType: mediaType, detail: detail)
    }

    /// ファイル参照から初期化
    ///
    /// - Parameters:
    ///   - id: File APIのファイルID
    ///   - mediaType: 画像のMIMEタイプ
    ///   - detail: 解析詳細度（OpenAI専用）
    /// - Returns: 画像コンテンツ
    public static func fileReference(
        _ id: String,
        mediaType: ImageMediaType,
        detail: ImageDetail? = nil
    ) -> ImageContent {
        ImageContent(source: .fileReference(id: id), mediaType: mediaType, detail: detail)
    }

    /// ファイルパスから初期化（メディアタイプを拡張子から推論）
    ///
    /// - Parameters:
    ///   - path: ファイルパス
    ///   - detail: 解析詳細度（OpenAI専用）
    /// - Returns: 画像コンテンツ
    /// - Throws: `MediaError.unsupportedFormat` または `MediaError.fileReadError`
    public static func file(
        at path: String,
        detail: ImageDetail? = nil
    ) throws -> ImageContent {
        let url = URL(fileURLWithPath: path)
        return try file(at: url, detail: detail)
    }

    /// ファイルURLから初期化（メディアタイプを拡張子から推論）
    ///
    /// - Parameters:
    ///   - url: ファイルURL
    ///   - detail: 解析詳細度（OpenAI専用）
    /// - Returns: 画像コンテンツ
    /// - Throws: `MediaError.unsupportedFormat` または `MediaError.fileReadError`
    public static func file(
        at url: URL,
        detail: ImageDetail? = nil
    ) throws -> ImageContent {
        let source = try MediaSource.fromFile(at: url)
        let mediaType = try inferMediaType(from: url)
        return ImageContent(source: source, mediaType: mediaType, detail: detail)
    }

    // MARK: - Validation

    /// プロバイダー互換性をバリデーション
    ///
    /// - Parameter provider: ターゲットプロバイダー
    /// - Throws: `MediaError` 互換性がない場合
    public func validate(for provider: ProviderType) throws {
        // メディアタイプのサポート確認
        try MediaError.validateSupport(mediaType, for: provider)

        // ファイル参照はAnthropicで未サポート
        if source.isFileReference && provider == .anthropic {
            throw MediaError.notSupportedByProvider(
                feature: "File reference",
                provider: provider
            )
        }
    }

    // MARK: - Private

    private static func inferMediaType(from url: URL) throws -> ImageMediaType {
        let ext = url.pathExtension.lowercased()
        guard let mediaType = ImageMediaType.from(fileExtension: ext) else {
            throw MediaError.unsupportedFormat(ext)
        }
        return mediaType
    }
}

// MARK: - Audio Content

/// 音声コンテンツ
///
/// LLMに送信する音声データを表現します。
///
/// ## サポートされるプロバイダー
/// - **OpenAI**: WAV, MP3（gpt-4o-audio-preview モデルのみ）
/// - **Gemini**: WAV, MP3, AAC, FLAC, OGG, AIFF
/// - **Anthropic**: 音声入力未対応
///
/// ## 使用例
/// ```swift
/// // Base64データから
/// let audioData = try Data(contentsOf: audioFileURL)
/// let audio = AudioContent.base64(audioData, mediaType: .wav)
///
/// // ファイルパスから
/// let audio = try AudioContent.file(at: "/path/to/audio.mp3")
/// ```
public struct AudioContent: Sendable, Equatable, Codable {
    /// データソース
    public let source: MediaSource

    /// メディアタイプ
    public let mediaType: AudioMediaType

    // MARK: - Initializers

    /// 初期化
    ///
    /// - Parameters:
    ///   - source: データソース
    ///   - mediaType: 音声のMIMEタイプ
    public init(source: MediaSource, mediaType: AudioMediaType) {
        self.source = source
        self.mediaType = mediaType
    }

    // MARK: - Convenience Initializers

    /// Base64データから初期化
    ///
    /// - Parameters:
    ///   - data: 音声のバイナリデータ
    ///   - mediaType: 音声のMIMEタイプ
    /// - Returns: 音声コンテンツ
    public static func base64(_ data: Data, mediaType: AudioMediaType) -> AudioContent {
        AudioContent(source: .base64(data), mediaType: mediaType)
    }

    /// URLから初期化
    ///
    /// - Parameters:
    ///   - url: 音声のURL
    ///   - mediaType: 音声のMIMEタイプ
    /// - Returns: 音声コンテンツ
    public static func url(_ url: URL, mediaType: AudioMediaType) -> AudioContent {
        AudioContent(source: .url(url), mediaType: mediaType)
    }

    /// ファイル参照から初期化
    ///
    /// - Parameters:
    ///   - id: File APIのファイルID
    ///   - mediaType: 音声のMIMEタイプ
    /// - Returns: 音声コンテンツ
    public static func fileReference(_ id: String, mediaType: AudioMediaType) -> AudioContent {
        AudioContent(source: .fileReference(id: id), mediaType: mediaType)
    }

    /// ファイルパスから初期化（メディアタイプを拡張子から推論）
    ///
    /// - Parameter path: ファイルパス
    /// - Returns: 音声コンテンツ
    /// - Throws: `MediaError.unsupportedFormat` または `MediaError.fileReadError`
    public static func file(at path: String) throws -> AudioContent {
        let url = URL(fileURLWithPath: path)
        return try file(at: url)
    }

    /// ファイルURLから初期化（メディアタイプを拡張子から推論）
    ///
    /// - Parameter url: ファイルURL
    /// - Returns: 音声コンテンツ
    /// - Throws: `MediaError.unsupportedFormat` または `MediaError.fileReadError`
    public static func file(at url: URL) throws -> AudioContent {
        let source = try MediaSource.fromFile(at: url)
        let mediaType = try inferMediaType(from: url)
        return AudioContent(source: source, mediaType: mediaType)
    }

    // MARK: - Validation

    /// プロバイダー互換性をバリデーション
    ///
    /// - Parameter provider: ターゲットプロバイダー
    /// - Throws: `MediaError` 互換性がない場合
    public func validate(for provider: ProviderType) throws {
        // Anthropicは音声未対応
        if provider == .anthropic {
            throw MediaError.notSupportedByProvider(
                feature: "Audio input",
                provider: provider
            )
        }

        // メディアタイプのサポート確認
        try MediaError.validateSupport(mediaType, for: provider)

        // OpenAIはbase64のみ
        if provider == .openai && !source.isBase64 {
            throw MediaError.notSupportedByProvider(
                feature: "Audio from URL (use base64)",
                provider: provider
            )
        }
    }

    // MARK: - Private

    private static func inferMediaType(from url: URL) throws -> AudioMediaType {
        let ext = url.pathExtension.lowercased()
        guard let mediaType = AudioMediaType.from(fileExtension: ext) else {
            throw MediaError.unsupportedFormat(ext)
        }
        return mediaType
    }
}

// MARK: - Video Content

/// 動画コンテンツ
///
/// LLMに送信する動画データを表現します。
///
/// ## サポートされるプロバイダー
/// - **Gemini**: MP4, AVI, MOV, MKV, WebM, FLV, MPEG, 3GP, WMV
/// - **Anthropic / OpenAI**: 動画入力未対応（フレーム分解が必要）
///
/// ## 使用例
/// ```swift
/// // File APIを使用（推奨：動画は通常サイズが大きいため）
/// let video = VideoContent.fileReference("files/abc123", mediaType: .mp4)
///
/// // 小さな動画の場合はBase64も可能
/// let videoData = try Data(contentsOf: videoFileURL)
/// let video = VideoContent.base64(videoData, mediaType: .mp4)
/// ```
public struct VideoContent: Sendable, Equatable, Codable {
    /// データソース
    public let source: MediaSource

    /// メディアタイプ
    public let mediaType: VideoMediaType

    // MARK: - Initializers

    /// 初期化
    ///
    /// - Parameters:
    ///   - source: データソース
    ///   - mediaType: 動画のMIMEタイプ
    public init(source: MediaSource, mediaType: VideoMediaType) {
        self.source = source
        self.mediaType = mediaType
    }

    // MARK: - Convenience Initializers

    /// Base64データから初期化
    ///
    /// - Parameters:
    ///   - data: 動画のバイナリデータ
    ///   - mediaType: 動画のMIMEタイプ
    /// - Returns: 動画コンテンツ
    ///
    /// - Note: 動画ファイルは通常サイズが大きいため、
    ///         大きなファイルにはFile APIの使用を推奨します。
    public static func base64(_ data: Data, mediaType: VideoMediaType) -> VideoContent {
        VideoContent(source: .base64(data), mediaType: mediaType)
    }

    /// URLから初期化
    ///
    /// - Parameters:
    ///   - url: 動画のURL
    ///   - mediaType: 動画のMIMEタイプ
    /// - Returns: 動画コンテンツ
    public static func url(_ url: URL, mediaType: VideoMediaType) -> VideoContent {
        VideoContent(source: .url(url), mediaType: mediaType)
    }

    /// ファイル参照から初期化（大きな動画ファイル用）
    ///
    /// - Parameters:
    ///   - id: File APIのファイルID
    ///   - mediaType: 動画のMIMEタイプ
    /// - Returns: 動画コンテンツ
    public static func fileReference(_ id: String, mediaType: VideoMediaType) -> VideoContent {
        VideoContent(source: .fileReference(id: id), mediaType: mediaType)
    }

    /// ファイルパスから初期化（メディアタイプを拡張子から推論）
    ///
    /// - Parameter path: ファイルパス
    /// - Returns: 動画コンテンツ
    /// - Throws: `MediaError.unsupportedFormat` または `MediaError.fileReadError`
    ///
    /// - Warning: 大きな動画ファイルを読み込むとメモリを大量に消費します。
    ///           大きなファイルにはFile APIの使用を推奨します。
    public static func file(at path: String) throws -> VideoContent {
        let url = URL(fileURLWithPath: path)
        return try file(at: url)
    }

    /// ファイルURLから初期化（メディアタイプを拡張子から推論）
    ///
    /// - Parameter url: ファイルURL
    /// - Returns: 動画コンテンツ
    /// - Throws: `MediaError.unsupportedFormat` または `MediaError.fileReadError`
    public static func file(at url: URL) throws -> VideoContent {
        let source = try MediaSource.fromFile(at: url)
        let mediaType = try inferMediaType(from: url)
        return VideoContent(source: source, mediaType: mediaType)
    }

    // MARK: - Validation

    /// プロバイダー互換性をバリデーション
    ///
    /// - Parameter provider: ターゲットプロバイダー
    /// - Throws: `MediaError` 互換性がない場合
    public func validate(for provider: ProviderType) throws {
        // Gemini以外は動画未対応
        if provider != .gemini {
            throw MediaError.notSupportedByProvider(
                feature: "Video input",
                provider: provider
            )
        }
    }

    // MARK: - Private

    private static func inferMediaType(from url: URL) throws -> VideoMediaType {
        let ext = url.pathExtension.lowercased()
        guard let mediaType = VideoMediaType.from(fileExtension: ext) else {
            throw MediaError.unsupportedFormat(ext)
        }
        return mediaType
    }
}

// MARK: - Media Content Protocol

/// メディアコンテンツ共通プロトコル
///
/// 全てのメディアコンテンツ型が準拠するプロトコルです。
public protocol MediaContentProtocol: Sendable, Equatable, Codable {
    associatedtype MediaTypeEnum: MediaType

    /// データソース
    var source: MediaSource { get }

    /// MIMEタイプ文字列
    var mimeType: String { get }

    /// プロバイダー互換性をバリデーション
    func validate(for provider: ProviderType) throws
}

extension ImageContent: MediaContentProtocol {
    public typealias MediaTypeEnum = ImageMediaType

    public var mimeType: String { mediaType.mimeType }
}

extension AudioContent: MediaContentProtocol {
    public typealias MediaTypeEnum = AudioMediaType

    public var mimeType: String { mediaType.mimeType }
}

extension VideoContent: MediaContentProtocol {
    public typealias MediaTypeEnum = VideoMediaType

    public var mimeType: String { mediaType.mimeType }
}
