// MediaTypes.swift
// swift-llm-structured-outputs
//
// Created by Claude on 2025-12-20.

import Foundation

// MARK: - Image Media Type

/// 画像メディアタイプ
///
/// 各プロバイダーでサポートされる画像形式を定義します。
/// プロバイダー間の互換性情報も含みます。
///
/// ## サポート状況
/// - **全プロバイダー共通**: JPEG, PNG, GIF, WebP
/// - **Gemini専用**: HEIC, HEIF
///
/// ## 使用例
/// ```swift
/// let imageType: ImageMediaType = .jpeg
/// print(imageType.isSupported(by: .anthropic))  // true
/// print(imageType.fileExtension)  // "jpg"
/// ```
public enum ImageMediaType: String, Sendable, Codable, CaseIterable {
    case jpeg = "image/jpeg"
    case png = "image/png"
    case gif = "image/gif"
    case webp = "image/webp"
    case heic = "image/heic"   // Gemini only
    case heif = "image/heif"   // Gemini only

    // MARK: - Properties

    /// ファイル拡張子
    public var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .gif: return "gif"
        case .webp: return "webp"
        case .heic: return "heic"
        case .heif: return "heif"
        }
    }

    /// MIME タイプ文字列
    public var mimeType: String { rawValue }

    // MARK: - Provider Compatibility

    /// 全プロバイダーで共通サポートされるタイプ
    public static var universalTypes: [ImageMediaType] {
        [.jpeg, .png, .gif, .webp]
    }

    /// Gemini専用タイプ
    public static var geminiOnlyTypes: [ImageMediaType] {
        [.heic, .heif]
    }

    /// 指定されたプロバイダーでサポートされるか
    public func isSupported(by provider: ProviderType) -> Bool {
        switch provider {
        case .anthropic, .openai:
            return Self.universalTypes.contains(self)
        case .gemini:
            return true  // All types supported
        }
    }

    // MARK: - Inference

    /// ファイル拡張子からメディアタイプを推論
    ///
    /// - Parameter fileExtension: ファイル拡張子（ドットなし）
    /// - Returns: 対応するメディアタイプ、見つからない場合は nil
    public static func from(fileExtension: String) -> ImageMediaType? {
        let ext = fileExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        case "gif": return .gif
        case "webp": return .webp
        case "heic": return .heic
        case "heif": return .heif
        default: return nil
        }
    }
}

// MARK: - Audio Media Type

/// 音声メディアタイプ
///
/// 各プロバイダーでサポートされる音声形式を定義します。
///
/// ## サポート状況
/// - **OpenAI Chat API**: WAV, MP3 のみ
/// - **Gemini**: 全形式対応
/// - **Anthropic**: 音声入力未対応
///
/// ## 使用例
/// ```swift
/// let audioType: AudioMediaType = .wav
/// print(AudioMediaType.openaiChatTypes.contains(audioType))  // true
/// ```
public enum AudioMediaType: String, Sendable, Codable, CaseIterable {
    case wav = "audio/wav"
    case mp3 = "audio/mp3"
    case aac = "audio/aac"
    case flac = "audio/flac"
    case ogg = "audio/ogg"
    case aiff = "audio/aiff"  // Gemini only

    // MARK: - Properties

    /// ファイル拡張子
    public var fileExtension: String {
        switch self {
        case .wav: return "wav"
        case .mp3: return "mp3"
        case .aac: return "aac"
        case .flac: return "flac"
        case .ogg: return "ogg"
        case .aiff: return "aiff"
        }
    }

    /// MIME タイプ文字列
    public var mimeType: String { rawValue }

    // MARK: - Provider Compatibility

    /// OpenAI Chat Completions でサポートされるタイプ
    public static var openaiChatTypes: [AudioMediaType] {
        [.wav, .mp3]
    }

    /// Gemini でサポートされるタイプ
    public static var geminiTypes: [AudioMediaType] {
        AudioMediaType.allCases
    }

    /// 指定されたプロバイダーでサポートされるか
    public func isSupported(by provider: ProviderType) -> Bool {
        switch provider {
        case .anthropic:
            return false  // Audio input not supported
        case .openai:
            return Self.openaiChatTypes.contains(self)
        case .gemini:
            return true
        }
    }

    // MARK: - Inference

    /// ファイル拡張子からメディアタイプを推論
    public static func from(fileExtension: String) -> AudioMediaType? {
        let ext = fileExtension.lowercased()
        switch ext {
        case "wav": return .wav
        case "mp3": return .mp3
        case "aac", "m4a": return .aac
        case "flac": return .flac
        case "ogg", "oga": return .ogg
        case "aiff", "aif": return .aiff
        default: return nil
        }
    }
}

// MARK: - Video Media Type

/// 動画メディアタイプ
///
/// 各プロバイダーでサポートされる動画形式を定義します。
///
/// ## サポート状況
/// - **Gemini**: 全形式対応
/// - **Anthropic / OpenAI**: 動画入力未対応（フレーム分解が必要）
///
/// ## 使用例
/// ```swift
/// let videoType: VideoMediaType = .mp4
/// print(videoType.isSupported(by: .gemini))  // true
/// print(videoType.isSupported(by: .openai))  // false
/// ```
public enum VideoMediaType: String, Sendable, Codable, CaseIterable {
    case mp4 = "video/mp4"
    case avi = "video/avi"
    case mov = "video/quicktime"
    case mkv = "video/x-matroska"
    case webm = "video/webm"
    case flv = "video/x-flv"
    case mpeg = "video/mpeg"
    case threegpp = "video/3gpp"
    case wmv = "video/x-ms-wmv"

    // MARK: - Properties

    /// ファイル拡張子
    public var fileExtension: String {
        switch self {
        case .mp4: return "mp4"
        case .avi: return "avi"
        case .mov: return "mov"
        case .mkv: return "mkv"
        case .webm: return "webm"
        case .flv: return "flv"
        case .mpeg: return "mpeg"
        case .threegpp: return "3gp"
        case .wmv: return "wmv"
        }
    }

    /// MIME タイプ文字列
    public var mimeType: String { rawValue }

    // MARK: - Provider Compatibility

    /// 指定されたプロバイダーでサポートされるか
    public func isSupported(by provider: ProviderType) -> Bool {
        switch provider {
        case .anthropic, .openai:
            return false  // Direct video input not supported
        case .gemini:
            return true
        }
    }

    // MARK: - Inference

    /// ファイル拡張子からメディアタイプを推論
    public static func from(fileExtension: String) -> VideoMediaType? {
        let ext = fileExtension.lowercased()
        switch ext {
        case "mp4", "m4v": return .mp4
        case "avi": return .avi
        case "mov": return .mov
        case "mkv": return .mkv
        case "webm": return .webm
        case "flv": return .flv
        case "mpeg", "mpg": return .mpeg
        case "3gp", "3gpp": return .threegpp
        case "wmv": return .wmv
        default: return nil
        }
    }
}

// MARK: - Provider Type

/// プロバイダー識別子
///
/// LLMプロバイダーを識別するための列挙型です。
/// メディア機能のサポート確認やエラーメッセージに使用されます。
public enum ProviderType: String, Sendable, Codable {
    case anthropic
    case openai
    case gemini

    /// プロバイダーの表示名
    public var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI"
        case .gemini: return "Google Gemini"
        }
    }
}

// MARK: - Media Type Protocol

/// メディアタイプ共通プロトコル
///
/// すべてのメディアタイプ列挙型が準拠するプロトコルです。
public protocol MediaType: RawRepresentable, Sendable, Codable, CaseIterable where RawValue == String {
    /// ファイル拡張子
    var fileExtension: String { get }
    /// MIME タイプ文字列
    var mimeType: String { get }
    /// 指定されたプロバイダーでサポートされるか
    func isSupported(by provider: ProviderType) -> Bool
}

extension ImageMediaType: MediaType {}
extension AudioMediaType: MediaType {}
extension VideoMediaType: MediaType {}
