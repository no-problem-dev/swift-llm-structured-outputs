# 会話

`Conversation` クラスは、型安全な構造化出力を維持しながら、LLM とのマルチターン会話を管理する便利な方法を提供します。

## 基本的な使い方

### 会話の作成

```swift
import LLMStructuredOutputs

let client = AnthropicClient(apiKey: "sk-ant-...")

var conversation = Conversation(
    client: client,
    model: .sonnet,
    systemPrompt: "あなたは親切な料理アシスタントです"
)
```

### メッセージの送信

`send` メソッドを使用してメッセージを送信し、構造化されたレスポンスを受け取ります:

```swift
@Structured("レシピ情報")
struct Recipe {
    @StructuredField("レシピ名")
    var name: String

    @StructuredField("材料リスト")
    var ingredients: [String]

    @StructuredField("調理手順")
    var instructions: [String]
}

// 最初のメッセージ
let recipe: Recipe = try await conversation.send("カルボナーラの作り方を教えて")
print(recipe.name)  // "カルボナーラ"

// フォローアップの質問（コンテキストが維持される）
@Structured("料理のコツ")
struct CookingTips {
    @StructuredField("コツのリスト")
    var tips: [String]
}

let tips: CookingTips = try await conversation.send("初心者向けのコツは？")
```

## 会話の状態

### メッセージの追跡

```swift
// 会話内のすべてのメッセージを取得
let messages = conversation.messages

// ターン数（ユーザー・アシスタントのペア）を取得
let turns = conversation.turnCount
```

### トークン使用量

```swift
// すべてのターンの合計トークン使用量を追跡
let totalUsage = conversation.totalUsage
print("入力トークン: \(totalUsage.inputTokens)")
print("出力トークン: \(totalUsage.outputTokens)")
print("合計トークン: \(totalUsage.totalTokens)")
```

### 会話のクリア

```swift
// 会話をリセットして最初からやり直す
conversation.clear()
```

## 既存のメッセージで開始

既存のメッセージ履歴で会話を初期化できます:

```swift
let existingMessages: [LLMMessage] = [
    .user("フランスの首都は？"),
    .assistant("{\"name\": \"パリ\", \"country\": \"フランス\"}")
]

var conversation = Conversation(
    client: client,
    model: .sonnet,
    messages: existingMessages
)
```

## 異なる出力型の使用

会話内の各メッセージは異なる構造化型を返すことができます:

```swift
@Structured
struct CityInfo {
    var name: String
    var country: String
}

@Structured
struct PopulationInfo {
    var population: Int
    var year: Int
}

@Structured
struct WeatherInfo {
    var temperature: Double
    var condition: String
}

// 同じ会話で、異なるレスポンス型
let city: CityInfo = try await conversation.send("日本の首都は？")
let population: PopulationInfo = try await conversation.send("その都市の人口は？")
let weather: WeatherInfo = try await conversation.send("今の天気は？")
```

## 低レベル Chat API

より細かい制御が必要な場合は、クライアントの `chat` メソッドを直接使用できます:

```swift
var messages: [LLMMessage] = []

// 最初のターン
messages.append(.user("2 + 2 は？"))
let response1: ChatResponse<MathAnswer> = try await client.chat(
    messages: messages,
    model: .sonnet
)
messages.append(response1.assistantMessage)

// 2番目のターン
messages.append(.user("それを3倍して"))
let response2: ChatResponse<MathAnswer> = try await client.chat(
    messages: messages,
    model: .sonnet
)
```

### ChatResponse のプロパティ

```swift
let response: ChatResponse<MyType> = try await client.chat(...)

// 構造化された結果
let result = response.result

// アシスタントの生メッセージ（履歴に追加用）
let assistantMessage = response.assistantMessage

// このターンのトークン使用量
let usage = response.usage

// レスポンスが終了した理由
let stopReason = response.stopReason

// 使用されたモデル
let model = response.model

// パース前の生テキスト
let rawText = response.rawText
```

## 設定オプション

### Temperature

レスポンスのランダム性を制御:

```swift
var conversation = Conversation(
    client: client,
    model: .sonnet,
    temperature: 0.7  // 0.0 = 確定的、1.0 = 創造的
)
```

### 最大トークン

レスポンスの長さを制限:

```swift
var conversation = Conversation(
    client: client,
    model: .sonnet,
    maxTokens: 500
)
```

## 型安全性

`Conversation` クラスはクライアント型に対してジェネリックであり、モデルの互換性を保証します:

```swift
// Anthropic クライアントを使用 - ClaudeModel のみ許可
var anthropicConv = Conversation(
    client: AnthropicClient(apiKey: "..."),
    model: .sonnet  // ✅ ClaudeModel
)

// OpenAI クライアントを使用 - GPTModel のみ許可
var openaiConv = Conversation(
    client: OpenAIClient(apiKey: "..."),
    model: .gpt4o  // ✅ GPTModel
)

// Gemini クライアントを使用 - GeminiModel のみ許可
var geminiConv = Conversation(
    client: GeminiClient(apiKey: "..."),
    model: .flash25  // ✅ GeminiModel
)
```

## 並行処理

`Conversation` は `Sendable` であり、非同期コンテキスト間で安全に使用できます:

```swift
let conversation = Conversation(
    client: client,
    model: .sonnet
)

// 並行コンテキストで安全に使用
Task {
    var conv = conversation
    let result: MyType = try await conv.send("こんにちは")
}
```

## ベストプラクティス

1. **関連する質問には会話を再利用** - コンテキストを維持
2. **新しいトピックでは会話をクリア** - 不要なコンテキストを削除
3. **トークン使用量を監視** - コスト管理のため
4. **タスクの複雑さに応じたモデルを使用** - 適切なモデル選択
5. **エラーを適切に処理** - do-catch ブロックで

## 次のステップ

- [プロバイダー](providers.md) ガイドでプロバイダー固有の詳細を確認
- [はじめに](getting-started.md) で基本的なセットアップを確認
- [API リファレンス](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/) で完全なドキュメントを閲覧
