// OutputMediaFormat.swift
// swift-llm-structured-outputs
//
// 出力メディアフォーマットの定義

import Foundation

// MARK: - OutputMediaFormat Protocol

/// 出力メディアフォーマット共通プロトコル
///
/// 生成されたメディア（画像、音声、動画）のフォーマットを表現します。
/// 入力側の `MediaType` プロトコルに対応する出力側のプロトコルです。
///
/// ## 準拠する型
/// - `ImageOutputFormat` - 画像出力フォーマット
/// - `AudioOutputFormat` - 音声出力フォーマット
/// - `VideoOutputFormat` - 動画出力フォーマット
public protocol OutputMediaFormat: RawRepresentable, Sendable, Codable, CaseIterable, Hashable
    where RawValue == String {
    /// ファイル拡張子
    var fileExtension: String { get }

    /// MIME タイプ文字列
    var mimeType: String { get }
}

// MARK: - ImageOutputFormat

/// 画像出力フォーマット
///
/// LLM が生成する画像のフォーマットを定義します。
///
/// ## プロバイダー別対応状況
/// - **OpenAI (DALL-E/GPT-Image)**: PNG (デフォルト), JPEG, WebP
/// - **Gemini**: PNG (デフォルト)
///
/// ## 使用例
/// ```swift
/// let format: ImageOutputFormat = .png
/// print(format.mimeType)       // "image/png"
/// print(format.fileExtension)  // "png"
/// ```
public enum ImageOutputFormat: String, OutputMediaFormat {
    case png = "image/png"
    case jpeg = "image/jpeg"
    case webp = "image/webp"

    // MARK: - Properties

    /// ファイル拡張子
    public var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .webp: return "webp"
        }
    }

    /// MIME タイプ文字列
    public var mimeType: String { rawValue }

    // MARK: - Provider Compatibility

    /// OpenAI でサポートされるフォーマット
    public static var openaiFormats: [ImageOutputFormat] {
        [.png, .jpeg, .webp]
    }

    /// Gemini でサポートされるフォーマット
    public static var geminiFormats: [ImageOutputFormat] {
        [.png]
    }

    /// 指定されたプロバイダーでサポートされるか
    public func isSupported(by provider: ProviderType) -> Bool {
        switch provider {
        case .anthropic:
            return false  // 画像生成未対応
        case .openai:
            return Self.openaiFormats.contains(self)
        case .gemini:
            return Self.geminiFormats.contains(self)
        }
    }

    // MARK: - Inference

    /// ファイル拡張子からフォーマットを推論
    ///
    /// - Parameter fileExtension: ファイル拡張子（ドットなし）
    /// - Returns: 対応するフォーマット、見つからない場合は nil
    public static func from(fileExtension: String) -> ImageOutputFormat? {
        let ext = fileExtension.lowercased()
        switch ext {
        case "png": return .png
        case "jpg", "jpeg": return .jpeg
        case "webp": return .webp
        default: return nil
        }
    }
}

// MARK: - AudioOutputFormat

/// 音声出力フォーマット
///
/// LLM が生成する音声のフォーマットを定義します。
///
/// ## プロバイダー別対応状況
/// - **OpenAI TTS**: MP3, Opus, AAC, FLAC, WAV, PCM
/// - **Gemini TTS**: PCM (Linear16, 24kHz)
///
/// ## 使用例
/// ```swift
/// let format: AudioOutputFormat = .mp3
/// print(format.mimeType)       // "audio/mp3"
/// print(format.fileExtension)  // "mp3"
/// ```
public enum AudioOutputFormat: String, OutputMediaFormat {
    case mp3 = "audio/mp3"
    case wav = "audio/wav"
    case opus = "audio/opus"
    case aac = "audio/aac"
    case flac = "audio/flac"
    case pcm = "audio/pcm"

    // MARK: - Properties

    /// ファイル拡張子
    public var fileExtension: String {
        switch self {
        case .mp3: return "mp3"
        case .wav: return "wav"
        case .opus: return "opus"
        case .aac: return "aac"
        case .flac: return "flac"
        case .pcm: return "pcm"
        }
    }

    /// MIME タイプ文字列
    public var mimeType: String { rawValue }

    // MARK: - Provider Compatibility

    /// OpenAI TTS でサポートされるフォーマット
    public static var openaiFormats: [AudioOutputFormat] {
        [.mp3, .opus, .aac, .flac, .wav, .pcm]
    }

    /// Gemini TTS でサポートされるフォーマット
    public static var geminiFormats: [AudioOutputFormat] {
        [.pcm]  // Linear16, 24kHz
    }

    /// 指定されたプロバイダーでサポートされるか
    public func isSupported(by provider: ProviderType) -> Bool {
        switch provider {
        case .anthropic:
            return false  // 音声生成未対応
        case .openai:
            return Self.openaiFormats.contains(self)
        case .gemini:
            return Self.geminiFormats.contains(self)
        }
    }

    // MARK: - Inference

    /// ファイル拡張子からフォーマットを推論
    public static func from(fileExtension: String) -> AudioOutputFormat? {
        let ext = fileExtension.lowercased()
        switch ext {
        case "mp3": return .mp3
        case "wav": return .wav
        case "opus": return .opus
        case "aac", "m4a": return .aac
        case "flac": return .flac
        case "pcm", "raw": return .pcm
        default: return nil
        }
    }
}

// MARK: - VideoOutputFormat

/// 動画出力フォーマット
///
/// LLM が生成する動画のフォーマットを定義します。
///
/// ## プロバイダー別対応状況
/// - **OpenAI Sora**: MP4
/// - **Gemini Veo**: MP4
///
/// ## 使用例
/// ```swift
/// let format: VideoOutputFormat = .mp4
/// print(format.mimeType)       // "video/mp4"
/// print(format.fileExtension)  // "mp4"
/// ```
public enum VideoOutputFormat: String, OutputMediaFormat {
    case mp4 = "video/mp4"

    // MARK: - Properties

    /// ファイル拡張子
    public var fileExtension: String {
        switch self {
        case .mp4: return "mp4"
        }
    }

    /// MIME タイプ文字列
    public var mimeType: String { rawValue }

    // MARK: - Provider Compatibility

    /// 指定されたプロバイダーでサポートされるか
    public func isSupported(by provider: ProviderType) -> Bool {
        switch provider {
        case .anthropic:
            return false  // 動画生成未対応
        case .openai, .gemini:
            return true
        }
    }

    // MARK: - Inference

    /// ファイル拡張子からフォーマットを推論
    public static func from(fileExtension: String) -> VideoOutputFormat? {
        let ext = fileExtension.lowercased()
        switch ext {
        case "mp4", "m4v": return .mp4
        default: return nil
        }
    }
}
