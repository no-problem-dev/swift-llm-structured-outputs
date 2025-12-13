# swift-llm-structured-outputs

型安全な構造化出力を生成する Swift LLM クライアントライブラリ

🌐 **[English](README_EN.md)** | 日本語

[![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%2B%20%7C%20macOS%2014%2B-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 特徴

- **型安全な構造化出力** - Swift マクロによる JSON Schema 自動生成
- **マルチプロバイダー対応** - Claude (Anthropic)、GPT (OpenAI)、Gemini (Google) をサポート
- **会話継続** - `Conversation` クラスによる状態管理とマルチターン会話
- **Swift Concurrency** - async/await と Sendable に完全対応
- **ゼロ依存** - swift-syntax のみ使用（マクロ実装用）

## クイックスタート

### 1. 構造化出力の型を定義

```swift
import LLMStructuredOutputs

@Structured("ユーザー情報")
struct UserInfo {
    @StructuredField("名前")
    var name: String

    @StructuredField("年齢", .minimum(0), .maximum(150))
    var age: Int

    @StructuredField("メールアドレス", .format(.email))
    var email: String?
}
```

### 2. LLM から構造化データを取得

```swift
// Claude を使用
let client = AnthropicClient(apiKey: "sk-ant-...")
let user: UserInfo = try await client.generate(
    prompt: "山田太郎さんは35歳、メールはtaro@example.comです",
    model: .sonnet
)
print(user.name)  // "山田太郎"
print(user.age)   // 35
```

### 3. 会話を継続

```swift
var conversation = Conversation(
    client: client,
    model: .sonnet,
    systemPrompt: "あなたは親切なアシスタントです"
)

// 最初の質問
let cityInfo: CityInfo = try await conversation.send("日本の首都は？")
print(cityInfo.name)  // "東京"

// 会話を継続（コンテキストが維持される）
let population: PopulationInfo = try await conversation.send("その都市の人口は？")
print(population.count)  // 13960000
```

## インストール

### Swift Package Manager

`Package.swift` に依存関係を追加:

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-llm-structured-outputs.git", from: "1.0.0")
]
```

ターゲットに追加:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "LLMStructuredOutputs", package: "swift-llm-structured-outputs")
    ]
)
```

## 対応プロバイダー

| プロバイダー | クライアント | モデル例 |
|-------------|-------------|---------|
| Anthropic | `AnthropicClient` | `.sonnet`, `.opus`, `.haiku` |
| OpenAI | `OpenAIClient` | `.gpt4o`, `.gpt4oMini`, `.o1` |
| Google | `GeminiClient` | `.pro25`, `.flash25`, `.flash25Lite` |

### 使用例

```swift
// Anthropic Claude
let anthropic = AnthropicClient(apiKey: "sk-ant-...")
let result: MyType = try await anthropic.generate(
    prompt: "...",
    model: .sonnet
)

// OpenAI GPT
let openai = OpenAIClient(apiKey: "sk-...")
let result: MyType = try await openai.generate(
    prompt: "...",
    model: .gpt4o
)

// Google Gemini
let gemini = GeminiClient(apiKey: "...")
let result: MyType = try await gemini.generate(
    prompt: "...",
    model: .flash25
)
```

## マクロ一覧

### @Structured

構造体を構造化出力対応にします。

```swift
@Structured("商品情報")
struct Product {
    @StructuredField("商品名")
    var name: String

    @StructuredField("価格", .minimum(0))
    var price: Int
}
```

### @StructuredField

フィールドに説明と制約を付与します。

**利用可能な制約:**

| 制約 | 説明 | 例 |
|-----|------|-----|
| `.minimum(n)` | 最小値 | `.minimum(0)` |
| `.maximum(n)` | 最大値 | `.maximum(100)` |
| `.minLength(n)` | 最小文字数 | `.minLength(1)` |
| `.maxLength(n)` | 最大文字数 | `.maxLength(100)` |
| `.minItems(n)` | 最小要素数 | `.minItems(1)` |
| `.maxItems(n)` | 最大要素数 | `.maxItems(10)` |
| `.pattern(regex)` | 正規表現 | `.pattern("^[A-Z]+$")` |
| `.format(type)` | フォーマット | `.format(.email)` |
| `.enum([...])` | 列挙値 | `.enum(["a", "b"])` |

### @StructuredEnum

String 型の enum を構造化出力対応にします。

```swift
@StructuredEnum("優先度")
enum Priority: String {
    @StructuredCase("緊急タスク")
    case high

    @StructuredCase("通常タスク")
    case medium

    @StructuredCase("後回し可能")
    case low
}
```

## 会話継続

`Conversation` クラスを使用してマルチターン会話を管理できます。

```swift
var conversation = Conversation(
    client: AnthropicClient(apiKey: "..."),
    model: .sonnet,
    systemPrompt: "あなたは料理のエキスパートです"
)

// 連続した質問（コンテキストが維持される）
let recipe: Recipe = try await conversation.send("パスタの作り方を教えて")
let tips: CookingTips = try await conversation.send("初心者向けのコツは？")

// 使用状況の確認
print("ターン数: \(conversation.turnCount)")
print("総トークン: \(conversation.totalUsage.totalTokens)")

// 会話をリセット
conversation.clear()
```

## 要件

- Swift 6.0+
- iOS 17.0+ / macOS 14.0+

## ドキュメント

詳細なドキュメントは以下を参照してください:

- [API リファレンス](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/)
- [ガイド](documentation/)
  - [Getting Started](documentation/getting-started.md)
  - [Providers](documentation/providers.md)
  - [Conversation](documentation/conversation.md)

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照してください。

## 作者

NOPROBLEM
