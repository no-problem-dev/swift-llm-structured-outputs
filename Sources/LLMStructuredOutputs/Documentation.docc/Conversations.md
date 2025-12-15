# 会話

構造化出力を使用したマルチターン会話の管理方法を学びます。

## 概要

``ConversationHistory`` は、LLM とのマルチターン会話を管理する Actor です。
履歴はクライアントやモデルから独立しており、異なるプロバイダー間で同じ会話を継続できます。

## 会話の作成と実行

```swift
let history = ConversationHistory()
let client = AnthropicClient(apiKey: "...")

@Structured
struct CityInfo {
    var name: String
    var country: String
}

let city: CityInfo = try await client.chat(
    "日本の首都は？",
    history: history,
    model: .sonnet,
    systemPrompt: "あなたは親切なアシスタントです"
)
```

## コンテキストの維持

同じ履歴を使い回すことで、コンテキストが維持されます：

```swift
// 最初のターン
let city: CityInfo = try await client.chat(
    "日本の首都は？",
    history: history,
    model: .sonnet
)

// 2番目のターン - 「その都市」が東京を指すことを理解
let pop: PopulationInfo = try await client.chat(
    "その都市の人口は？",
    history: history,
    model: .sonnet
)
```

## 異なるプロバイダー間での継続

履歴はクライアントから独立しているため、プロバイダーを切り替えられます：

```swift
let history = ConversationHistory()

// Claude で会話開始
let claude = AnthropicClient(apiKey: "...")
let city: CityInfo = try await claude.chat(
    "日本の首都は？",
    history: history,
    model: .sonnet
)

// 同じ履歴で GPT に切り替え
let openai = OpenAIClient(apiKey: "...")
let pop: PopulationInfo = try await openai.chat(
    "その都市の人口は？",
    history: history,
    model: .gpt4o
)
```

## 状態の確認

```swift
// メッセージ履歴
let messages = await history.getMessages()

// ターン数
let turns = await history.turnCount

// トークン使用量
let usage = await history.getTotalUsage()
print("合計: \(usage.totalTokens)")
```

## 会話のリセット

```swift
await history.clear()
```

## イベントストリーム

``ConversationEvent`` を購読して、会話の変更をリアルタイムで監視できます：

```swift
Task {
    for await event in history.eventStream {
        switch event {
        case .userMessage(let msg):
            print("👤 \(msg.content)")
        case .assistantMessage(let msg):
            print("🤖 \(msg.content)")
        case .usageUpdated(let usage):
            print("📊 \(usage.totalTokens) tokens")
        case .cleared:
            print("🗑️ Cleared")
        case .error(let error):
            print("❌ \(error.localizedDescription)")
        }
    }
}
```

## 設定オプション

### Temperature

```swift
let result: Recipe = try await client.chat(
    "創作料理を提案して",
    history: history,
    model: .sonnet,
    temperature: 0.8
)
```

### 最大トークン

```swift
let result: Summary = try await client.chat(
    "要約して",
    history: history,
    model: .sonnet,
    maxTokens: 500
)
```

## Topics

### 関連型

- ``ConversationHistory``
- ``ConversationHistoryProtocol``
- ``ConversationEvent``
- ``TokenUsage``
