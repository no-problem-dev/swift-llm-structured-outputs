# プロバイダー

swift-llm-structured-outputs は、統一されたインターフェースで複数の LLM プロバイダーをサポートしています。

## 対応プロバイダー

| プロバイダー | クライアントクラス | モデル列挙型 |
|-------------|------------------|-------------|
| Anthropic | `AnthropicClient` | `ClaudeModel` |
| OpenAI | `OpenAIClient` | `GPTModel` |
| Google | `GeminiClient` | `GeminiModel` |

## Anthropic Claude

### セットアップ

```swift
let client = AnthropicClient(apiKey: "sk-ant-...")
```

### 利用可能なモデル

| エイリアス | モデル ID | 説明 |
|-----------|----------|------|
| `.sonnet` | claude-sonnet-4-20250514 | 速度と品質のバランスが最適 |
| `.opus` | claude-opus-4-20250514 | 最も高性能なモデル |
| `.haiku` | claude-haiku-3-20250307 | 最速のモデル |

### 固定バージョンの使用

```swift
// 特定のバージョンを使用
let result: MyType = try await client.generate(
    prompt: "...",
    model: .sonnet_20250514
)

// プレビューバージョンを使用
let result: MyType = try await client.generate(
    prompt: "...",
    model: .sonnet_preview(version: "2025-01-15")
)
```

### カスタムモデル

```swift
let result: MyType = try await client.generate(
    prompt: "...",
    model: .custom("claude-3-5-sonnet-20241022")
)
```

## OpenAI GPT

### セットアップ

```swift
let client = OpenAIClient(apiKey: "sk-...")
```

### 利用可能なモデル

| エイリアス | モデル ID | 説明 |
|-----------|----------|------|
| `.gpt4o` | gpt-4o | 最も高性能な GPT モデル |
| `.gpt4oMini` | gpt-4o-mini | より高速で経済的 |
| `.o1` | o1 | 推論モデル |
| `.o1Mini` | o1-mini | 高速な推論モデル |
| `.o3Mini` | o3-mini | 最新のコンパクト推論モデル |

### 固定バージョンの使用

```swift
let result: MyType = try await client.generate(
    prompt: "...",
    model: .gpt4o_20241120
)
```

### プレビューバージョン

```swift
let result: MyType = try await client.generate(
    prompt: "...",
    model: .gpt4o_preview(version: "2024-12-17")
)
```

## Google Gemini

### セットアップ

```swift
let client = GeminiClient(apiKey: "...")
```

### 利用可能なモデル

| エイリアス | モデル ID | 説明 |
|-----------|----------|------|
| `.pro25` | gemini-2.5-pro-preview-06-05 | 最も高性能 |
| `.flash25` | gemini-2.5-flash-preview-05-20 | 高速で効率的 |
| `.flash25Lite` | gemini-2.5-flash-lite-preview-06-17 | 軽量版 |
| `.flash20` | gemini-2.0-flash | 安定版フラッシュモデル |
| `.pro15` | gemini-1.5-pro | 前世代プロモデル |
| `.flash15` | gemini-1.5-flash | 前世代フラッシュモデル |

### プレビューバージョン

```swift
let result: MyType = try await client.generate(
    prompt: "...",
    model: .pro25_preview(version: "06-05")
)
```

## 共通パラメーター

すべてのクライアントで以下のパラメーターがサポートされています:

```swift
let result: MyType = try await client.generate(
    prompt: "プロンプトを入力",
    model: .sonnet,
    systemPrompt: "あなたは親切なアシスタントです",  // オプション
    temperature: 0.7,  // オプション: 0.0-1.0
    maxTokens: 1000    // オプション
)
```

### パラメーター説明

| パラメーター | 型 | 説明 |
|------------|-----|------|
| `prompt` | `String` | ユーザーの入力プロンプト |
| `model` | プロバイダー固有 | 使用するモデル |
| `systemPrompt` | `String?` | システム指示 |
| `temperature` | `Double?` | ランダム性 (0.0-1.0) |
| `maxTokens` | `Int?` | 最大応答トークン数 |

## 型安全性

このライブラリはコンパイル時に型安全性を保証します:

```swift
// ✅ コンパイル成功 - 正しいモデル型
let anthropic = AnthropicClient(apiKey: "...")
let result: MyType = try await anthropic.generate(
    prompt: "...",
    model: .sonnet  // ClaudeModel
)

// ❌ コンパイルエラー - 誤ったモデル型
let result: MyType = try await anthropic.generate(
    prompt: "...",
    model: .gpt4o  // GPTModel - 型の不一致！
)
```

## エラーハンドリング

```swift
do {
    let result: MyType = try await client.generate(
        prompt: "...",
        model: .sonnet
    )
} catch let error as LLMError {
    switch error {
    case .apiError(let message):
        print("APIエラー: \(message)")
    case .decodingError(let message):
        print("レスポンスのデコードに失敗: \(message)")
    case .invalidResponse:
        print("無効なレスポンス")
    case .networkError(let underlying):
        print("ネットワークエラー: \(underlying)")
    }
}
```

## 次のステップ

- [ツールコール](tool-calling.md) で LLM に外部関数を呼び出させる方法を学ぶ
- [会話](conversation.md) でマルチターンのやり取りについて学ぶ
- [API リファレンス](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/) で完全なドキュメントを確認
