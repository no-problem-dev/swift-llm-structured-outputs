// LLMInputProtocol.swift
// swift-llm-structured-outputs
//
// Created by Claude on 2025-12-21.

import Foundation

// MARK: - LLMInputProtocol

/// LLMへの入力を表すプロトコル
///
/// テキストプロンプトとマルチモーダルコンテンツ（画像、音声、動画）を
/// 統一的に扱うためのプロトコルです。
///
/// ## 概要
///
/// このプロトコルは、LLMに送信する入力を抽象化します。
/// テキストのみの入力から、画像・音声・動画を含むマルチモーダル入力まで
/// 一貫したインターフェースで扱えます。
///
/// ## 使用例
///
/// ```swift
/// // テキストのみ
/// let input = LLMInput("こんにちは")
///
/// // マルチモーダル（画像付き）
/// let input = LLMInput(
///     "この画像を分析してください",
///     images: [imageContent]
/// )
///
/// // Prompt DSL を使用
/// let input = LLMInput(
///     Prompt {
///         PromptComponent.role("データ分析の専門家")
///         PromptComponent.objective("画像から情報を抽出")
///     },
///     images: [imageContent]
/// )
/// ```
public protocol LLMInputProtocol: Sendable {
    /// テキストプロンプト
    var prompt: Prompt { get }

    /// 画像コンテンツ
    var images: [ImageContent] { get }

    /// 音声コンテンツ
    var audios: [AudioContent] { get }

    /// 動画コンテンツ
    var videos: [VideoContent] { get }
}

// MARK: - Default Implementations

extension LLMInputProtocol {
    /// 画像コンテンツ（デフォルト: 空）
    public var images: [ImageContent] { [] }

    /// 音声コンテンツ（デフォルト: 空）
    public var audios: [AudioContent] { [] }

    /// 動画コンテンツ（デフォルト: 空）
    public var videos: [VideoContent] { [] }

    /// メディアコンテンツを含むかどうか
    public var hasMediaContent: Bool {
        !images.isEmpty || !audios.isEmpty || !videos.isEmpty
    }

    /// LLMMessage に変換
    ///
    /// プロトコルに準拠した入力を、LLM API に送信可能な
    /// `LLMMessage` 形式に変換します。
    ///
    /// - Returns: ユーザーロールの LLMMessage
    public func toLLMMessage() -> LLMMessage {
        var contents: [LLMMessage.MessageContent] = []

        // メディアを先に追加（LLM API の慣例に従う）
        contents += images.map { .image($0) }
        contents += audios.map { .audio($0) }
        contents += videos.map { .video($0) }

        // テキストを追加
        let text = prompt.render()
        if !text.isEmpty {
            contents.append(.text(text))
        }

        return LLMMessage(role: .user, contents: contents)
    }

    /// プロバイダー互換性をバリデーション
    ///
    /// 入力に含まれるメディアコンテンツが、指定されたプロバイダーで
    /// サポートされているかを検証します。
    ///
    /// - Parameter provider: ターゲットプロバイダー
    /// - Throws: `MediaError` 互換性がない場合
    public func validate(for provider: ProviderType) throws {
        for image in images {
            try image.validate(for: provider)
        }
        for audio in audios {
            try audio.validate(for: provider)
        }
        for video in videos {
            try video.validate(for: provider)
        }
    }
}
