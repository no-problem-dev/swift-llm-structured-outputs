// LLMInput.swift
// swift-llm-structured-outputs
//
// Created by Claude on 2025-12-21.

import Foundation

// MARK: - LLMInput

/// LLMへの入力を表す具象型
///
/// テキストプロンプトとマルチモーダルコンテンツを統合した
/// LLM入力の標準実装です。
///
/// ## 概要
///
/// `LLMInput` は `LLMInputProtocol` の具象実装であり、
/// すべての LLM API 呼び出しで使用される統一入力型です。
///
/// ## 使用例
///
/// ### テキストのみ
/// ```swift
/// // 文字列リテラルから直接作成
/// let input: LLMInput = "こんにちは"
///
/// // 明示的な初期化
/// let input = LLMInput("分析してください")
/// ```
///
/// ### Prompt DSL を使用
/// ```swift
/// let input = LLMInput(
///     Prompt {
///         PromptComponent.role("データ分析の専門家")
///         PromptComponent.objective("売上データを分析")
///     }
/// )
/// ```
///
/// ### マルチモーダル入力
/// ```swift
/// // 画像付き
/// let input = LLMInput(
///     "この画像を分析してください",
///     images: [imageContent]
/// )
///
/// // 音声付き
/// let input = LLMInput(
///     "この音声を文字起こししてください",
///     audios: [audioContent]
/// )
///
/// // 複数のメディア
/// let input = LLMInput(
///     Prompt {
///         PromptComponent.objective("動画と音声を分析")
///     },
///     audios: [audioContent],
///     videos: [videoContent]
/// )
/// ```
public struct LLMInput: LLMInputProtocol, ExpressibleByStringLiteral {
    /// テキストプロンプト
    public let prompt: Prompt

    /// 画像コンテンツ
    public let images: [ImageContent]

    /// 音声コンテンツ
    public let audios: [AudioContent]

    /// 動画コンテンツ
    public let videos: [VideoContent]

    // MARK: - Initializers

    /// フル初期化
    ///
    /// すべてのプロパティを明示的に指定して初期化します。
    ///
    /// - Parameters:
    ///   - prompt: テキストプロンプト
    ///   - images: 画像コンテンツ（デフォルト: 空）
    ///   - audios: 音声コンテンツ（デフォルト: 空）
    ///   - videos: 動画コンテンツ（デフォルト: 空）
    public init(
        _ prompt: Prompt,
        images: [ImageContent] = [],
        audios: [AudioContent] = [],
        videos: [VideoContent] = []
    ) {
        self.prompt = prompt
        self.images = images
        self.audios = audios
        self.videos = videos
    }

    /// 文字列から初期化
    ///
    /// 単純なテキストプロンプトを作成します。
    ///
    /// - Parameters:
    ///   - text: プロンプトテキスト
    ///   - images: 画像コンテンツ（デフォルト: 空）
    ///   - audios: 音声コンテンツ（デフォルト: 空）
    ///   - videos: 動画コンテンツ（デフォルト: 空）
    public init(
        _ text: String,
        images: [ImageContent] = [],
        audios: [AudioContent] = [],
        videos: [VideoContent] = []
    ) {
        self.prompt = Prompt(stringLiteral: text)
        self.images = images
        self.audios = audios
        self.videos = videos
    }

    // MARK: - ExpressibleByStringLiteral

    public init(stringLiteral value: String) {
        self.prompt = Prompt(stringLiteral: value)
        self.images = []
        self.audios = []
        self.videos = []
    }
}

// MARK: - Convenience Extensions

extension LLMInput {
    /// 画像を追加した新しい入力を返す
    ///
    /// - Parameter image: 追加する画像
    /// - Returns: 画像が追加された新しい LLMInput
    public func adding(image: ImageContent) -> LLMInput {
        LLMInput(
            prompt,
            images: images + [image],
            audios: audios,
            videos: videos
        )
    }

    /// 複数の画像を追加した新しい入力を返す
    ///
    /// - Parameter images: 追加する画像の配列
    /// - Returns: 画像が追加された新しい LLMInput
    public func adding(images newImages: [ImageContent]) -> LLMInput {
        LLMInput(
            prompt,
            images: images + newImages,
            audios: audios,
            videos: videos
        )
    }

    /// 音声を追加した新しい入力を返す
    ///
    /// - Parameter audio: 追加する音声
    /// - Returns: 音声が追加された新しい LLMInput
    public func adding(audio: AudioContent) -> LLMInput {
        LLMInput(
            prompt,
            images: images,
            audios: audios + [audio],
            videos: videos
        )
    }

    /// 複数の音声を追加した新しい入力を返す
    ///
    /// - Parameter audios: 追加する音声の配列
    /// - Returns: 音声が追加された新しい LLMInput
    public func adding(audios newAudios: [AudioContent]) -> LLMInput {
        LLMInput(
            prompt,
            images: images,
            audios: audios + newAudios,
            videos: videos
        )
    }

    /// 動画を追加した新しい入力を返す
    ///
    /// - Parameter video: 追加する動画
    /// - Returns: 動画が追加された新しい LLMInput
    public func adding(video: VideoContent) -> LLMInput {
        LLMInput(
            prompt,
            images: images,
            audios: audios,
            videos: videos + [video]
        )
    }

    /// 複数の動画を追加した新しい入力を返す
    ///
    /// - Parameter videos: 追加する動画の配列
    /// - Returns: 動画が追加された新しい LLMInput
    public func adding(videos newVideos: [VideoContent]) -> LLMInput {
        LLMInput(
            prompt,
            images: images,
            audios: audios,
            videos: videos + newVideos
        )
    }
}

// MARK: - Prompt Conformance to LLMInputProtocol

extension Prompt: LLMInputProtocol {
    /// Prompt 自体をプロンプトとして返す
    public var prompt: Prompt { self }
}
