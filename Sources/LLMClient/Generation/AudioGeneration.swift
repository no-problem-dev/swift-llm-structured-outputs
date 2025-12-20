// AudioGeneration.swift
// swift-llm-structured-outputs
//
// 音声生成（TTS）機能のプロトコルと関連型

import Foundation

// MARK: - SpeechGenerationCapable Protocol

/// 音声生成（TTS）機能を持つクライアントのプロトコル
///
/// このプロトコルを実装するクライアントは、テキストから音声を生成できます。
///
/// ## 使用例
/// ```swift
/// // OpenAI クライアントで音声生成
/// let client = OpenAIClient(apiKey: "sk-...")
/// let audio = try await client.generateSpeech(
///     text: "こんにちは、世界！",
///     model: .tts1,
///     voice: .alloy
/// )
/// try audio.save(to: URL(fileURLWithPath: "greeting.mp3"))
/// ```
public protocol SpeechGenerationCapable<SpeechModel>: Sendable {
    /// 音声生成で使用可能なモデル型
    associatedtype SpeechModel: Sendable

    /// 音声で使用可能な声の型
    associatedtype Voice: Sendable

    /// テキストから音声を生成
    ///
    /// - Parameters:
    ///   - text: 音声化するテキスト
    ///   - model: 使用する音声生成モデル
    ///   - voice: 使用する声
    ///   - speed: 再生速度（0.25〜4.0、デフォルト: 1.0）
    ///   - format: 出力フォーマット
    /// - Returns: 生成された音声
    /// - Throws: `LLMError` または `SpeechGenerationError`
    func generateSpeech(
        text: String,
        model: SpeechModel,
        voice: Voice,
        speed: Double?,
        format: AudioOutputFormat?
    ) async throws -> GeneratedAudio
}

// MARK: - Default Implementations

extension SpeechGenerationCapable {
    /// テキストから音声を生成（デフォルト引数付き）
    public func generateSpeech(
        text: String,
        model: SpeechModel,
        voice: Voice,
        speed: Double? = nil,
        format: AudioOutputFormat? = nil
    ) async throws -> GeneratedAudio {
        try await generateSpeech(
            text: text,
            model: model,
            voice: voice,
            speed: speed,
            format: format
        )
    }
}

// MARK: - OpenAI TTS Models

/// OpenAI TTS モデル
public enum OpenAITTSModel: String, Sendable, Codable, CaseIterable, Equatable {
    /// TTS-1（標準品質、低レイテンシー）
    case tts1 = "tts-1"
    /// TTS-1 HD（高品質）
    case tts1HD = "tts-1-hd"

    /// モデル ID
    public var id: String { rawValue }

    /// 表示名
    public var displayName: String {
        switch self {
        case .tts1: return "TTS-1"
        case .tts1HD: return "TTS-1 HD"
        }
    }

    /// サポートされる出力フォーマット
    public var supportedFormats: [AudioOutputFormat] {
        AudioOutputFormat.openaiFormats
    }
}

// MARK: - OpenAI TTS Voices

/// OpenAI TTS 音声
public enum OpenAIVoice: String, Sendable, Codable, CaseIterable, Equatable {
    /// Alloy - 中性的な声
    case alloy
    /// Echo - 男性的な声
    case echo
    /// Fable - 男性的な声（British）
    case fable
    /// Onyx - 深い男性の声
    case onyx
    /// Nova - 女性的な声
    case nova
    /// Shimmer - 女性的な声（柔らかい）
    case shimmer

    /// 音声 ID
    public var id: String { rawValue }

    /// 表示名
    public var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Gemini TTS Models

/// Gemini TTS モデル（将来対応予定）
public enum GeminiTTSModel: String, Sendable, Codable, CaseIterable, Equatable {
    /// Gemini TTS（プレビュー）
    case geminiTTS = "gemini-tts-preview"

    /// モデル ID
    public var id: String { rawValue }

    /// 表示名
    public var displayName: String {
        "Gemini TTS"
    }

    /// サポートされる出力フォーマット
    public var supportedFormats: [AudioOutputFormat] {
        AudioOutputFormat.geminiFormats
    }
}

// MARK: - SpeechGenerationError

/// 音声生成固有のエラー
public enum SpeechGenerationError: Error, Sendable, LocalizedError {
    /// テキストが長すぎる
    case textTooLong(length: Int, maximum: Int)
    /// テキストが空
    case emptyText
    /// 速度が範囲外
    case invalidSpeed(Double)
    /// フォーマットがモデルでサポートされていない
    case unsupportedFormat(AudioOutputFormat, model: String)
    /// 音声生成がこのプロバイダーでサポートされていない
    case notSupportedByProvider(String)

    public var errorDescription: String? {
        switch self {
        case .textTooLong(let length, let maximum):
            return "Text length (\(length)) exceeds maximum (\(maximum))"
        case .emptyText:
            return "Text cannot be empty"
        case .invalidSpeed(let speed):
            return "Speed \(speed) is not valid. Must be between 0.25 and 4.0"
        case .unsupportedFormat(let format, let model):
            return "Format \(format.rawValue) is not supported by \(model)"
        case .notSupportedByProvider(let provider):
            return "Speech generation is not supported by \(provider)"
        }
    }
}
