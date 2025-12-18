# プロバイダー

対応している LLM プロバイダーとモデルについて学びます。

## 概要

LLMStructuredOutputs は、3 つの主要な LLM プロバイダーをサポートしており、それぞれに専用のクライアントクラスとモデルオプションがあります。

## Anthropic Claude

### クライアントのセットアップ

```swift
let client = AnthropicClient(apiKey: "sk-ant-...")
```

### モデルオプション

`ClaudeModel` を使用してモデルを選択:

| エイリアス | 説明 |
|-----------|------|
| `.sonnet` | Claude Sonnet - バランスの取れた性能 |
| `.opus` | Claude Opus - 最高性能 |
| `.haiku` | Claude Haiku - 最速 |

```swift
let result: MyType = try await client.generate(
    prompt: "...",
    model: .sonnet
)
```

### 固定バージョン

本番環境の安定性のために、固定バージョンを使用:

```swift
model: .sonnet_20250514
model: .opus_20250514
model: .haiku_20250307
```

## OpenAI GPT

### クライアントのセットアップ

```swift
let client = OpenAIClient(apiKey: "sk-...")
```

### モデルオプション

`GPTModel` を使用してモデルを選択:

| エイリアス | 説明 |
|-----------|------|
| `.gpt4o` | GPT-4o - 最も高性能 |
| `.gpt4oMini` | GPT-4o Mini - 高速 |
| `.o1` | o1 - 推論モデル |
| `.o1Mini` | o1 Mini - コンパクト推論 |
| `.o3Mini` | o3 Mini - 最新の推論 |

```swift
let result: MyType = try await client.generate(
    prompt: "...",
    model: .gpt4o
)
```

## Google Gemini

### クライアントのセットアップ

```swift
let client = GeminiClient(apiKey: "...")
```

### モデルオプション

`GeminiModel` を使用してモデルを選択:

| エイリアス | 説明 |
|-----------|------|
| `.flash3` | Gemini 3 Flash - 最高性能・高速 |
| `.pro25` | Gemini 2.5 Pro - 高性能 |
| `.flash25` | Gemini 2.5 Flash - 高速 |
| `.flash25Lite` | Gemini 2.5 Flash Lite - 軽量 |
| `.flash20` | Gemini 2.0 Flash - 安定版 |
| `.pro15` | Gemini 1.5 Pro - 前世代 |
| `.flash15` | Gemini 1.5 Flash - 前世代 |

```swift
let result: MyType = try await client.generate(
    prompt: "...",
    model: .flash3
)
```

## 共通パラメーター

すべてのプロバイダーで以下のパラメーターをサポート:

```swift
let result: MyType = try await client.generate(
    prompt: "プロンプト",
    model: .sonnet,
    systemPrompt: "あなたは親切なアシスタントです",
    temperature: 0.7,
    maxTokens: 1000
)
```

| パラメーター | 型 | 説明 |
|------------|-----|------|
| `prompt` | `String` | ユーザー入力 |
| `model` | プロバイダー固有 | モデル選択 |
| `systemPrompt` | `String?` | システム指示 |
| `temperature` | `Double?` | ランダム性 (0.0-1.0) |
| `maxTokens` | `Int?` | 最大レスポンストークン |

## 型安全性

ライブラリはコンパイル時に型安全性を強制:

```swift
// ✅ 正しい - ClaudeModel と AnthropicClient
let anthropic = AnthropicClient(apiKey: "...")
try await anthropic.generate(prompt: "...", model: .sonnet)

// ❌ コンパイルエラー - GPTModel と AnthropicClient
try await anthropic.generate(prompt: "...", model: .gpt4o)
```

## カスタムモデル

すべてのプロバイダーでカスタムモデル ID をサポート:

```swift
// Anthropic
model: .custom("claude-3-opus-20240229")

// OpenAI
model: .custom("gpt-4-1106-preview")

// Gemini
model: .custom("gemini-1.0-pro")
```
