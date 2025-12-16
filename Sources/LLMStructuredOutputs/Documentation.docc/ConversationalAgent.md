# 会話型エージェント

マルチターン会話を保持しながらエージェントループを実行します。

## 概要

``ConversationalAgentSession`` は以下の機能を提供します：

- **会話履歴の自動管理**: 複数ターンにわたる会話を自動追跡
- **割り込みサポート**: 実行中のエージェントに追加指示を送信
- **イベントストリーム**: UI 連携のための非同期イベント配信
- **インタラクティブモード**: ``AskUserTool`` で AI がユーザーに質問可能

## 基本的な使い方

セッションを作成し、`run()` でエージェントループを実行します：

```swift
let session = ConversationalAgentSession(
    client: AnthropicClient(apiKey: "..."),
    systemPrompt: Prompt {
        PromptComponent.role("リサーチアシスタント")
    },
    tools: ToolSet { WebSearchTool.self }
)

let stream: some ConversationalAgentStepStream<ResearchResult> = session.run(
    "AIエージェントについて調査して",
    model: .sonnet
)

for try await step in stream {
    switch step {
    case .toolCall(let call):
        print("🔧 \(call.name)")
    case .finalResponse(let output):
        print("✅ \(output)")
    default:
        break
    }
}
```

## 会話の継続

同じセッションで追加の質問ができます：

```swift
let followUpStream: some ConversationalAgentStepStream<ResearchResult> = session.run(
    "セキュリティ面についてもっと詳しく",
    model: .sonnet
)
```

## 割り込み機能

実行中に追加指示を送信：

```swift
await session.interrupt("特にセキュリティ面に焦点を当てて")
```

## イベント監視

UI 更新用のイベントストリーム：

```swift
for await event in session.eventStream {
    switch event {
    case .sessionStarted:
        showLoading()
    case .sessionCompleted:
        hideLoading()
    default:
        break
    }
}
```

## インタラクティブモード

``AskUserTool`` を追加すると、AI がユーザーに質問できるようになります：

```swift
let session = ConversationalAgentSession(
    client: client,
    systemPrompt: Prompt {
        PromptComponent.role("リサーチアシスタント")
        PromptComponent.instruction("不明な点は ask_user で質問してください")
    },
    tools: ToolSet {
        WebSearchTool.self
        AskUserTool.self  // インタラクティブモードを有効化
    }
)

for try await step in stream {
    switch step {
    case .askingUser(let question):
        // ユーザーに質問を表示
        let answer = getUserInput(question)
        await session.provideAnswer(answer)
    case .finalResponse(let output):
        print(output)
    default:
        break
    }
}
```

## Topics

### セッション

- ``ConversationalAgentSession``
- ``ConversationalAgentSessionProtocol``

### ステップ

- ``ConversationalAgentStep``
- ``ConversationalAgentStepStream``

### イベント

- ``ConversationalAgentEvent``
- ``ConversationalAgentError``

### ツール

- ``AskUserTool``
