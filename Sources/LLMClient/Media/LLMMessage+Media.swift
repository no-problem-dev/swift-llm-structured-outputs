// LLMMessage+Media.swift
// swift-llm-structured-outputs
//
// Created by Claude on 2025-12-20.

import Foundation

// MARK: - LLMMessage Media Extensions

extension LLMMessage {

    // MARK: - 画像メッセージ

    /// テキストと画像を含むユーザーメッセージを作成
    ///
    /// 画像は、Base64データまたはURLから作成できます。
    ///
    /// ## 使用例
    /// ```swift
    /// let imageData = try Data(contentsOf: imageURL)
    /// let message = LLMMessage.user(
    ///     "この画像に何が写っていますか？",
    ///     image: .base64(imageData, mediaType: .jpeg)
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - text: テキストメッセージ
    ///   - image: 画像コンテンツ
    /// - Returns: ユーザーメッセージ
    public static func user(_ text: String, image: ImageContent) -> LLMMessage {
        LLMMessage(role: .user, contents: [.image(image), .text(text)])
    }

    /// 複数の画像を含むユーザーメッセージを作成
    ///
    /// 複数の画像を同時に送信する場合に使用します。
    ///
    /// ## 使用例
    /// ```swift
    /// let images = [
    ///     ImageContent.base64(image1Data, mediaType: .jpeg),
    ///     ImageContent.base64(image2Data, mediaType: .png)
    /// ]
    /// let message = LLMMessage.user("これらの画像を比較してください", images: images)
    /// ```
    ///
    /// - Parameters:
    ///   - text: テキストメッセージ
    ///   - images: 画像コンテンツの配列
    /// - Returns: ユーザーメッセージ
    public static func user(_ text: String, images: [ImageContent]) -> LLMMessage {
        var contents: [MessageContent] = images.map { .image($0) }
        contents.append(.text(text))
        return LLMMessage(role: .user, contents: contents)
    }

    // MARK: - 音声メッセージ

    /// テキストと音声を含むユーザーメッセージを作成
    ///
    /// 音声ファイルを送信してトランスクリプションや分析を行う場合に使用します。
    ///
    /// ## 使用例
    /// ```swift
    /// let audioData = try Data(contentsOf: audioURL)
    /// let message = LLMMessage.user(
    ///     "この音声を文字起こししてください",
    ///     audio: .base64(audioData, mediaType: .wav)
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - text: テキストメッセージ
    ///   - audio: 音声コンテンツ
    /// - Returns: ユーザーメッセージ
    public static func user(_ text: String, audio: AudioContent) -> LLMMessage {
        LLMMessage(role: .user, contents: [.audio(audio), .text(text)])
    }

    // MARK: - 動画メッセージ

    /// テキストと動画を含むユーザーメッセージを作成
    ///
    /// 動画ファイルを送信して分析を行う場合に使用します。
    /// 現在、動画入力はGeminiのみでサポートされています。
    ///
    /// ## 使用例
    /// ```swift
    /// let message = LLMMessage.user(
    ///     "この動画の内容を説明してください",
    ///     video: .fileReference("files/video123", mediaType: .mp4)
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - text: テキストメッセージ
    ///   - video: 動画コンテンツ
    /// - Returns: ユーザーメッセージ
    public static func user(_ text: String, video: VideoContent) -> LLMMessage {
        LLMMessage(role: .user, contents: [.video(video), .text(text)])
    }

    // MARK: - 複合メッセージ

    /// 任意のコンテンツを含むユーザーメッセージを作成
    ///
    /// 複数種類のメディアを組み合わせる場合に使用します。
    ///
    /// ## 使用例
    /// ```swift
    /// let message = LLMMessage.user(contents: [
    ///     .text("以下の画像と音声について説明してください"),
    ///     .image(imageContent),
    ///     .audio(audioContent)
    /// ])
    /// ```
    ///
    /// - Parameter contents: メッセージコンテンツの配列
    /// - Returns: ユーザーメッセージ
    public static func user(contents: [MessageContent]) -> LLMMessage {
        LLMMessage(role: .user, contents: contents)
    }

    // MARK: - Convenience Properties

    /// 画像コンテンツを取得
    ///
    /// メッセージに含まれる全ての画像を配列で返します。
    public var images: [ImageContent] {
        contents.compactMap { content in
            if case .image(let image) = content { return image }
            return nil
        }
    }

    /// 音声コンテンツを取得
    ///
    /// メッセージに含まれる全ての音声を配列で返します。
    public var audios: [AudioContent] {
        contents.compactMap { content in
            if case .audio(let audio) = content { return audio }
            return nil
        }
    }

    /// 動画コンテンツを取得
    ///
    /// メッセージに含まれる全ての動画を配列で返します。
    public var videos: [VideoContent] {
        contents.compactMap { content in
            if case .video(let video) = content { return video }
            return nil
        }
    }

    /// メディアコンテンツを含むかどうか
    ///
    /// 画像、音声、または動画のいずれかを含む場合に `true` を返します。
    public var hasMediaContent: Bool {
        contents.contains { content in
            switch content {
            case .image, .audio, .video: return true
            default: return false
            }
        }
    }

    /// 画像を含むかどうか
    public var hasImage: Bool {
        contents.contains { if case .image = $0 { return true }; return false }
    }

    /// 音声を含むかどうか
    public var hasAudio: Bool {
        contents.contains { if case .audio = $0 { return true }; return false }
    }

    /// 動画を含むかどうか
    public var hasVideo: Bool {
        contents.contains { if case .video = $0 { return true }; return false }
    }
}
