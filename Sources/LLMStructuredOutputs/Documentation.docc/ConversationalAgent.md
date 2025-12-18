# 会話型エージェント

マルチターン会話を保持しながらエージェントループを実行します。

## 概要

`ConversationalAgentSession` は以下の機能を提供します：

- **会話履歴の自動管理**: 複数ターンにわたる会話を自動追跡
- **割り込みサポート**: 実行中のエージェントに追加指示を送信
- **型安全なストリーミング**: `SessionPhase<Output>` を通じた型付き出力
- **インタラクティブモード**: AI がユーザーに質問可能

## 基本的な使い方

セッションを作成し、`run()` でエージェントループを実行します：

```swift
let session = ConversationalAgentSession(
    client: AnthropicClient(apiKey: "..."),
    systemPrompt: Prompt {
        PromptComponent.role("リサーチアシスタント")
    },
    tools: ToolSet { WebSearchTool() }
)

for try await phase in session.run("AIエージェントについて調査して", model: .sonnet, outputType: ResearchResult.self) {
    switch phase {
    case .running(let step):
        switch step {
        case .toolCall(let call):
            print("🔧 \(call.name)")
        default:
            break
        }
    case .completed(let output):
        print("✅ \(output)")
    default:
        break
    }
}
```

## 会話の継続

同じセッションで追加の質問ができます：

```swift
for try await phase in session.run("セキュリティ面についてもっと詳しく", model: .sonnet, outputType: ResearchResult.self) {
    if case .completed(let output) = phase {
        print("✅ \(output)")
    }
}
```

## 割り込み機能

実行中に追加指示を送信：

```swift
await session.interrupt("特にセキュリティ面に焦点を当てて")
```

## インタラクティブモード

`interactiveMode: true` を指定すると、AI がユーザーに質問できるようになります：

```swift
let session = ConversationalAgentSession(
    client: client,
    systemPrompt: Prompt {
        PromptComponent.role("リサーチアシスタント")
        PromptComponent.instruction("不明な点は ask_user で質問してください")
    },
    tools: ToolSet {
        WebSearchTool()
    },
    interactiveMode: true  // AI がユーザーに質問可能に
)

for try await phase in session.run("調査して", model: .sonnet, outputType: Result.self) {
    switch phase {
    case .awaitingUserInput(let question):
        // ユーザーに質問を表示
        let answer = getUserInput(question)
        await session.reply(answer)
    case .completed(let output):
        print(output)
    default:
        break
    }
}
```

## Topics

### 関連ガイド

- <doc:AgentLoop>
