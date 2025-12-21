// GeneratedAudio.swift
// swift-llm-structured-outputs
//
// 生成された音声コンテンツの定義

import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

// MARK: - GeneratedAudio

/// 生成された音声
///
/// LLM によって生成された音声データを表現します。
/// OpenAI TTS や Gemini TTS による音声生成の結果として返されます。
///
/// ## プロバイダー別の特性
/// - **OpenAI TTS**: 複数のフォーマット（MP3, Opus, AAC, FLAC, WAV, PCM）をサポート
/// - **Gemini TTS**: PCM（Linear16, 24kHz）のみ
///
/// ## 使用例
/// ```swift
/// // 音声を生成
/// let audio = try await client.generateSpeech(
///     text: "こんにちは、世界！",
///     voice: .alloy,
///     model: .tts1
/// )
///
/// // ファイルに保存
/// try audio.save(to: URL(fileURLWithPath: "greeting.mp3"))
///
/// // 音声を再生（AVFoundation 利用可能時）
/// if let player = audio.audioPlayer {
///     player.play()
/// }
/// ```
public struct GeneratedAudio: GeneratedMediaProtocol {
    // MARK: - Properties

    /// 生成された音声データ（Base64デコード済み）
    public let data: Data

    /// 音声フォーマット
    public let format: AudioOutputFormat

    /// 音声のテキスト表現（トランスクリプト）
    ///
    /// 生成時に使用された元のテキスト、または
    /// 音声認識によって生成されたテキストが格納されます。
    public let transcript: String?

    /// 音声ファイルの識別子（OpenAI）
    ///
    /// OpenAI の音声生成 API では、生成された音声に一意の識別子が付与されます。
    public let id: String?

    /// 有効期限（OpenAI）
    ///
    /// OpenAI の一部の API では、生成された音声に有効期限が設定されます。
    public let expiresAt: Date?

    // MARK: - GeneratedMediaProtocol

    /// MIME タイプ文字列
    public var mimeType: String { format.mimeType }

    /// ファイル拡張子
    public var fileExtension: String { format.fileExtension }

    // MARK: - Initializers

    /// 初期化
    ///
    /// - Parameters:
    ///   - data: 音声データ
    ///   - format: 音声フォーマット
    ///   - transcript: テキスト表現（オプション）
    ///   - id: 識別子（オプション）
    ///   - expiresAt: 有効期限（オプション）
    public init(
        data: Data,
        format: AudioOutputFormat,
        transcript: String? = nil,
        id: String? = nil,
        expiresAt: Date? = nil
    ) {
        self.data = data
        self.format = format
        self.transcript = transcript
        self.id = id
        self.expiresAt = expiresAt
    }

    /// Base64 文字列から初期化
    ///
    /// - Parameters:
    ///   - base64String: Base64 エンコードされた音声データ
    ///   - format: 音声フォーマット
    ///   - transcript: テキスト表現（オプション）
    ///   - id: 識別子（オプション）
    ///   - expiresAt: 有効期限（オプション）
    /// - Throws: Base64 デコードに失敗した場合
    public init(
        base64String: String,
        format: AudioOutputFormat,
        transcript: String? = nil,
        id: String? = nil,
        expiresAt: Date? = nil
    ) throws {
        guard let data = Data(base64Encoded: base64String) else {
            throw GeneratedMediaError.invalidBase64Data
        }
        self.data = data
        self.format = format
        self.transcript = transcript
        self.id = id
        self.expiresAt = expiresAt
    }

    // MARK: - Audio Playback

    #if canImport(AVFoundation)
    /// AVAudioPlayer を作成
    ///
    /// - Returns: 音声を再生するための AVAudioPlayer、作成に失敗した場合は nil
    /// - Note: PCM フォーマットの場合、追加の変換が必要になる場合があります
    public var audioPlayer: AVAudioPlayer? {
        try? AVAudioPlayer(data: data)
    }
    #endif

    // MARK: - Metadata

    /// データサイズ（バイト）
    public var dataSize: Int {
        data.count
    }

    /// Base64 エンコードされた文字列
    public var base64String: String {
        data.base64EncodedString()
    }

    /// Data URL 形式の文字列
    ///
    /// HTML の audio 要素などで使用可能な形式です。
    /// 例: `data:audio/mp3;base64,SUQzBAA...`
    public var dataURL: String {
        "data:\(mimeType);base64,\(base64String)"
    }

    /// 有効期限が過ぎているかどうか
    ///
    /// - Returns: 有効期限が設定されていて、かつ現在時刻を過ぎている場合は true
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }

    /// 推定再生時間（秒）
    ///
    /// フォーマットごとの一般的なビットレートを使用して概算します。
    /// 正確な値が必要な場合は AVAudioPlayer を使用してください。
    public var estimatedDuration: TimeInterval? {
        // 各フォーマットの一般的なビットレート（bps）を使用
        let bytesPerSecond: Double
        switch format {
        case .mp3:
            bytesPerSecond = 128_000 / 8  // 128 kbps
        case .wav:
            bytesPerSecond = 1_411_200 / 8  // 16-bit, 44.1kHz, stereo
        case .opus:
            bytesPerSecond = 64_000 / 8  // 64 kbps (typical)
        case .aac:
            bytesPerSecond = 128_000 / 8  // 128 kbps
        case .flac:
            bytesPerSecond = 1_000_000 / 8  // ~1 Mbps (variable)
        case .pcm:
            bytesPerSecond = 24_000 * 2  // 24kHz, 16-bit mono (Gemini default)
        }
        return Double(dataSize) / bytesPerSecond
    }
}

// MARK: - Codable

extension GeneratedAudio {
    private enum CodingKeys: String, CodingKey {
        case data
        case format
        case transcript
        case id
        case expiresAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.data = try container.decode(Data.self, forKey: .data)
        self.format = try container.decode(AudioOutputFormat.self, forKey: .format)
        self.transcript = try container.decodeIfPresent(String.self, forKey: .transcript)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
        try container.encode(format, forKey: .format)
        try container.encodeIfPresent(transcript, forKey: .transcript)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
    }
}
