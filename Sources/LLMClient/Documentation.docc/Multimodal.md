# マルチモーダル

画像・音声・動画の入力（Vision）と生成機能。

@Metadata {
    @PageColor(blue)
}

## 概要

LLMClient は、テキストだけでなく画像・音声・動画を扱うマルチモーダル機能を提供します。入力（Vision）と生成の両方に対応しています。

### プロバイダー対応表

| 機能 | Anthropic | OpenAI | Gemini |
|------|:---------:|:------:|:------:|
| 画像入力 | ✓ | ✓ | ✓ |
| 音声入力 | - | ✓ | ✓ |
| 動画入力 | - | - | ✓ |
| 画像生成 | - | ✓ | ✓ |
| 音声生成 | - | ✓ | - |
| 動画生成 | - | ✓ | ✓ |

## メディア入力（Vision）

### 画像解析

画像を含むメッセージを送信して、LLM に解析させます。

```swift
import LLMStructuredOutputs

// 画像データを読み込み
let imageData = try Data(contentsOf: imageURL)
let image = ImageContent.base64(imageData, mediaType: .jpeg)

// 画像付きメッセージを作成
let message = LLMMessage.user("この画像に何が写っていますか？", image: image)

// 構造化出力で解析結果を取得
@Structured("画像解析結果")
struct ImageAnalysis {
    @StructuredField("説明") var description: String
    @StructuredField("検出されたオブジェクト") var objects: [String]
}

let result: ImageAnalysis = try await client.generate(
    messages: [message],
    model: .sonnet
)
```

### 複数画像の比較

```swift
let images = [
    ImageContent.base64(image1Data, mediaType: .jpeg),
    ImageContent.base64(image2Data, mediaType: .png)
]

let message = LLMMessage.user("これらの画像を比較してください", images: images)
```

### 音声解析

音声ファイルを送信してトランスクリプションや分析を行います（OpenAI、Gemini のみ）。

```swift
let audioData = try Data(contentsOf: audioURL)
let audio = AudioContent.base64(audioData, mediaType: .wav)

let message = LLMMessage.user("この音声を文字起こししてください", audio: audio)
```

### 動画解析

動画ファイルを解析します（Gemini のみ）。

```swift
// Gemini File API でアップロード済みの動画を参照
let video = VideoContent.fileReference("files/video123", mediaType: .mp4)

let message = LLMMessage.user("この動画の内容を説明してください", video: video)
```

### メディアソース

メディアコンテンツは3種類のソースから作成できます：

```swift
// Base64 データ
let image1 = ImageContent.base64(data, mediaType: .jpeg)

// URL
let image2 = ImageContent.url(URL(string: "https://example.com/image.jpg")!, mediaType: .jpeg)

// ファイル参照（Gemini File API）
let video = VideoContent.fileReference("files/video123", mediaType: .mp4)
```

## 画像生成

### OpenAI（DALL-E、GPT-Image）

```swift
let client = OpenAIClient(apiKey: "sk-...")

// DALL-E 3 で画像生成
let image = try await client.generateImage(
    prompt: "夕焼けの海辺で遊ぶ猫",
    model: .dalle3,
    size: .square1024,
    quality: .hd
)

// 画像を保存
try image.save(to: URL(fileURLWithPath: "cat.png"))

// UIImage/NSImage として取得
let uiImage = image.uiImage  // iOS
let nsImage = image.nsImage  // macOS
```

### Gemini（Imagen 4）

```swift
let client = GeminiClient(apiKey: "...")

let image = try await client.generateImage(
    prompt: "未来都市の風景",
    model: .imagen4,
    size: .landscape1536x1024
)
```

### 利用可能なモデル

**OpenAI:**
- `.dalle3` - DALL-E 3（高品質）
- `.dalle2` - DALL-E 2（従来モデル）
- `.gptImage` - GPT-Image（GPT-4o ベース）

**Gemini:**
- `.imagen4` - Imagen 4（標準）
- `.imagen4Ultra` - Imagen 4 Ultra（最高品質）
- `.imagen4Fast` - Imagen 4 Fast（高速）
- `.gemini20FlashImage` - Gemini 2.0 Flash Image

## 音声生成（TTS）

テキストから音声を生成します（OpenAI のみ）。

```swift
let client = OpenAIClient(apiKey: "sk-...")

let audio = try await client.generateSpeech(
    text: "こんにちは、世界！",
    model: .tts1HD,
    voice: .nova,
    speed: 1.0,
    format: .mp3
)

// 音声を保存
try audio.save(to: URL(fileURLWithPath: "greeting.mp3"))

// AVAudioPlayer で再生
let player = try audio.audioPlayer()
player.play()
```

### 利用可能な声

| 声 | 特徴 |
|-----|------|
| `.alloy` | 中性的 |
| `.echo` | 男性的 |
| `.fable` | 男性的（British） |
| `.onyx` | 深い男性 |
| `.nova` | 女性的 |
| `.shimmer` | 女性的（柔らかい） |

## 動画生成

動画生成は非同期ジョブとして処理されます。

### OpenAI（Sora 2）

```swift
let client = OpenAIClient(apiKey: "sk-...")

// 同期的に完了まで待機
let video = try await client.generateVideo(
    prompt: "海辺を走る犬のスローモーション映像",
    model: .sora2,
    duration: 8,
    aspectRatio: .landscape16x9
)

try video.save(to: URL(fileURLWithPath: "dog.mp4"))
```

### Gemini（Veo）

```swift
let client = GeminiClient(apiKey: "...")

let video = try await client.generateVideo(
    prompt: "宇宙から見た地球の夜景",
    model: .veo31,
    duration: 6
)

// リモートURLからダウンロード
if let remoteURL = video.remoteURL {
    let localVideo = try await video.download()
    try localVideo.save(to: URL(fileURLWithPath: "earth.mp4"))
}
```

### ジョブベースの制御

長時間の生成では、ジョブを手動で管理できます：

```swift
// ジョブを開始
var job = try await client.startVideoGeneration(
    prompt: "タイムラプスの夕焼け",
    model: .sora2Pro
)

// ステータスをポーリング
while !job.status.isTerminal {
    try await Task.sleep(nanoseconds: 5_000_000_000)  // 5秒
    job = try await client.checkVideoStatus(job)
    print("進捗: \(job.progress ?? 0)%")
}

// 動画を取得
if job.status == .completed {
    let video = try await client.getGeneratedVideo(job)
}
```

### 利用可能なモデル

**OpenAI:**
- `.sora2` - Sora 2（標準、720p）
- `.sora2Pro` - Sora 2 Pro（高品質、1080p）

**Gemini:**
- `.veo31` - Veo 3.1（最新）
- `.veo31Fast` - Veo 3.1 Fast（高速）
- `.veo30` - Veo 3.0（安定版）
- `.veo20` - Veo 2.0

## エラーハンドリング

```swift
do {
    let image = try await client.generateImage(prompt: "...", model: .dalle3)
} catch let error as ImageGenerationError {
    switch error {
    case .contentPolicyViolation(let reason):
        print("コンテンツポリシー違反: \(reason ?? "")")
    case .unsupportedSize(let size, let model):
        print("\(model) はサイズ \(size) をサポートしていません")
    case .notSupportedByProvider(let provider):
        print("\(provider) は画像生成をサポートしていません")
    default:
        print("エラー: \(error)")
    }
} catch let error as MediaError {
    switch error {
    case .unsupportedFormat(let format):
        print("非対応フォーマット: \(format)")
    case .notSupportedByProvider(let media, let provider):
        print("\(provider) は \(media) をサポートしていません")
    default:
        print("メディアエラー: \(error)")
    }
}
```

## Topics

### メディア入力

- ``ImageContent``
- ``AudioContent``
- ``VideoContent``
- ``MediaSource``
- ``ImageMediaType``
- ``AudioMediaType``
- ``VideoMediaType``

### 生成結果

- ``GeneratedImage``
- ``GeneratedAudio``
- ``GeneratedVideo``
- ``VideoGenerationJob``

### 画像生成

- ``ImageGenerationCapable``
- ``OpenAIImageModel``
- ``GeminiImageModel``
- ``ImageSize``
- ``ImageQuality``

### 音声生成

- ``SpeechGenerationCapable``
- ``OpenAITTSModel``
- ``OpenAIVoice``
- ``AudioOutputFormat``

### 動画生成

- ``VideoGenerationCapable``
- ``OpenAIVideoModel``
- ``GeminiVideoModel``
- ``VideoAspectRatio``
- ``VideoResolution``
- ``VideoGenerationStatus``

### エラー

- ``MediaError``
- ``ImageGenerationError``
- ``SpeechGenerationError``
- ``VideoGenerationError``
