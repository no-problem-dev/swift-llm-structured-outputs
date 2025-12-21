# マルチメディアAPI仕様書

このドキュメントは、各LLMプロバイダー（Anthropic、OpenAI、Google Gemini）のマルチメディア入出力APIの詳細仕様をまとめたものです。
Swift実装時の参照用として、セッションを超えて保持するために作成されています。

---

## 目次

1. [総合比較表](#総合比較表)
2. [Anthropic Claude API](#1-anthropic-claude-api)
3. [OpenAI API](#2-openai-api)
4. [Google Gemini API](#3-google-gemini-api)
5. [Swift実装への影響](#4-swift実装への影響)

---

## 総合比較表

### 機能対応マトリクス

| 機能 | Anthropic Claude | OpenAI | Google Gemini |
|------|------------------|--------|---------------|
| **入力** | | | |
| 画像入力 | ✅ | ✅ | ✅ |
| 音声入力 | ❌ API未対応 | ✅ | ✅ |
| 動画入力 | ❌ | ⚠️ フレーム分解 | ✅ |
| **出力** | | | |
| テキスト出力 | ✅ | ✅ | ✅ |
| 画像生成 | ❌ | ✅ | ✅ |
| 音声生成 | ❌ | ✅ | ✅ |
| 動画生成 | ❌ | ✅ | ✅ |

### エンドポイント構成

| プロバイダー | チャット | 画像生成 | 音声生成 | 動画生成 |
|-------------|---------|---------|---------|---------|
| Anthropic | `/v1/messages` | N/A | N/A | N/A |
| OpenAI | `/v1/chat/completions` | `/v1/images/generations` | `/v1/audio/speech` | `/v1/videos/generations` |
| Gemini | `/:generateContent` | `/:generateContent` (同一) | `/:generateContent` (TTS) | `/veo:generate` |

---

## 1. Anthropic Claude API

### 1.1 画像入力

#### 対応モデル
- Claude 3 Opus, Sonnet, Haiku
- Claude 3.5 Sonnet, Haiku
- Claude 4 Opus, Sonnet, Haiku

#### サポート形式
| 形式 | MIME Type | 備考 |
|-----|-----------|------|
| JPEG | `image/jpeg` | ✅ |
| PNG | `image/png` | ✅ |
| GIF | `image/gif` | ✅ アニメーションは最初のフレームのみ |
| WebP | `image/webp` | ✅ |

#### サイズ制限
- 最大ファイルサイズ: **20MB/画像**
- 推奨サイズ: 1568px以下（長辺）
- 最大画像数: API 100枚/リクエスト

#### 入力方式

**Base64形式:**
```json
{
  "role": "user",
  "content": [
    {
      "type": "image",
      "source": {
        "type": "base64",
        "media_type": "image/jpeg",
        "data": "<base64_encoded_string>"
      }
    },
    {
      "type": "text",
      "text": "この画像を説明してください"
    }
  ]
}
```

**URL形式:**
```json
{
  "role": "user",
  "content": [
    {
      "type": "image",
      "source": {
        "type": "url",
        "url": "https://example.com/image.jpg"
      }
    },
    {
      "type": "text",
      "text": "この画像を説明してください"
    }
  ]
}
```

#### トークン計算
画像トークン = (width × height) / 750

### 1.2 音声入力
**❌ API未対応**

Claude Voiceは消費者向けアプリのみ。APIでの直接音声入力は未サポート。
サードパーティ統合（ElevenLabs、Hume AI）が必要。

### 1.3 動画入力
**❌ 未サポート**

### 1.4 出力機能
**❌ 画像/音声/動画生成は未サポート**

Anthropicは安全性重視の方針により、生成機能を提供していない。

---

## 2. OpenAI API

### 2.1 画像入力

#### 対応モデル
- GPT-4o, GPT-4o-mini
- GPT-4 Turbo with Vision
- o1, o3, o4 シリーズ
- GPT-5 シリーズ

#### サポート形式
| 形式 | MIME Type |
|-----|-----------|
| JPEG | `image/jpeg` |
| PNG | `image/png` |
| GIF | `image/gif` |
| WebP | `image/webp` |

#### サイズ制限
- 推奨最大サイズ: **20MB**
- detail パラメータ: `low`, `high`, `auto`

#### 入力方式

**Base64形式 (Data URL):**
```json
{
  "role": "user",
  "content": [
    {
      "type": "text",
      "text": "この画像を説明してください"
    },
    {
      "type": "image_url",
      "image_url": {
        "url": "data:image/jpeg;base64,<base64_encoded_string>",
        "detail": "high"
      }
    }
  ]
}
```

**URL形式:**
```json
{
  "role": "user",
  "content": [
    {
      "type": "image_url",
      "image_url": {
        "url": "https://example.com/image.jpg",
        "detail": "auto"
      }
    }
  ]
}
```

### 2.2 音声入力

#### 対応モデル
- `gpt-4o-audio-preview`
- `gpt-4o-mini-audio-preview`

#### サポート形式
| 形式 | 備考 |
|-----|------|
| WAV | ✅ 推奨（低レイテンシ） |
| MP3 | ✅ |

#### サイズ制限
- 最大ファイルサイズ: **20MB**

#### 入力方式
```json
{
  "role": "user",
  "content": [
    {
      "type": "text",
      "text": "この音声を書き起こしてください"
    },
    {
      "type": "input_audio",
      "input_audio": {
        "data": "<base64_encoded_audio>",
        "format": "wav"
      }
    }
  ]
}
```

### 2.3 動画入力
**⚠️ 間接サポート**

動画をフレームに分解し、画像として送信。
推奨: 2-4 fps でキーフレームを抽出、512-720px にリサイズ。

### 2.4 画像生成

#### 対応モデル
| モデル | ステータス | 特徴 |
|-------|-----------|------|
| `gpt-image-1.5` | ✅ 推奨 | 最新、常にBase64返却 |
| `gpt-image-1` | ✅ | - |
| `gpt-image-1-mini` | ✅ | 軽量版 |
| `dall-e-3` | ⚠️ 2026/05/12 廃止予定 | - |
| `dall-e-2` | ⚠️ 2026/05/12 廃止予定 | - |

#### エンドポイント
```
POST https://api.openai.com/v1/images/generations
```

#### リクエスト
```json
{
  "model": "gpt-image-1",
  "prompt": "A white cat sitting on a windowsill",
  "n": 1,
  "size": "1024x1024",
  "quality": "hd",
  "response_format": "b64_json"
}
```

#### レスポンス
```json
{
  "created": 1701994117,
  "data": [
    {
      "b64_json": "<base64_encoded_image>",
      "revised_prompt": "..."
    }
  ]
}
```

#### パラメータ
| パラメータ | 値 | 備考 |
|-----------|-----|------|
| size | `1024x1024`, `1792x1024`, `1024x1792` | DALL-E 3 |
| quality | `standard`, `hd` | - |
| style | `natural`, `vivid` | DALL-E 3のみ |
| response_format | `url`, `b64_json` | GPT-Imageは常にb64_json |

### 2.5 音声生成

#### 対応モデル
| モデル | 特徴 |
|-------|------|
| `gpt-4o-mini-tts` | 音声指示対応、表現力高 |
| `tts-1` | 標準品質 |
| `tts-1-hd` | 高品質 |

#### A) 専用TTSエンドポイント
```
POST https://api.openai.com/v1/audio/speech
```

**リクエスト:**
```json
{
  "model": "gpt-4o-mini-tts",
  "input": "こんにちは、今日はいい天気ですね。",
  "voice": "alloy",
  "response_format": "mp3",
  "speed": 1.0
}
```

**レスポンス:** 音声バイナリストリーム

#### B) Chat Completions API での音声出力

**リクエスト:**
```json
{
  "model": "gpt-4o-audio-preview",
  "modalities": ["text", "audio"],
  "audio": {
    "voice": "alloy",
    "format": "wav"
  },
  "messages": [
    {"role": "user", "content": "俳句を詠んでください"}
  ]
}
```

**レスポンス:**
```json
{
  "choices": [{
    "message": {
      "content": null,
      "audio": {
        "id": "audio_abc123",
        "data": "<base64_encoded_wav>",
        "expires_at": 1729234747,
        "transcript": "古池や 蛙飛び込む 水の音"
      }
    }
  }]
}
```

#### 音声オプション
- **Voices:** alloy, ash, ballad, coral, echo, fable, onyx, nova, sage, shimmer, verse, marin, cedar
- **Formats:** mp3, opus, aac, flac, wav, pcm
- **Speed:** 0.25 - 4.0

### 2.6 動画生成

#### 対応モデル
| モデル | 特徴 |
|-------|------|
| `sora-2` | 高速、実験向け |
| `sora-2-pro` | 高品質、本番向け |

#### エンドポイント
```
POST https://api.openai.com/v1/videos/generations
GET  https://api.openai.com/v1/videos/{id}
```

#### リクエスト
```json
{
  "model": "sora-2",
  "prompt": "A cat walking in a garden",
  "size": "1280x720",
  "seconds": 8
}
```

#### レスポンス（生成開始）
```json
{
  "id": "video_abc123",
  "object": "video",
  "status": "queued",
  "model": "sora-2",
  "progress": 0,
  "seconds": "8",
  "size": "1280x720"
}
```

#### レスポンス（完了後）
```json
{
  "id": "video_abc123",
  "status": "completed",
  "progress": 100,
  "url": "https://..."
}
```

#### パラメータ
| パラメータ | 値 |
|-----------|-----|
| size | `720x1280`, `1280x720`, `1024x1792`, `1792x1024` |
| seconds | 4, 8, 12 |

---

## 3. Google Gemini API

### 3.1 画像入力

#### 対応モデル
- Gemini 1.5 Pro, Flash
- Gemini 2.0 Flash
- Gemini 2.5 Pro, Flash, Flash-Lite
- Gemini 3 Flash, Pro

#### サポート形式
| 形式 | MIME Type |
|-----|-----------|
| JPEG | `image/jpeg` |
| PNG | `image/png` |
| WebP | `image/webp` |
| HEIC | `image/heic` |
| HEIF | `image/heif` |

#### サイズ制限
- インライン: **20MB/リクエスト**（テキスト含む）
- File API: 無制限（実質的に）
- 最大画像数: 3,600枚

#### 入力方式

**インライン (Base64):**
```json
{
  "contents": [{
    "parts": [
      {
        "inline_data": {
          "mimeType": "image/jpeg",
          "data": "<base64_encoded_string>"
        }
      },
      {
        "text": "この画像を説明してください"
      }
    ]
  }]
}
```

**File API参照:**
```json
{
  "contents": [{
    "parts": [
      {
        "file_data": {
          "mime_type": "image/jpeg",
          "file_uri": "https://generativelanguage.googleapis.com/v1beta/files/abc123"
        }
      }
    ]
  }]
}
```

### 3.2 音声入力

#### 対応モデル
- Gemini 1.5 Pro, Flash
- Gemini 2.0 Flash
- Gemini 2.5 Pro, Flash

#### サポート形式
| 形式 | MIME Type |
|-----|-----------|
| WAV | `audio/wav` |
| MP3 | `audio/mp3` |
| AIFF | `audio/aiff` |
| AAC | `audio/aac` |
| OGG | `audio/ogg` |
| FLAC | `audio/flac` |

#### サイズ制限
- インライン: **20MB/リクエスト**
- File API: 推奨
- 最大音声長: **9.5時間**
- トークン換算: 1秒 = 32トークン

#### 入力方式
```json
{
  "contents": [{
    "parts": [
      {
        "inline_data": {
          "mimeType": "audio/mp3",
          "data": "<base64_encoded_audio>"
        }
      },
      {
        "text": "この音声を書き起こしてください"
      }
    ]
  }]
}
```

### 3.3 動画入力

#### 対応モデル
- Gemini 2.0 Flash
- Gemini 2.5 Pro, Flash

#### サポート形式
| 形式 | MIME Type |
|-----|-----------|
| MP4 | `video/mp4` |
| AVI | `video/avi` |
| MOV | `video/quicktime` |
| MKV | `video/x-matroska` |
| WebM | `video/webm` |
| FLV | `video/x-flv` |
| MPEG | `video/mpeg` |

#### サイズ制限
- インライン: **20MB/リクエスト**
- File API: **2GB**

#### 入力方式
```json
{
  "contents": [{
    "parts": [
      {
        "inline_data": {
          "mimeType": "video/mp4",
          "data": "<base64_encoded_video>"
        }
      },
      {
        "text": "この動画の内容を説明してください"
      }
    ]
  }]
}
```

### 3.4 画像生成

#### 対応モデル
| モデル | 解像度 | 特徴 |
|-------|--------|------|
| `gemini-2.5-flash-image` | 1024px | 一般用途 |
| `gemini-3-pro-image-preview` | 最大4096px | プロ品質、テキスト描画対応 |
| `imagen-4.0-generate-001` | - | 別API（Imagen） |

#### エンドポイント（Gemini Image）
```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent
```

#### リクエスト
```json
{
  "contents": [{
    "parts": [{"text": "猫が窓辺で座っている写真"}]
  }],
  "generationConfig": {
    "responseModalities": ["TEXT", "IMAGE"]
  }
}
```

#### レスポンス
```json
{
  "candidates": [{
    "content": {
      "parts": [
        {
          "text": "生成された画像です。"
        },
        {
          "inlineData": {
            "mimeType": "image/png",
            "data": "<base64_encoded_image>"
          }
        }
      ]
    }
  }]
}
```

### 3.5 音声生成 (TTS)

#### 対応モデル
| モデル | 特徴 |
|-------|------|
| `gemini-2.5-flash-preview-tts` | 標準TTS |
| `gemini-2.5-pro-preview-tts` | 高品質TTS |

#### エンドポイント
```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent
```

#### リクエスト
```json
{
  "contents": [{
    "parts": [{"text": "こんにちは、今日はいい天気ですね。"}]
  }],
  "generationConfig": {
    "responseModalities": ["AUDIO"],
    "speechConfig": {
      "voiceConfig": {
        "prebuiltVoiceConfig": {
          "voiceName": "Zephyr"
        }
      }
    }
  }
}
```

#### レスポンス
```json
{
  "candidates": [{
    "content": {
      "parts": [{
        "inlineData": {
          "mimeType": "audio/L16;codec=pcm;rate=24000",
          "data": "<base64_encoded_pcm>"
        }
      }]
    }
  }]
}
```

#### 音声出力形式
- **フォーマット:** PCM (Linear16)
- **サンプルレート:** 24,000 Hz
- **チャンネル:** モノラル
- **ビット深度:** 16-bit

**注意:** PCMデータはそのままでは再生不可。WAVヘッダー追加が必要。

#### 音声オプション
30種類の音声: Zephyr (Bright), Puck (Upbeat), Kore (Firm), Enceladus (Breathy), Algieba (Smooth), Sulafat (Warm), など

### 3.6 動画生成

#### 対応モデル
| モデル | 解像度 | 長さ | 特徴 |
|-------|--------|------|------|
| `veo-2` | 720p | 最大8秒 | GA |
| `veo-3.1` | - | - | プレビュー |
| `veo-3.1-fast` | - | - | 高速版 |

#### エンドポイント
```
POST https://generativelanguage.googleapis.com/v1beta/models/veo-2:generate
```

#### リクエスト
```json
{
  "prompt": "A cat walking through a garden",
  "config": {
    "duration": 8,
    "resolution": "720p"
  }
}
```

#### レスポンス（非同期）
```json
{
  "name": "operations/abc123",
  "done": false
}
```

#### レスポンス（完了時）
```json
{
  "done": true,
  "response": {
    "generateVideoResponse": {
      "generatedSamples": [{
        "video": {
          "uri": "https://storage.googleapis.com/..."
        }
      }]
    }
  }
}
```

#### 注意事項
- 生成動画は**2日間**で削除される
- SynthIDによる透かし入り
- 24fps、720p

---

## 4. Swift実装への影響

### 4.1 既存の型構造

現在の `LLMMessage.MessageContent`:
```swift
public enum MessageContent: Sendable, Equatable, Codable {
    case text(String)
    case toolUse(id: String, name: String, input: Data)
    case toolResult(toolCallId: String, name: String, content: String, isError: Bool)
}
```

### 4.2 拡張案

```swift
public enum MessageContent: Sendable, Equatable, Codable {
    // 既存
    case text(String)
    case toolUse(id: String, name: String, input: Data)
    case toolResult(toolCallId: String, name: String, content: String, isError: Bool)

    // 新規: メディア入力
    case image(ImageContent)
    case audio(AudioContent)
    case video(VideoContent)
}

// MARK: - Image Content

public struct ImageContent: Sendable, Equatable, Codable {
    public let source: MediaSource
    public let mediaType: ImageMediaType
    public let detail: ImageDetail?  // OpenAI専用

    public enum ImageMediaType: String, Sendable, Codable {
        case jpeg = "image/jpeg"
        case png = "image/png"
        case gif = "image/gif"
        case webp = "image/webp"
        case heic = "image/heic"  // Geminiのみ
        case heif = "image/heif"  // Geminiのみ
    }

    public enum ImageDetail: String, Sendable, Codable {
        case low, high, auto
    }
}

// MARK: - Audio Content

public struct AudioContent: Sendable, Equatable, Codable {
    public let source: MediaSource
    public let mediaType: AudioMediaType

    public enum AudioMediaType: String, Sendable, Codable {
        case wav = "audio/wav"
        case mp3 = "audio/mp3"
        case aac = "audio/aac"
        case flac = "audio/flac"
        case ogg = "audio/ogg"
        case aiff = "audio/aiff"  // Geminiのみ
    }
}

// MARK: - Video Content

public struct VideoContent: Sendable, Equatable, Codable {
    public let source: MediaSource
    public let mediaType: VideoMediaType

    public enum VideoMediaType: String, Sendable, Codable {
        case mp4 = "video/mp4"
        case avi = "video/avi"
        case mov = "video/quicktime"
        case mkv = "video/x-matroska"
        case webm = "video/webm"
        case flv = "video/x-flv"
        case mpeg = "video/mpeg"
    }
}

// MARK: - Media Source

public enum MediaSource: Sendable, Equatable, Codable {
    case base64(Data)
    case url(URL)
    case fileReference(String)  // Gemini File API / OpenAI Files API
}
```

### 4.3 LLMResponse.ContentBlock の拡張

```swift
public enum ContentBlock: Sendable {
    // 既存
    case text(String)
    case toolUse(id: String, name: String, input: Data)

    // 新規: メディア出力
    case image(GeneratedImage)
    case audio(GeneratedAudio)
    case videoJob(VideoGenerationJob)
}

public struct GeneratedImage: Sendable {
    public let data: Data
    public let mediaType: ImageContent.ImageMediaType
    public let revisedPrompt: String?  // OpenAI専用
}

public struct GeneratedAudio: Sendable {
    public let data: Data
    public let format: AudioOutputFormat
    public let transcript: String?
    public let expiresAt: Date?  // OpenAI専用

    public enum AudioOutputFormat: String, Sendable {
        case wav, mp3, opus, aac, flac, pcm
    }
}

public struct VideoGenerationJob: Sendable {
    public let id: String
    public let status: VideoStatus
    public let progress: Int?
    public let downloadURL: URL?

    public enum VideoStatus: String, Sendable {
        case queued, inProgress, completed, failed
    }
}
```

### 4.4 プロバイダー別の変換ロジック

各プロバイダーの `convertToXxxMessage` メソッドで、新しいコンテンツタイプを適切な形式に変換する必要がある。

#### AnthropicProvider
```swift
case .image(let imageContent):
    let source: [String: Any]
    switch imageContent.source {
    case .base64(let data):
        source = [
            "type": "base64",
            "media_type": imageContent.mediaType.rawValue,
            "data": data.base64EncodedString()
        ]
    case .url(let url):
        source = ["type": "url", "url": url.absoluteString]
    case .fileReference:
        fatalError("Anthropic does not support file references")
    }
    contentBlocks.append(.image(source: source))
```

#### OpenAIProvider
```swift
case .image(let imageContent):
    let urlString: String
    switch imageContent.source {
    case .base64(let data):
        urlString = "data:\(imageContent.mediaType.rawValue);base64,\(data.base64EncodedString())"
    case .url(let url):
        urlString = url.absoluteString
    case .fileReference(let fileId):
        // Files API形式
        urlString = fileId
    }
    // detail パラメータを含める
    contentBlocks.append(.imageURL(url: urlString, detail: imageContent.detail?.rawValue))

case .audio(let audioContent):
    guard case .base64(let data) = audioContent.source else {
        fatalError("OpenAI audio requires base64 data")
    }
    contentBlocks.append(.inputAudio(
        data: data.base64EncodedString(),
        format: audioContent.mediaType == .wav ? "wav" : "mp3"
    ))
```

#### GeminiProvider
```swift
case .image(let imageContent), .audio(let audioContent), .video(let videoContent):
    switch source {
    case .base64(let data):
        parts.append(GeminiPart(inlineData: GeminiInlineData(
            mimeType: mediaType.rawValue,
            data: data.base64EncodedString()
        )))
    case .url(let url):
        // URL経由は File API にアップロード後に参照
        parts.append(GeminiPart(fileData: GeminiFileData(
            mimeType: mediaType.rawValue,
            fileUri: url.absoluteString
        )))
    case .fileReference(let uri):
        parts.append(GeminiPart(fileData: GeminiFileData(
            mimeType: mediaType.rawValue,
            fileUri: uri
        )))
    }
```

### 4.5 機能可用性チェック

```swift
extension LLMModel {
    /// 画像入力のサポート
    public var supportsImageInput: Bool {
        switch self {
        case .claude, .gpt, .gemini:
            return true
        case .custom:
            return false  // 不明
        }
    }

    /// 音声入力のサポート
    public var supportsAudioInput: Bool {
        switch self {
        case .claude:
            return false  // API未対応
        case .gpt(let model):
            switch model {
            case .gpt4o, .gpt4oMini, .gpt4o_version, .gpt4oMini_version:
                return true  // audio-preview モデルのみ実際には対応
            default:
                return false
            }
        case .gemini:
            return true
        case .custom:
            return false
        }
    }

    /// 動画入力のサポート
    public var supportsVideoInput: Bool {
        switch self {
        case .gemini:
            return true
        default:
            return false
        }
    }

    /// 画像生成のサポート
    public var supportsImageGeneration: Bool {
        switch self {
        case .gpt, .gemini:
            return true  // 別モデル/エンドポイントが必要
        default:
            return false
        }
    }

    /// 音声生成のサポート
    public var supportsAudioGeneration: Bool {
        switch self {
        case .gpt, .gemini:
            return true  // 別モデル/エンドポイントが必要
        default:
            return false
        }
    }

    /// 動画生成のサポート
    public var supportsVideoGeneration: Bool {
        switch self {
        case .gpt, .gemini:
            return true  // Sora / Veo (別エンドポイント)
        default:
            return false
        }
    }
}
```

### 4.6 エラーハンドリング

```swift
public enum LLMError: Error, Sendable {
    // 既存...

    // 新規: メディア関連エラー
    case mediaNotSupported(mediaType: String, provider: String)
    case mediaSizeExceeded(size: Int, maxSize: Int)
    case invalidMediaFormat(format: String, supported: [String])
    case mediaUploadFailed(Error)
    case videoGenerationFailed(jobId: String, reason: String)
    case videoGenerationTimeout(jobId: String)
}
```

---

## 参考リンク

### Anthropic
- [Vision Documentation](https://docs.anthropic.com/en/docs/build-with-claude/vision)

### OpenAI
- [Images and Vision](https://platform.openai.com/docs/guides/images-vision)
- [Audio and Speech](https://platform.openai.com/docs/guides/audio)
- [Video Generation](https://platform.openai.com/docs/guides/video-generation)

### Google Gemini
- [Image Understanding](https://ai.google.dev/gemini-api/docs/image-understanding)
- [Audio Understanding](https://ai.google.dev/gemini-api/docs/audio)
- [Video Understanding](https://ai.google.dev/gemini-api/docs/video-understanding)
- [Image Generation](https://ai.google.dev/gemini-api/docs/image-generation)
- [Speech Generation (TTS)](https://ai.google.dev/gemini-api/docs/speech-generation)
- [Video Generation (Veo)](https://ai.google.dev/gemini-api/docs/video)

---

## 更新履歴

| 日付 | 内容 |
|------|------|
| 2025-12-20 | 初版作成 |
