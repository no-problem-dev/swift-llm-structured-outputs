# マルチメディア機能 実装方針書

このドキュメントは、swift-llm-structured-outputs ライブラリにマルチメディア入出力機能を追加するための実装方針を定義します。

---

## 目次

1. [設計原則](#設計原則)
2. [アーキテクチャ概要](#アーキテクチャ概要)
3. [Phase 1: メディアコンテンツ型の定義](#phase-1-メディアコンテンツ型の定義)
4. [Phase 2: LLMMessage の拡張](#phase-2-llmmessage-の拡張)
5. [Phase 3: LLMResponse の拡張](#phase-3-llmresponse-の拡張)
6. [Phase 4: プロバイダー変換層](#phase-4-プロバイダー変換層)
7. [Phase 5: 機能可用性とエラーハンドリング](#phase-5-機能可用性とエラーハンドリング)
8. [Phase 6: 高レベルAPI](#phase-6-高レベルapi)
9. [ファイル構成](#ファイル構成)
10. [実装優先順位](#実装優先順位)

---

## 設計原則

### 1. 既存アーキテクチャの尊重

現在のライブラリは以下のレイヤー構造を持つ：

```
┌─────────────────────────────────────────────────────┐
│  High-Level API                                      │
│  (StructuredLLMClient, ChatCapableClient, etc.)     │
├─────────────────────────────────────────────────────┤
│  Client Layer                                        │
│  (AnthropicClient, OpenAIClient, GeminiClient)      │
├─────────────────────────────────────────────────────┤
│  Provider Layer                                      │
│  (AnthropicProvider, OpenAIProvider, GeminiProvider)│
├─────────────────────────────────────────────────────┤
│  Core Types                                          │
│  (LLMRequest, LLMMessage, LLMResponse)              │
└─────────────────────────────────────────────────────┘
```

マルチメディア対応は **Core Types レイヤーを拡張** し、**Provider Layer で差異を吸収** する。

### 2. 後方互換性の維持

既存のテキストベースAPIは **完全に互換** を維持する：

```swift
// 既存コード - そのまま動作
let message = LLMMessage.user("Hello")
let result: UserInfo = try await client.generate(prompt: "...", model: .sonnet)
```

### 3. 型安全性の最大化

Swift の型システムを活用し、**コンパイル時に無効な組み合わせを検出**：

```swift
// コンパイルエラー：Anthropicは動画入力未対応
let message = LLMMessage.user(contents: [.video(...)]) // ← 型レベルでの制約は難しいため、ランタイムチェック
```

### 4. プロバイダー間差異の吸収

各プロバイダーの API 形式差異は **Provider Layer で完全に吸収**：

```
LLMMessage.image(...)
    ├─ AnthropicProvider → { "type": "image", "source": {...} }
    ├─ OpenAIProvider    → { "type": "image_url", "image_url": {...} }
    └─ GeminiProvider    → { "inline_data": {...} }
```

### 5. 段階的な機能追加

入力機能を先に実装し、出力機能は後から追加：

```
Phase 1: メディア型定義 → Phase 2: 入力対応 → Phase 3: 出力対応 → Phase 4: 高レベルAPI
```

---

## アーキテクチャ概要

### 新規ファイル構成

```
Sources/LLMClient/
├── Media/                          # 新規ディレクトリ
│   ├── MediaTypes.swift            # メディアタイプ定義
│   ├── MediaSource.swift           # メディアソース定義
│   ├── MediaContent.swift          # 統合メディアコンテンツ
│   └── MediaCapabilities.swift     # プロバイダー機能可用性
├── Provider/
│   ├── AnthropicProvider.swift     # 既存（拡張）
│   ├── OpenAIProvider.swift        # 既存（拡張）
│   ├── GeminiProvider.swift        # 既存（拡張）
│   └── MediaConversion/            # 新規サブディレクトリ
│       ├── AnthropicMediaAdapter.swift
│       ├── OpenAIMediaAdapter.swift
│       └── GeminiMediaAdapter.swift
└── Provider/LLMProvider.swift      # 既存（拡張: LLMMessage.MessageContent）
```

### 依存関係

```
MediaTypes ← MediaSource ← MediaContent
                              ↓
                    LLMMessage.MessageContent
                              ↓
                   Provider MediaAdapters
```

---

## Phase 1: メディアコンテンツ型の定義

### 1.1 MediaTypes.swift

メディアタイプを enum で定義。各プロバイダーでサポートされる形式を明確化。

```swift
// Sources/LLMClient/Media/MediaTypes.swift

import Foundation

// MARK: - Image Media Type

/// 画像メディアタイプ
///
/// 各プロバイダーでサポートされる画像形式を定義します。
/// プロバイダー間の互換性情報も含みます。
public enum ImageMediaType: String, Sendable, Codable, CaseIterable {
    case jpeg = "image/jpeg"
    case png = "image/png"
    case gif = "image/gif"
    case webp = "image/webp"
    case heic = "image/heic"   // Gemini only
    case heif = "image/heif"   // Gemini only

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
}

// MARK: - Audio Media Type

/// 音声メディアタイプ
public enum AudioMediaType: String, Sendable, Codable, CaseIterable {
    case wav = "audio/wav"
    case mp3 = "audio/mp3"
    case aac = "audio/aac"
    case flac = "audio/flac"
    case ogg = "audio/ogg"
    case aiff = "audio/aiff"  // Gemini only

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

    /// OpenAI Chat Completions でサポートされるタイプ
    public static var openaiChatTypes: [AudioMediaType] {
        [.wav, .mp3]
    }

    /// Gemini でサポートされるタイプ
    public static var geminiTypes: [AudioMediaType] {
        AudioMediaType.allCases
    }
}

// MARK: - Video Media Type

/// 動画メディアタイプ
public enum VideoMediaType: String, Sendable, Codable, CaseIterable {
    case mp4 = "video/mp4"
    case avi = "video/avi"
    case mov = "video/quicktime"
    case mkv = "video/x-matroska"
    case webm = "video/webm"
    case flv = "video/x-flv"
    case mpeg = "video/mpeg"

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
        }
    }
}

// MARK: - Provider Type

/// プロバイダー識別子
public enum ProviderType: String, Sendable {
    case anthropic
    case openai
    case gemini
}
```

### 1.2 MediaSource.swift

メディアデータのソースを定義。Base64、URL、ファイル参照をサポート。

```swift
// Sources/LLMClient/Media/MediaSource.swift

import Foundation

// MARK: - Media Source

/// メディアデータのソース
///
/// メディアコンテンツは以下の3つの方法で提供できます：
/// - Base64エンコードされたバイナリデータ
/// - アクセス可能なURL
/// - プロバイダーのFile API経由のファイル参照
public enum MediaSource: Sendable, Equatable, Codable {
    /// Base64エンコードされたバイナリデータ
    case base64(Data)

    /// アクセス可能なURL（HTTP/HTTPS）
    case url(URL)

    /// ファイルAPI参照（Gemini File API, OpenAI Files API）
    case fileReference(id: String)

    // MARK: - Convenience Methods

    /// Base64文字列を取得
    public var base64String: String? {
        guard case .base64(let data) = self else { return nil }
        return data.base64EncodedString()
    }

    /// URLを取得
    public var urlValue: URL? {
        guard case .url(let url) = self else { return nil }
        return url
    }

    /// ファイル参照IDを取得
    public var fileReferenceId: String? {
        guard case .fileReference(let id) = self else { return nil }
        return id
    }

    // MARK: - Validation

    /// データサイズを取得（base64の場合のみ）
    public var dataSize: Int? {
        guard case .base64(let data) = self else { return nil }
        return data.count
    }

    /// 指定サイズ以下かチェック
    public func isWithinSizeLimit(_ maxBytes: Int) -> Bool {
        guard let size = dataSize else { return true }
        return size <= maxBytes
    }
}

// MARK: - Codable Implementation

extension MediaSource {
    private enum CodingKeys: String, CodingKey {
        case type
        case data
        case url
        case fileId
    }

    private enum SourceType: String, Codable {
        case base64
        case url
        case fileReference
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(SourceType.self, forKey: .type)

        switch type {
        case .base64:
            let data = try container.decode(Data.self, forKey: .data)
            self = .base64(data)
        case .url:
            let url = try container.decode(URL.self, forKey: .url)
            self = .url(url)
        case .fileReference:
            let id = try container.decode(String.self, forKey: .fileId)
            self = .fileReference(id: id)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .base64(let data):
            try container.encode(SourceType.base64, forKey: .type)
            try container.encode(data, forKey: .data)
        case .url(let url):
            try container.encode(SourceType.url, forKey: .type)
            try container.encode(url, forKey: .url)
        case .fileReference(let id):
            try container.encode(SourceType.fileReference, forKey: .type)
            try container.encode(id, forKey: .fileId)
        }
    }
}
```

### 1.3 MediaContent.swift

各メディアタイプのコンテンツを定義。

```swift
// Sources/LLMClient/Media/MediaContent.swift

import Foundation

// MARK: - Image Content

/// 画像コンテンツ
///
/// LLMに送信する画像データを表現します。
public struct ImageContent: Sendable, Equatable, Codable {
    /// データソース
    public let source: MediaSource

    /// メディアタイプ
    public let mediaType: ImageMediaType

    /// 詳細レベル（OpenAI専用）
    public let detail: ImageDetail?

    /// 詳細レベル
    public enum ImageDetail: String, Sendable, Codable {
        case low
        case high
        case auto
    }

    // MARK: - Initializers

    /// 初期化
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
    public static func base64(
        _ data: Data,
        mediaType: ImageMediaType,
        detail: ImageDetail? = nil
    ) -> ImageContent {
        ImageContent(source: .base64(data), mediaType: mediaType, detail: detail)
    }

    /// URLから初期化
    public static func url(
        _ url: URL,
        mediaType: ImageMediaType,
        detail: ImageDetail? = nil
    ) -> ImageContent {
        ImageContent(source: .url(url), mediaType: mediaType, detail: detail)
    }

    /// ファイルパスから初期化（メディアタイプを拡張子から推論）
    public static func file(
        at path: String,
        detail: ImageDetail? = nil
    ) throws -> ImageContent {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let mediaType = try inferMediaType(from: url)
        return ImageContent(source: .base64(data), mediaType: mediaType, detail: detail)
    }

    private static func inferMediaType(from url: URL) throws -> ImageMediaType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        case "gif": return .gif
        case "webp": return .webp
        case "heic": return .heic
        case "heif": return .heif
        default:
            throw MediaError.unsupportedFormat(ext)
        }
    }
}

// MARK: - Audio Content

/// 音声コンテンツ
public struct AudioContent: Sendable, Equatable, Codable {
    /// データソース
    public let source: MediaSource

    /// メディアタイプ
    public let mediaType: AudioMediaType

    // MARK: - Initializers

    public init(source: MediaSource, mediaType: AudioMediaType) {
        self.source = source
        self.mediaType = mediaType
    }

    /// Base64データから初期化
    public static func base64(_ data: Data, mediaType: AudioMediaType) -> AudioContent {
        AudioContent(source: .base64(data), mediaType: mediaType)
    }

    /// URLから初期化
    public static func url(_ url: URL, mediaType: AudioMediaType) -> AudioContent {
        AudioContent(source: .url(url), mediaType: mediaType)
    }
}

// MARK: - Video Content

/// 動画コンテンツ
public struct VideoContent: Sendable, Equatable, Codable {
    /// データソース
    public let source: MediaSource

    /// メディアタイプ
    public let mediaType: VideoMediaType

    // MARK: - Initializers

    public init(source: MediaSource, mediaType: VideoMediaType) {
        self.source = source
        self.mediaType = mediaType
    }

    /// Base64データから初期化
    public static func base64(_ data: Data, mediaType: VideoMediaType) -> VideoContent {
        VideoContent(source: .base64(data), mediaType: mediaType)
    }

    /// ファイル参照から初期化（大きな動画ファイル用）
    public static func fileReference(_ id: String, mediaType: VideoMediaType) -> VideoContent {
        VideoContent(source: .fileReference(id: id), mediaType: mediaType)
    }
}

// MARK: - Media Error

/// メディア関連エラー
public enum MediaError: Error, Sendable {
    /// サポートされていないフォーマット
    case unsupportedFormat(String)

    /// サイズ制限超過
    case sizeLimitExceeded(size: Int, maxSize: Int)

    /// プロバイダーが機能をサポートしていない
    case notSupportedByProvider(feature: String, provider: ProviderType)

    /// ファイル読み込みエラー
    case fileReadError(Error)

    /// 無効なメディアデータ
    case invalidMediaData(String)
}

extension MediaError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "Unsupported media format: \(format)"
        case .sizeLimitExceeded(let size, let maxSize):
            return "Media size (\(size) bytes) exceeds limit (\(maxSize) bytes)"
        case .notSupportedByProvider(let feature, let provider):
            return "\(feature) is not supported by \(provider.rawValue)"
        case .fileReadError(let error):
            return "Failed to read file: \(error.localizedDescription)"
        case .invalidMediaData(let reason):
            return "Invalid media data: \(reason)"
        }
    }
}
```

---

## Phase 2: LLMMessage の拡張

### 2.1 MessageContent enum の拡張

既存の `LLMMessage.MessageContent` に新しいケースを追加。

```swift
// Sources/LLMClient/Provider/LLMProvider.swift への変更

/// メッセージコンテンツの種類
public enum MessageContent: Sendable, Equatable, Codable {
    // MARK: - 既存（テキスト・ツール関連）

    /// テキストコンテンツ
    case text(String)

    /// ツール呼び出し（アシスタントが生成）
    case toolUse(id: String, name: String, input: Data)

    /// ツール実行結果
    case toolResult(toolCallId: String, name: String, content: String, isError: Bool)

    // MARK: - 新規（メディア入力）

    /// 画像コンテンツ
    case image(ImageContent)

    /// 音声コンテンツ
    case audio(AudioContent)

    /// 動画コンテンツ
    case video(VideoContent)
}
```

### 2.2 LLMMessage のファクトリメソッド追加

```swift
// LLMMessage extension

extension LLMMessage {
    // MARK: - 画像メッセージ

    /// テキストと画像を含むユーザーメッセージを作成
    ///
    /// ```swift
    /// let imageData = try Data(contentsOf: imageURL)
    /// let message = LLMMessage.user(
    ///     "この画像に何が写っていますか？",
    ///     image: .base64(imageData, mediaType: .jpeg)
    /// )
    /// ```
    public static func user(_ text: String, image: ImageContent) -> LLMMessage {
        LLMMessage(role: .user, contents: [.image(image), .text(text)])
    }

    /// 複数の画像を含むユーザーメッセージを作成
    public static func user(_ text: String, images: [ImageContent]) -> LLMMessage {
        var contents: [MessageContent] = images.map { .image($0) }
        contents.append(.text(text))
        return LLMMessage(role: .user, contents: contents)
    }

    // MARK: - 音声メッセージ

    /// テキストと音声を含むユーザーメッセージを作成
    ///
    /// ```swift
    /// let audioData = try Data(contentsOf: audioURL)
    /// let message = LLMMessage.user(
    ///     "この音声を文字起こししてください",
    ///     audio: .base64(audioData, mediaType: .wav)
    /// )
    /// ```
    public static func user(_ text: String, audio: AudioContent) -> LLMMessage {
        LLMMessage(role: .user, contents: [.audio(audio), .text(text)])
    }

    // MARK: - 動画メッセージ

    /// テキストと動画を含むユーザーメッセージを作成
    public static func user(_ text: String, video: VideoContent) -> LLMMessage {
        LLMMessage(role: .user, contents: [.video(video), .text(text)])
    }

    // MARK: - 複合メッセージ

    /// 任意のコンテンツを含むユーザーメッセージを作成
    ///
    /// ```swift
    /// let message = LLMMessage.user(contents: [
    ///     .text("以下の画像と音声について説明してください"),
    ///     .image(imageContent),
    ///     .audio(audioContent)
    /// ])
    /// ```
    public static func user(contents: [MessageContent]) -> LLMMessage {
        LLMMessage(role: .user, contents: contents)
    }

    // MARK: - Convenience Properties

    /// 画像コンテンツを取得
    public var images: [ImageContent] {
        contents.compactMap { content in
            if case .image(let image) = content { return image }
            return nil
        }
    }

    /// 音声コンテンツを取得
    public var audios: [AudioContent] {
        contents.compactMap { content in
            if case .audio(let audio) = content { return audio }
            return nil
        }
    }

    /// 動画コンテンツを取得
    public var videos: [VideoContent] {
        contents.compactMap { content in
            if case .video(let video) = content { return video }
            return nil
        }
    }

    /// メディアコンテンツを含むかどうか
    public var hasMediaContent: Bool {
        contents.contains { content in
            switch content {
            case .image, .audio, .video: return true
            default: return false
            }
        }
    }
}
```

---

## Phase 3: LLMResponse の拡張

### 3.1 ContentBlock の拡張

```swift
// LLMResponse.ContentBlock extension

extension LLMResponse {
    /// コンテンツブロック
    public enum ContentBlock: Sendable {
        // MARK: - 既存
        case text(String)
        case toolUse(id: String, name: String, input: Data)

        // MARK: - 新規（メディア出力）

        /// 生成された画像
        case generatedImage(GeneratedImage)

        /// 生成された音声
        case generatedAudio(GeneratedAudio)

        /// 動画生成ジョブ（非同期）
        case videoJob(VideoGenerationJob)
    }
}

// MARK: - Generated Image

/// 生成された画像
public struct GeneratedImage: Sendable {
    /// 画像データ（Base64デコード済み）
    public let data: Data

    /// メディアタイプ
    public let mediaType: ImageMediaType

    /// 修正されたプロンプト（OpenAI DALL-E）
    public let revisedPrompt: String?

    public init(data: Data, mediaType: ImageMediaType, revisedPrompt: String? = nil) {
        self.data = data
        self.mediaType = mediaType
        self.revisedPrompt = revisedPrompt
    }
}

// MARK: - Generated Audio

/// 生成された音声
public struct GeneratedAudio: Sendable {
    /// 音声データ（Base64デコード済み）
    public let data: Data

    /// 出力フォーマット
    public let format: AudioOutputFormat

    /// 音声のテキスト書き起こし
    public let transcript: String?

    /// 有効期限（OpenAI）
    public let expiresAt: Date?

    /// 音声ID（OpenAI）
    public let id: String?

    /// 音声出力フォーマット
    public enum AudioOutputFormat: String, Sendable {
        case wav
        case mp3
        case opus
        case aac
        case flac
        case pcm
    }

    public init(
        data: Data,
        format: AudioOutputFormat,
        transcript: String? = nil,
        expiresAt: Date? = nil,
        id: String? = nil
    ) {
        self.data = data
        self.format = format
        self.transcript = transcript
        self.expiresAt = expiresAt
        self.id = id
    }
}

// MARK: - Video Generation Job

/// 動画生成ジョブ（非同期生成用）
public struct VideoGenerationJob: Sendable {
    /// ジョブID
    public let id: String

    /// ステータス
    public let status: VideoStatus

    /// 進捗（0-100）
    public let progress: Int?

    /// ダウンロードURL（完了時のみ）
    public let downloadURL: URL?

    /// エラーメッセージ（失敗時のみ）
    public let errorMessage: String?

    /// 動画生成ステータス
    public enum VideoStatus: String, Sendable {
        case queued
        case inProgress
        case completed
        case failed
    }

    public init(
        id: String,
        status: VideoStatus,
        progress: Int? = nil,
        downloadURL: URL? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.status = status
        self.progress = progress
        self.downloadURL = downloadURL
        self.errorMessage = errorMessage
    }
}
```

---

## Phase 4: プロバイダー変換層

### 4.1 プロバイダー別アダプター

各プロバイダーの内部で、共通の `MessageContent` をプロバイダー固有の形式に変換。

#### AnthropicMediaAdapter

```swift
// Sources/LLMClient/Provider/MediaConversion/AnthropicMediaAdapter.swift

import Foundation

/// Anthropic用メディア変換アダプター
struct AnthropicMediaAdapter {

    /// MessageContent を Anthropic API 形式に変換
    static func convert(_ content: LLMMessage.MessageContent) throws -> Any {
        switch content {
        case .text(let text):
            return ["type": "text", "text": text]

        case .image(let imageContent):
            return try convertImage(imageContent)

        case .audio:
            throw MediaError.notSupportedByProvider(feature: "Audio input", provider: .anthropic)

        case .video:
            throw MediaError.notSupportedByProvider(feature: "Video input", provider: .anthropic)

        case .toolUse(let id, let name, let input):
            // 既存のツール呼び出し変換
            return ["type": "tool_use", "id": id, "name": name, "input": input]

        case .toolResult(let toolCallId, _, let content, let isError):
            return [
                "type": "tool_result",
                "tool_use_id": toolCallId,
                "content": content,
                "is_error": isError
            ]
        }
    }

    /// 画像コンテンツを Anthropic 形式に変換
    private static func convertImage(_ image: ImageContent) throws -> [String: Any] {
        // サポート確認
        guard image.mediaType.isSupported(by: .anthropic) else {
            throw MediaError.unsupportedFormat(image.mediaType.rawValue)
        }

        var source: [String: Any]

        switch image.source {
        case .base64(let data):
            source = [
                "type": "base64",
                "media_type": image.mediaType.rawValue,
                "data": data.base64EncodedString()
            ]
        case .url(let url):
            source = [
                "type": "url",
                "url": url.absoluteString
            ]
        case .fileReference:
            throw MediaError.notSupportedByProvider(
                feature: "File reference",
                provider: .anthropic
            )
        }

        return ["type": "image", "source": source]
    }
}
```

#### OpenAIMediaAdapter

```swift
// Sources/LLMClient/Provider/MediaConversion/OpenAIMediaAdapter.swift

import Foundation

/// OpenAI用メディア変換アダプター
struct OpenAIMediaAdapter {

    /// MessageContent を OpenAI API 形式に変換
    static func convert(_ content: LLMMessage.MessageContent) throws -> Any {
        switch content {
        case .text(let text):
            return ["type": "text", "text": text]

        case .image(let imageContent):
            return try convertImage(imageContent)

        case .audio(let audioContent):
            return try convertAudio(audioContent)

        case .video:
            throw MediaError.notSupportedByProvider(
                feature: "Direct video input (use frame extraction)",
                provider: .openai
            )

        case .toolUse, .toolResult:
            // 既存のツール変換ロジック
            fatalError("Tool conversion handled separately in OpenAIProvider")
        }
    }

    /// 画像コンテンツを OpenAI 形式に変換
    private static func convertImage(_ image: ImageContent) throws -> [String: Any] {
        var imageUrl: [String: Any]

        switch image.source {
        case .base64(let data):
            let dataUrl = "data:\(image.mediaType.rawValue);base64,\(data.base64EncodedString())"
            imageUrl = ["url": dataUrl]
        case .url(let url):
            imageUrl = ["url": url.absoluteString]
        case .fileReference(let id):
            imageUrl = ["url": id]  // Files API reference
        }

        // detail パラメータ（オプション）
        if let detail = image.detail {
            imageUrl["detail"] = detail.rawValue
        }

        return ["type": "image_url", "image_url": imageUrl]
    }

    /// 音声コンテンツを OpenAI 形式に変換
    private static func convertAudio(_ audio: AudioContent) throws -> [String: Any] {
        // OpenAI は base64 のみサポート
        guard case .base64(let data) = audio.source else {
            throw MediaError.notSupportedByProvider(
                feature: "Audio from URL (use base64)",
                provider: .openai
            )
        }

        // サポートされる形式を確認
        let format: String
        switch audio.mediaType {
        case .wav: format = "wav"
        case .mp3: format = "mp3"
        default:
            throw MediaError.unsupportedFormat(audio.mediaType.rawValue)
        }

        return [
            "type": "input_audio",
            "input_audio": [
                "data": data.base64EncodedString(),
                "format": format
            ]
        ]
    }
}
```

#### GeminiMediaAdapter

```swift
// Sources/LLMClient/Provider/MediaConversion/GeminiMediaAdapter.swift

import Foundation

/// Gemini用メディア変換アダプター
struct GeminiMediaAdapter {

    /// MessageContent を Gemini API 形式に変換
    static func convert(_ content: LLMMessage.MessageContent) throws -> Any {
        switch content {
        case .text(let text):
            return ["text": text]

        case .image(let imageContent):
            return try convertMedia(
                source: imageContent.source,
                mimeType: imageContent.mediaType.rawValue
            )

        case .audio(let audioContent):
            return try convertMedia(
                source: audioContent.source,
                mimeType: audioContent.mediaType.rawValue
            )

        case .video(let videoContent):
            return try convertMedia(
                source: videoContent.source,
                mimeType: videoContent.mediaType.rawValue
            )

        case .toolUse, .toolResult:
            fatalError("Tool conversion handled separately in GeminiProvider")
        }
    }

    /// メディアソースを Gemini 形式に変換（共通処理）
    private static func convertMedia(source: MediaSource, mimeType: String) throws -> [String: Any] {
        switch source {
        case .base64(let data):
            return [
                "inline_data": [
                    "mime_type": mimeType,
                    "data": data.base64EncodedString()
                ]
            ]
        case .url(let url):
            return [
                "file_data": [
                    "mime_type": mimeType,
                    "file_uri": url.absoluteString
                ]
            ]
        case .fileReference(let id):
            return [
                "file_data": [
                    "mime_type": mimeType,
                    "file_uri": id
                ]
            ]
        }
    }
}
```

---

## Phase 5: 機能可用性とエラーハンドリング

### 5.1 MediaCapabilities

```swift
// Sources/LLMClient/Media/MediaCapabilities.swift

import Foundation

/// プロバイダーのメディア機能可用性
public struct MediaCapabilities: Sendable {

    /// 画像入力サポート
    public let supportsImageInput: Bool

    /// 音声入力サポート
    public let supportsAudioInput: Bool

    /// 動画入力サポート
    public let supportsVideoInput: Bool

    /// 画像生成サポート
    public let supportsImageGeneration: Bool

    /// 音声生成サポート
    public let supportsAudioGeneration: Bool

    /// 動画生成サポート
    public let supportsVideoGeneration: Bool

    /// 最大画像サイズ（バイト）
    public let maxImageSize: Int

    /// 最大音声サイズ（バイト）
    public let maxAudioSize: Int?

    /// 最大動画サイズ（バイト）
    public let maxVideoSize: Int?

    // MARK: - Provider Capabilities

    /// Anthropic の機能
    public static let anthropic = MediaCapabilities(
        supportsImageInput: true,
        supportsAudioInput: false,
        supportsVideoInput: false,
        supportsImageGeneration: false,
        supportsAudioGeneration: false,
        supportsVideoGeneration: false,
        maxImageSize: 20 * 1024 * 1024,  // 20MB
        maxAudioSize: nil,
        maxVideoSize: nil
    )

    /// OpenAI の機能
    public static let openai = MediaCapabilities(
        supportsImageInput: true,
        supportsAudioInput: true,   // gpt-4o-audio-preview
        supportsVideoInput: false,  // フレーム分解が必要
        supportsImageGeneration: true,  // DALL-E / GPT-Image
        supportsAudioGeneration: true,  // TTS
        supportsVideoGeneration: true,  // Sora
        maxImageSize: 20 * 1024 * 1024,
        maxAudioSize: 20 * 1024 * 1024,
        maxVideoSize: nil
    )

    /// Gemini の機能
    public static let gemini = MediaCapabilities(
        supportsImageInput: true,
        supportsAudioInput: true,
        supportsVideoInput: true,
        supportsImageGeneration: true,
        supportsAudioGeneration: true,
        supportsVideoGeneration: true,
        maxImageSize: 20 * 1024 * 1024,  // inline
        maxAudioSize: 20 * 1024 * 1024,  // inline
        maxVideoSize: 20 * 1024 * 1024   // inline (File API: 2GB)
    )

    /// プロバイダータイプから機能を取得
    public static func capabilities(for provider: ProviderType) -> MediaCapabilities {
        switch provider {
        case .anthropic: return .anthropic
        case .openai: return .openai
        case .gemini: return .gemini
        }
    }
}
```

### 5.2 LLMError の拡張

```swift
// LLMProvider.swift への追加

extension LLMError {
    // MARK: - 新規メディア関連エラー

    /// メディアがプロバイダーでサポートされていない
    case mediaNotSupported(mediaType: String, provider: String)

    /// メディアサイズ制限超過
    case mediaSizeExceeded(size: Int, maxSize: Int)

    /// 無効なメディアフォーマット
    case invalidMediaFormat(format: String, supported: [String])

    /// メディアアップロード失敗
    case mediaUploadFailed(Error)

    /// 動画生成失敗
    case videoGenerationFailed(jobId: String, reason: String)

    /// 動画生成タイムアウト
    case videoGenerationTimeout(jobId: String)
}
```

---

## Phase 6: 高レベルAPI

### 6.1 ChatCapableClient の拡張

```swift
// Sources/LLMConversation/ChatCapableClient+Media.swift

extension ChatCapableClient {

    /// 画像を含むメッセージでチャット
    ///
    /// ```swift
    /// let imageData = try Data(contentsOf: imageURL)
    /// let response = try await client.chat(
    ///     "この画像に何が写っていますか？",
    ///     image: .base64(imageData, mediaType: .jpeg),
    ///     model: .sonnet
    /// )
    /// ```
    public func chat(
        _ text: String,
        image: ImageContent,
        model: Model,
        systemPrompt: String? = nil
    ) async throws -> ChatResponse {
        let message = LLMMessage.user(text, image: image)
        return try await chat(messages: [message], model: model, systemPrompt: systemPrompt)
    }

    /// 複数の画像を含むメッセージでチャット
    public func chat(
        _ text: String,
        images: [ImageContent],
        model: Model,
        systemPrompt: String? = nil
    ) async throws -> ChatResponse {
        let message = LLMMessage.user(text, images: images)
        return try await chat(messages: [message], model: model, systemPrompt: systemPrompt)
    }
}
```

---

## ファイル構成

### 新規作成ファイル

```
Sources/LLMClient/
├── Media/
│   ├── MediaTypes.swift              # メディアタイプ enum
│   ├── MediaSource.swift             # メディアソース enum
│   ├── MediaContent.swift            # ImageContent, AudioContent, VideoContent
│   ├── MediaCapabilities.swift       # プロバイダー機能可用性
│   └── GeneratedMedia.swift          # GeneratedImage, GeneratedAudio, VideoJob
├── Provider/
│   └── MediaConversion/
│       ├── AnthropicMediaAdapter.swift
│       ├── OpenAIMediaAdapter.swift
│       └── GeminiMediaAdapter.swift
```

### 既存変更ファイル

```
Sources/LLMClient/
├── Provider/
│   ├── LLMProvider.swift             # MessageContent 拡張、LLMError 拡張
│   ├── AnthropicProvider.swift       # convertToAnthropicMessages 拡張
│   ├── OpenAIProvider.swift          # convertToOpenAIMessages 拡張
│   └── GeminiProvider.swift          # convertToGeminiContents 拡張

Sources/LLMConversation/
├── ChatCapableClient+Media.swift     # 新規（便利メソッド）
```

---

## 実装優先順位

### Phase 1: 基盤型定義（優先度: 高）
1. MediaTypes.swift
2. MediaSource.swift
3. MediaContent.swift

### Phase 2: 入力サポート（優先度: 高）
1. LLMMessage.MessageContent 拡張
2. AnthropicMediaAdapter（画像のみ）
3. OpenAIMediaAdapter（画像 + 音声）
4. GeminiMediaAdapter（画像 + 音声 + 動画）

### Phase 3: 機能可用性（優先度: 中）
1. MediaCapabilities
2. LLMError 拡張
3. バリデーションロジック

### Phase 4: 出力サポート（優先度: 中）
1. GeneratedMedia 型定義
2. LLMResponse.ContentBlock 拡張
3. レスポンスパース拡張

### Phase 5: 高レベルAPI（優先度: 低）
1. ChatCapableClient+Media
2. ドキュメント更新
3. サンプルコード

---

## 検討事項

### 1. 大きなメディアファイルの扱い

- 20MB超のファイルは File API 経由が必須（Gemini, OpenAI）
- File API のラッパー実装を検討

### 2. ストリーミング対応

- 音声/動画のストリーミング入出力は将来検討
- 現在は非ストリーミング（バッチ）のみ

### 3. 生成系APIのエンドポイント分離

- 画像/音声/動画生成は別エンドポイント
- 専用クライアント or 既存クライアントの拡張

### 4. 非同期動画生成のポーリング

- Sora / Veo は非同期ジョブ
- ポーリングヘルパーの実装を検討

---

## 更新履歴

| 日付 | 内容 |
|------|------|
| 2025-12-20 | 初版作成 |
