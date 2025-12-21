# マルチモーダル出力 設計方針書

本ドキュメントは、swift-llm-structured-outputs ライブラリにマルチモーダル出力機能を追加するための設計方針を定義します。

---

## 設計原則

### 1. 対称性（Symmetry）

入力側と出力側で一貫したパターンを採用します：

| 入力（実装済み） | 出力（新規） |
|-----------------|-------------|
| `ImageContent` | `GeneratedImage` |
| `AudioContent` | `GeneratedAudio` |
| `VideoContent` | `VideoGenerationJob` |
| `MediaContentProtocol` | `GeneratedMediaProtocol` |
| `MediaType` protocol | `OutputMediaFormat` protocol |

### 2. プロトコル指向設計（Protocol-Oriented Design）

既存の `StructuredLLMClient<Model>` パターンに倣い、機能別プロトコルを定義：

```swift
// 既存パターン
protocol StructuredLLMClient<Model>: Sendable {
    associatedtype Model: Sendable
    func generate<T: StructuredProtocol>(...) async throws -> T
}

// 新規：同じパターンで生成機能を追加
protocol ImageGenerationCapable<ImageModel>: Sendable {
    associatedtype ImageModel: Sendable
    func generateImage(...) async throws -> GeneratedImage
}
```

### 3. 型安全なモデル選択

入力/出力で異なるモデルが必要な場合があります（例：テキスト生成は GPT-4o、画像生成は DALL-E）。
型システムでこれを表現：

```swift
// 既存：テキスト生成モデル
OpenAIClient: StructuredLLMClient where Model == GPTModel

// 新規：画像生成モデル
OpenAIClient: ImageGenerationCapable where ImageModel == OpenAIImageModel
```

### 4. 段階的実装（Incremental Implementation）

```
Phase 1: 出力コンテンツ型の定義
Phase 2: 生成機能プロトコルの定義
Phase 3: OpenAI 画像生成の実装
Phase 4: Gemini 画像生成の実装
Phase 5: 音声生成の実装
Phase 6: 動画生成の実装（非同期ジョブ）
```

---

## アーキテクチャ

### レイヤー構造

```
┌─────────────────────────────────────────────────────────┐
│  High-Level API                                         │
│  - StructuredLLMClient (既存)                           │
│  - ImageGenerationCapable (新規)                        │
│  - AudioGenerationCapable (新規)                        │
│  - VideoGenerationCapable (新規)                        │
├─────────────────────────────────────────────────────────┤
│  Client Layer                                           │
│  - OpenAIClient + ImageGenerationCapable                │
│  - GeminiClient + ImageGenerationCapable                │
│  - (Anthropic: 生成機能なし)                            │
├─────────────────────────────────────────────────────────┤
│  Provider Layer                                         │
│  - OpenAIImageProvider (新規)                           │
│  - OpenAIAudioProvider (新規)                           │
│  - OpenAIVideoProvider (新規)                           │
│  - GeminiMediaProvider (新規: 統一エンドポイント)       │
├─────────────────────────────────────────────────────────┤
│  Core Types                                             │
│  - GeneratedImage, GeneratedAudio (新規)                │
│  - VideoGenerationJob (新規)                            │
│  - OutputMediaFormat protocol (新規)                    │
│  - LLMResponse.ContentBlock 拡張 (新規)                 │
└─────────────────────────────────────────────────────────┘
```

---

## 型定義

### 1. 出力メディアフォーマット（OutputMediaFormat Protocol）

入力側の `MediaType` プロトコルに対応：

```swift
/// 出力メディアフォーマット共通プロトコル
public protocol OutputMediaFormat: RawRepresentable, Sendable, Codable
    where RawValue == String {
    /// ファイル拡張子
    var fileExtension: String { get }
    /// MIME タイプ文字列
    var mimeType: String { get }
}

/// 画像出力フォーマット
public enum ImageOutputFormat: String, OutputMediaFormat, CaseIterable {
    case png = "image/png"
    case jpeg = "image/jpeg"
    case webp = "image/webp"

    public var fileExtension: String { ... }
    public var mimeType: String { rawValue }
}

/// 音声出力フォーマット
public enum AudioOutputFormat: String, OutputMediaFormat, CaseIterable {
    case mp3 = "audio/mp3"
    case wav = "audio/wav"
    case opus = "audio/opus"
    case aac = "audio/aac"
    case flac = "audio/flac"
    case pcm = "audio/pcm"  // Gemini TTS

    public var fileExtension: String { ... }
    public var mimeType: String { rawValue }
}
```

### 2. 生成コンテンツ型（Generated Content Types）

入力側の `ImageContent` などに対応する出力型：

```swift
/// 生成メディアコンテンツ共通プロトコル
public protocol GeneratedMediaProtocol: Sendable, Codable {
    /// 生成されたデータ
    var data: Data { get }
    /// MIME タイプ文字列
    var mimeType: String { get }
    /// ファイル保存用の拡張子
    var fileExtension: String { get }
}

/// 生成された画像
public struct GeneratedImage: GeneratedMediaProtocol, Equatable {
    public let data: Data
    public let format: ImageOutputFormat

    /// 修正されたプロンプト（OpenAI DALL-E/GPT-Image）
    public let revisedPrompt: String?

    // GeneratedMediaProtocol
    public var mimeType: String { format.mimeType }
    public var fileExtension: String { format.fileExtension }

    // MARK: - Convenience

    /// UIImage に変換（iOS/macOS）
    #if canImport(UIKit)
    public var uiImage: UIImage? { UIImage(data: data) }
    #endif

    #if canImport(AppKit)
    public var nsImage: NSImage? { NSImage(data: data) }
    #endif

    /// ファイルに保存
    public func save(to url: URL) throws {
        try data.write(to: url)
    }
}

/// 生成された音声
public struct GeneratedAudio: GeneratedMediaProtocol, Equatable {
    public let data: Data
    public let format: AudioOutputFormat

    /// 音声のテキスト書き起こし（OpenAI audio-preview）
    public let transcript: String?

    /// 音声ID（OpenAI: 会話継続用）
    public let id: String?

    /// 有効期限（OpenAI）
    public let expiresAt: Date?

    // GeneratedMediaProtocol
    public var mimeType: String { format.mimeType }
    public var fileExtension: String { format.fileExtension }
}

/// 動画生成ジョブ（非同期生成）
public struct VideoGenerationJob: Sendable, Codable, Equatable {
    public let id: String
    public let status: VideoStatus
    public let progress: Int?

    /// ダウンロードURL（完了時のみ）
    public let downloadURL: URL?

    /// エラーメッセージ（失敗時のみ）
    public let errorMessage: String?

    /// 動画生成ステータス
    public enum VideoStatus: String, Sendable, Codable {
        case queued
        case inProgress = "in_progress"
        case completed
        case failed
    }

    /// 完了しているか
    public var isCompleted: Bool { status == .completed }

    /// 失敗したか
    public var isFailed: Bool { status == .failed }

    /// 進行中か
    public var isInProgress: Bool { status == .queued || status == .inProgress }
}
```

### 3. LLMResponse.ContentBlock 拡張

既存の `ContentBlock` に生成コンテンツを追加：

```swift
extension LLMResponse {
    public enum ContentBlock: Sendable {
        // 既存
        case text(String)
        case toolUse(id: String, name: String, input: Data)

        // 新規：生成コンテンツ
        case generatedImage(GeneratedImage)
        case generatedAudio(GeneratedAudio)

        // 既存プロパティ
        public var text: String? { ... }

        // 新規：生成コンテンツ取得
        public var generatedImage: GeneratedImage? {
            if case .generatedImage(let image) = self { return image }
            return nil
        }

        public var generatedAudio: GeneratedAudio? {
            if case .generatedAudio(let audio) = self { return audio }
            return nil
        }
    }
}
```

---

## 生成機能プロトコル

### 1. 画像生成（ImageGenerationCapable）

```swift
/// 画像生成オプション
public struct ImageGenerationOptions: Sendable {
    /// 生成枚数（1-4）
    public let count: Int?

    /// サイズ
    public let size: ImageSize?

    /// 品質（OpenAI）
    public let quality: ImageQuality?

    /// スタイル（OpenAI DALL-E）
    public let style: ImageStyle?

    /// 出力フォーマット
    public let format: ImageOutputFormat?

    public enum ImageSize: Sendable {
        case square1024      // 1024x1024
        case landscape       // 1792x1024
        case portrait        // 1024x1792
        case custom(width: Int, height: Int)
    }

    public enum ImageQuality: String, Sendable {
        case standard
        case hd
    }

    public enum ImageStyle: String, Sendable {
        case natural
        case vivid
    }

    public static let `default` = ImageGenerationOptions()
}

/// 画像生成機能プロトコル
public protocol ImageGenerationCapable<ImageModel>: Sendable {
    associatedtype ImageModel: Sendable

    /// 画像を生成
    ///
    /// - Parameters:
    ///   - prompt: 画像を説明するプロンプト
    ///   - model: 使用するモデル
    ///   - options: 生成オプション
    /// - Returns: 生成された画像（複数の場合は配列）
    func generateImage(
        prompt: String,
        model: ImageModel,
        options: ImageGenerationOptions?
    ) async throws -> [GeneratedImage]

    /// 単一画像を生成（便利メソッド）
    func generateImage(
        prompt: String,
        model: ImageModel
    ) async throws -> GeneratedImage
}

// デフォルト実装
extension ImageGenerationCapable {
    public func generateImage(
        prompt: String,
        model: ImageModel
    ) async throws -> GeneratedImage {
        let images = try await generateImage(prompt: prompt, model: model, options: nil)
        guard let first = images.first else {
            throw LLMError.emptyResponse
        }
        return first
    }
}
```

### 2. 音声生成（AudioGenerationCapable）

```swift
/// 音声生成オプション
public struct SpeechGenerationOptions: Sendable {
    /// 声のID
    public let voice: String?

    /// 出力フォーマット
    public let format: AudioOutputFormat?

    /// 速度（0.25-4.0）
    public let speed: Double?

    /// 音声指示（OpenAI gpt-4o-mini-tts）
    public let instructions: String?

    public static let `default` = SpeechGenerationOptions()
}

/// 音声生成機能プロトコル
public protocol AudioGenerationCapable<AudioModel>: Sendable {
    associatedtype AudioModel: Sendable

    /// テキストから音声を生成
    ///
    /// - Parameters:
    ///   - text: 読み上げるテキスト
    ///   - model: 使用するモデル
    ///   - options: 生成オプション
    /// - Returns: 生成された音声
    func generateSpeech(
        text: String,
        model: AudioModel,
        options: SpeechGenerationOptions?
    ) async throws -> GeneratedAudio
}
```

### 3. 動画生成（VideoGenerationCapable）

```swift
/// 動画生成オプション
public struct VideoGenerationOptions: Sendable {
    /// サイズ
    public let size: VideoSize?

    /// 長さ（秒）
    public let duration: Int?

    public enum VideoSize: String, Sendable {
        case portrait720 = "720x1280"
        case landscape720 = "1280x720"
        case portrait1024 = "1024x1792"
        case landscape1024 = "1792x1024"
    }

    public static let `default` = VideoGenerationOptions()
}

/// 動画生成機能プロトコル（非同期ジョブベース）
public protocol VideoGenerationCapable<VideoModel>: Sendable {
    associatedtype VideoModel: Sendable

    /// 動画生成を開始
    ///
    /// - Parameters:
    ///   - prompt: 動画を説明するプロンプト
    ///   - model: 使用するモデル
    ///   - options: 生成オプション
    /// - Returns: 生成ジョブ
    func startVideoGeneration(
        prompt: String,
        model: VideoModel,
        options: VideoGenerationOptions?
    ) async throws -> VideoGenerationJob

    /// ジョブのステータスを確認
    ///
    /// - Parameter jobId: ジョブID
    /// - Returns: 更新されたジョブ情報
    func checkVideoStatus(jobId: String) async throws -> VideoGenerationJob

    /// 完了した動画をダウンロード
    ///
    /// - Parameter job: 完了したジョブ
    /// - Returns: 動画データ
    func downloadVideo(job: VideoGenerationJob) async throws -> Data

    /// 動画生成を待機（ポーリング）
    ///
    /// - Parameters:
    ///   - job: 生成ジョブ
    ///   - timeout: タイムアウト（秒）
    ///   - pollingInterval: ポーリング間隔（秒）
    /// - Returns: 完了したジョブ
    func waitForVideo(
        job: VideoGenerationJob,
        timeout: TimeInterval,
        pollingInterval: TimeInterval
    ) async throws -> VideoGenerationJob
}
```

---

## モデル定義

### OpenAI 画像生成モデル

```swift
/// OpenAI 画像生成モデル
public enum OpenAIImageModel: Sendable, Equatable {
    // Aliases（推奨）
    case gptImage        // 最新の GPT-Image
    case gptImageMini    // 軽量版
    case dalle3          // DALL-E 3（2026年廃止予定）

    // Fixed versions
    case gptImage_version(String)
    case dalle3_version(String)

    // Custom
    case custom(String)

    public var id: String { ... }
}
```

### OpenAI 音声生成モデル

```swift
/// OpenAI 音声生成モデル
public enum OpenAIAudioModel: Sendable, Equatable {
    case tts1        // 標準TTS
    case tts1HD      // 高品質TTS
    case gpt4oTTS    // GPT-4o-mini-tts（表現力高）
    case custom(String)

    public var id: String { ... }
}
```

### OpenAI 動画生成モデル

```swift
/// OpenAI 動画生成モデル
public enum OpenAISoraModel: Sendable, Equatable {
    case sora2       // 高速
    case sora2Pro    // 高品質
    case custom(String)

    public var id: String { ... }
}
```

### Gemini メディア生成モデル

```swift
/// Gemini 画像生成モデル
public enum GeminiImageModel: Sendable, Equatable {
    case flash25Image    // gemini-2.5-flash-image
    case pro3Image       // gemini-3-pro-image-preview
    case imagen4         // imagen-4.0-generate-001
    case custom(String)

    public var id: String { ... }
}

/// Gemini 音声生成モデル
public enum GeminiAudioModel: Sendable, Equatable {
    case flash25TTS      // gemini-2.5-flash-preview-tts
    case pro25TTS        // gemini-2.5-pro-preview-tts
    case custom(String)

    public var id: String { ... }
}

/// Gemini 動画生成モデル
public enum GeminiVideoModel: Sendable, Equatable {
    case veo2            // veo-2
    case veo31           // veo-3.1
    case veo31Fast       // veo-3.1-fast
    case custom(String)

    public var id: String { ... }
}
```

---

## クライアント拡張

### OpenAIClient 拡張

```swift
// 既存
extension OpenAIClient: StructuredLLMClient {
    typealias Model = GPTModel
}

// 新規：プロトコル準拠
extension OpenAIClient: ImageGenerationCapable {
    public typealias ImageModel = OpenAIImageModel

    public func generateImage(
        prompt: String,
        model: OpenAIImageModel,
        options: ImageGenerationOptions?
    ) async throws -> [GeneratedImage] {
        // POST /v1/images/generations
        ...
    }
}

extension OpenAIClient: AudioGenerationCapable {
    public typealias AudioModel = OpenAIAudioModel

    public func generateSpeech(
        text: String,
        model: OpenAIAudioModel,
        options: SpeechGenerationOptions?
    ) async throws -> GeneratedAudio {
        // POST /v1/audio/speech
        ...
    }
}

extension OpenAIClient: VideoGenerationCapable {
    public typealias VideoModel = OpenAISoraModel

    public func startVideoGeneration(...) async throws -> VideoGenerationJob {
        // POST /v1/videos/generations
        ...
    }

    public func checkVideoStatus(jobId: String) async throws -> VideoGenerationJob {
        // GET /v1/videos/{id}
        ...
    }
}
```

### GeminiClient 拡張

```swift
extension GeminiClient: ImageGenerationCapable {
    public typealias ImageModel = GeminiImageModel

    public func generateImage(
        prompt: String,
        model: GeminiImageModel,
        options: ImageGenerationOptions?
    ) async throws -> [GeneratedImage] {
        // POST /models/{model}:generateContent
        // with responseModalities: ["TEXT", "IMAGE"]
        ...
    }
}

extension GeminiClient: AudioGenerationCapable {
    public typealias AudioModel = GeminiAudioModel

    public func generateSpeech(
        text: String,
        model: GeminiAudioModel,
        options: SpeechGenerationOptions?
    ) async throws -> GeneratedAudio {
        // POST /models/{model}:generateContent
        // with responseModalities: ["AUDIO"]
        ...
    }
}

extension GeminiClient: VideoGenerationCapable {
    public typealias VideoModel = GeminiVideoModel

    public func startVideoGeneration(...) async throws -> VideoGenerationJob {
        // POST /models/{model}:generate
        ...
    }
}
```

---

## エラーハンドリング

### LLMError 拡張

```swift
public enum LLMError: Error, Sendable {
    // 既存...

    // 新規：生成関連

    /// 画像生成に失敗
    case imageGenerationFailed(reason: String)

    /// 音声生成に失敗
    case speechGenerationFailed(reason: String)

    /// 動画生成に失敗
    case videoGenerationFailed(jobId: String, reason: String)

    /// 動画生成タイムアウト
    case videoGenerationTimeout(jobId: String)

    /// プロンプトが安全性フィルターに引っかかった
    case promptBlocked(reason: String?)

    /// 生成機能がサポートされていない
    case generationNotSupported(type: String, provider: String)
}
```

---

## ファイル構成

### 新規作成ファイル

```
Sources/LLMClient/
├── Media/
│   ├── Output/                          # 新規ディレクトリ
│   │   ├── OutputMediaFormat.swift      # 出力フォーマット型
│   │   ├── GeneratedImage.swift         # 生成画像型
│   │   ├── GeneratedAudio.swift         # 生成音声型
│   │   └── VideoGenerationJob.swift     # 動画生成ジョブ型
│   │
│   └── Generation/                      # 新規ディレクトリ
│       ├── ImageGenerationCapable.swift # 画像生成プロトコル
│       ├── AudioGenerationCapable.swift # 音声生成プロトコル
│       ├── VideoGenerationCapable.swift # 動画生成プロトコル
│       ├── ImageGenerationOptions.swift # 画像生成オプション
│       ├── SpeechGenerationOptions.swift # 音声生成オプション
│       └── VideoGenerationOptions.swift # 動画生成オプション
│
├── Client/
│   ├── OpenAI/                          # 新規サブディレクトリ
│   │   ├── OpenAIClient+ImageGeneration.swift
│   │   ├── OpenAIClient+AudioGeneration.swift
│   │   ├── OpenAIClient+VideoGeneration.swift
│   │   ├── OpenAIImageModel.swift
│   │   ├── OpenAIAudioModel.swift
│   │   └── OpenAISoraModel.swift
│   │
│   └── Gemini/                          # 新規サブディレクトリ
│       ├── GeminiClient+ImageGeneration.swift
│       ├── GeminiClient+AudioGeneration.swift
│       ├── GeminiClient+VideoGeneration.swift
│       ├── GeminiImageModel.swift
│       ├── GeminiAudioModel.swift
│       └── GeminiVideoModel.swift
│
└── Provider/
    ├── OpenAIImageProvider.swift        # 画像生成プロバイダー
    ├── OpenAIAudioProvider.swift        # 音声生成プロバイダー
    ├── OpenAIVideoProvider.swift        # 動画生成プロバイダー
    └── GeminiGenerationProvider.swift   # Gemini 生成プロバイダー
```

### 既存変更ファイル

```
Sources/LLMClient/
├── Provider/
│   └── LLMProvider.swift                # LLMError 拡張
│       └── LLMResponse.ContentBlock 拡張
```

---

## 実装優先順位

### Phase 1: 基盤型定義（高優先度）

1. `OutputMediaFormat` プロトコルと具体型
2. `GeneratedImage`, `GeneratedAudio` 型
3. `VideoGenerationJob` 型
4. `LLMResponse.ContentBlock` 拡張

### Phase 2: 画像生成（高優先度）

1. `ImageGenerationCapable` プロトコル
2. `ImageGenerationOptions` 型
3. `OpenAIImageModel` 型
4. `OpenAIClient+ImageGeneration` 実装
5. `GeminiImageModel` 型
6. `GeminiClient+ImageGeneration` 実装

### Phase 3: 音声生成（中優先度）

1. `AudioGenerationCapable` プロトコル
2. `SpeechGenerationOptions` 型
3. `OpenAIAudioModel` 型
4. `OpenAIClient+AudioGeneration` 実装
5. `GeminiAudioModel` 型
6. `GeminiClient+AudioGeneration` 実装

### Phase 4: 動画生成（低優先度）

1. `VideoGenerationCapable` プロトコル
2. `VideoGenerationOptions` 型
3. `OpenAISoraModel`, `GeminiVideoModel` 型
4. 各クライアント実装

---

## 設計判断の根拠

### 1. 別プロトコルとした理由

画像/音声/動画生成を `StructuredLLMClient` に統合せず、別プロトコルとした理由：

- **エンドポイントの違い**: テキスト生成とは異なるエンドポイントを使用
- **モデルの違い**: 生成タスクには専用モデルが必要
- **レスポンス形式の違い**: 構造化出力ではなくバイナリデータを返す
- **プロバイダー対応の違い**: Anthropic は生成機能なし

### 2. associatedtype を使う理由

```swift
protocol ImageGenerationCapable<ImageModel>: Sendable {
    associatedtype ImageModel: Sendable
}
```

- 既存の `StructuredLLMClient<Model>` と同じパターンを維持
- プロバイダー固有のモデル型を安全に使用可能
- コンパイル時に不正なモデル指定を検出

### 3. Options を struct にした理由

```swift
public struct ImageGenerationOptions: Sendable { ... }
```

- プロバイダー間で共通のオプションを定義可能
- プロバイダー固有のオプションは拡張で追加可能
- デフォルト値を `.default` で提供

### 4. 動画を非同期ジョブにした理由

```swift
func startVideoGeneration(...) async throws -> VideoGenerationJob
func checkVideoStatus(jobId: String) async throws -> VideoGenerationJob
```

- 動画生成は数分〜数十分かかる
- 同期的に待機するのは非現実的
- ポーリングまたはWebhook対応が必要

---

## 使用例

### 画像生成

```swift
let client = OpenAIClient(apiKey: "...")

// シンプルな使用
let image = try await client.generateImage(
    prompt: "A cat sitting on a window sill",
    model: .gptImage
)
try image.save(to: URL(fileURLWithPath: "cat.png"))

// オプション指定
let images = try await client.generateImage(
    prompt: "A futuristic city",
    model: .dalle3,
    options: ImageGenerationOptions(
        count: 2,
        size: .landscape,
        quality: .hd,
        style: .vivid
    )
)
```

### 音声生成

```swift
let client = OpenAIClient(apiKey: "...")

let audio = try await client.generateSpeech(
    text: "こんにちは、今日はいい天気ですね。",
    model: .tts1HD,
    options: SpeechGenerationOptions(
        voice: "nova",
        format: .mp3
    )
)
try audio.save(to: URL(fileURLWithPath: "greeting.mp3"))
```

### 動画生成

```swift
let client = OpenAIClient(apiKey: "...")

// 生成開始
let job = try await client.startVideoGeneration(
    prompt: "A cat walking through a garden",
    model: .sora2,
    options: VideoGenerationOptions(
        size: .landscape720,
        duration: 8
    )
)

// 完了まで待機
let completedJob = try await client.waitForVideo(
    job: job,
    timeout: 600,  // 10分
    pollingInterval: 10
)

// ダウンロード
let videoData = try await client.downloadVideo(job: completedJob)
try videoData.write(to: URL(fileURLWithPath: "cat.mp4"))
```

---

## 更新履歴

| 日付 | 内容 |
|------|------|
| 2025-12-20 | 初版作成 |
