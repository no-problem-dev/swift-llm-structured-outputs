# 会話

構造化出力を使用したマルチターン会話の管理方法を学びます。

## 概要

``Conversation`` クラスは、型安全な構造化出力を受け取りながら、複数の LLM のやり取りでコンテキストを維持する便利な方法を提供します。

## 会話の作成

```swift
var conversation = Conversation(
    client: AnthropicClient(apiKey: "..."),
    model: .sonnet,
    systemPrompt: "あなたは親切なアシスタントです"
)
```

## メッセージの送信

`send` メソッドを使用してメッセージを交換:

```swift
@Structured
struct CityInfo {
    var name: String
    var country: String
}

@Structured
struct PopulationInfo {
    var population: Int
}

// 最初のターン
let city: CityInfo = try await conversation.send("日本の首都は？")
print(city.name)  // "東京"

// 2番目のターン - コンテキストが維持される
let pop: PopulationInfo = try await conversation.send("その都市の人口は？")
print(pop.population)  // 13960000
```

## 状態の追跡

### メッセージ履歴

```swift
// すべてのメッセージにアクセス
let messages = conversation.messages
print("合計メッセージ数: \(messages.count)")

// 完了したターンの数
let turns = conversation.turnCount
```

### トークン使用量

```swift
let usage = conversation.totalUsage
print("入力トークン: \(usage.inputTokens)")
print("出力トークン: \(usage.outputTokens)")
print("合計: \(usage.totalTokens)")
```

## 会話のリセット

会話をクリアして最初からやり直す:

```swift
conversation.clear()
```

## 低レベル API

より細かい制御が必要な場合は、``ChatResponse`` を直接使用:

```swift
var messages: [LLMMessage] = []
messages.append(.user("こんにちは"))

let response: ChatResponse<Greeting> = try await client.chat(
    messages: messages,
    model: .sonnet
)

// アシスタントのレスポンスを履歴に追加
messages.append(response.assistantMessage)

// 会話を続ける
messages.append(.user("元気ですか？"))
```

### ChatResponse のプロパティ

| プロパティ | 型 | 説明 |
|----------|-----|------|
| `result` | `T` | 構造化出力 |
| `assistantMessage` | `LLMMessage` | 履歴用 |
| `usage` | `TokenUsage` | トークン数 |
| `stopReason` | `StopReason?` | レスポンス終了理由 |
| `model` | `String` | 使用モデル |
| `rawText` | `String` | 生レスポンス |

## 設定

### Temperature

```swift
var conversation = Conversation(
    client: client,
    model: .sonnet,
    temperature: 0.7  // 0.0 = 確定的、1.0 = 創造的
)
```

### 最大トークン

```swift
var conversation = Conversation(
    client: client,
    model: .sonnet,
    maxTokens: 500
)
```

## 並行処理

``Conversation`` は `Sendable` であり、非同期での使用に対応:

```swift
Task {
    var conv = conversation
    let result: MyType = try await conv.send("こんにちは")
}
```
