# ``LLMConversation``

マルチターン会話とチャット履歴を管理するモジュール。

@Metadata {
    @PageColor(orange)
}

## 概要

LLMConversation は、LLM とのマルチターン会話を管理するための機能を提供します。会話履歴の追跡、トークン使用量の監視、イベントストリームによるリアルタイム通知など、チャットアプリケーション構築に必要な機能を備えています。

@Row {
    @Column(size: 2) {
        ### 主な機能

        - **会話履歴管理** - メッセージ履歴を Actor で安全に管理
        - **トークン追跡** - 累計トークン使用量をリアルタイムで把握
        - **イベントストリーム** - 会話イベントの非同期購読
        - **プロバイダー非依存** - 同じ履歴を異なる LLM で継続可能
        - **ストリーミング対応** - レスポンスの逐次処理
    }

    @Column {
        ```swift
        let history = ConversationHistory()

        // 会話を実行
        let result: CityInfo = try await client.chat(
            "東京の人口は？",
            history: history,
            model: .sonnet
        )

        // ターン数を確認
        print(await history.turnCount)  // 1
        ```
    }
}

## 会話の実行

### 基本的な使い方

`chat()` メソッドで会話を実行し、`ConversationHistory` で履歴を管理します。

```swift
import LLMClient
import LLMConversation

let client = AnthropicClient(apiKey: "sk-ant-...")
let history = ConversationHistory()

// 1回目の質問
let answer1: CityInfo = try await client.chat(
    "日本の首都は？",
    history: history,
    model: .sonnet
)
print(answer1.name)  // "東京"

// 2回目の質問（コンテキストが維持される）
let answer2: PopulationInfo = try await client.chat(
    "その都市の人口は？",
    history: history,
    model: .sonnet
)
print(answer2.population)  // 13960000
```

### ストリーミング会話

レスポンスを逐次的に受け取れます。

```swift
let history = ConversationHistory()

for try await event in client.chatStream(
    "長文で説明してください",
    history: history,
    model: .sonnet
) as AsyncThrowingStream<ChatStreamEvent<Analysis>, Error> {
    switch event {
    case .text(let chunk):
        print(chunk, terminator: "")
    case .completed(let result):
        print("\n完了: \(result)")
    }
}
```

## ConversationHistory

Actor として実装された会話履歴管理クラスです。

### 履歴の確認

```swift
let history = ConversationHistory()

// 会話を実行...

// 状態を確認
let messages = await history.getMessages()
let usage = await history.getTotalUsage()
let turns = await history.turnCount

print("メッセージ数: \(messages.count)")
print("総トークン: \(usage.totalTokens)")
print("ターン数: \(turns)")
```

### 既存履歴からの復元

過去の会話を復元して継続できます。

```swift
let savedMessages: [LLMMessage] = [
    .user("こんにちは"),
    .assistant("こんにちは！何かお手伝いできますか？")
]

let history = ConversationHistory(messages: savedMessages)

// 会話を継続
let result: Response = try await client.chat(
    "天気を教えて",
    history: history,
    model: .sonnet
)
```

### 履歴のクリア

```swift
await history.clear()
print(await history.turnCount)  // 0
```

## イベントストリーム

会話の変更をリアルタイムで購読できます。

```swift
let history = ConversationHistory()

// イベントを購読
Task {
    for await event in history.eventStream {
        switch event {
        case .userMessage(let msg):
            print("👤 User: \(msg.textContent ?? "")")
        case .assistantMessage(let msg):
            print("🤖 Assistant: \(msg.textContent ?? "")")
        case .usageUpdated(let usage):
            print("📊 Tokens: \(usage.totalTokens)")
        case .cleared:
            print("🗑️ History cleared")
        case .error(let error):
            print("❌ Error: \(error)")
        }
    }
}

// 会話を実行（イベントが発行される）
let result: Response = try await client.chat(
    "質問です",
    history: history,
    model: .sonnet
)
```

## プロバイダー間での継続

同じ履歴を異なるプロバイダーで使用できます。

```swift
let history = ConversationHistory()

// Claude で開始
let claude = AnthropicClient(apiKey: "...")
let _ = try await claude.chat("分析を始めて", history: history, model: .sonnet)

// GPT で継続
let gpt = OpenAIClient(apiKey: "...")
let _ = try await gpt.chat("詳しく説明して", history: history, model: .gpt4o)

// Gemini で完了
let gemini = GeminiClient(apiKey: "...")
let result: FinalReport = try await gemini.chat("まとめて", history: history, model: .flash)
```

## Topics

### 会話履歴

- ``ConversationHistory``
- ``ConversationHistoryProtocol``

### メッセージ

- ``LLMClient/LLMMessage``

### イベント

- ``ConversationEvent``

### レスポンス

- ``ChatResponse``
- ``TokenUsage``

### クライアント拡張

- ``ChatCapableClient``
