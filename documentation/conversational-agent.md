# 会話型エージェント

`ConversationalAgentSession` は、マルチターン会話を保持しながらエージェントループを実行する機能です。

## 概要

`runAgent` との違い：

| 機能 | runAgent | ConversationalAgentSession |
|------|----------|---------------------------|
| 会話履歴 | 手動管理 | 自動管理 |
| ターン継続 | 不可 | 可能 |
| 割り込み | 不可 | 可能 |
| イベントストリーム | なし | あり |

## 基本的な使い方

### 1. セッション作成

```swift
import LLMStructuredOutputs

let client = AnthropicClient(apiKey: "sk-ant-...")

let tools = ToolSet {
    WebSearchTool.self
    FetchPageTool.self
}

let session = ConversationalAgentSession(
    client: client,
    systemPrompt: Prompt {
        PromptComponent.role("リサーチアシスタント")
    },
    tools: tools
)
```

### 2. ストリーム取得と実行

```swift
@Structured("調査結果")
struct ResearchResult {
    @StructuredField("要約")
    var summary: String

    @StructuredField("主要な発見")
    var findings: [String]
}

let stream: some ConversationalAgentStepStream<ResearchResult> = session.run(
    "AIエージェントについて調査して",
    model: .sonnet
)

for try await step in stream {
    switch step {
    case .userMessage(let msg):
        print("👤 \(msg)")
    case .thinking:
        print("🤔 思考中...")
    case .toolCall(let call):
        print("🔧 \(call.name)")
    case .toolResult(let result):
        print("📄 \(result.output)")
    case .interrupted(let msg):
        print("⚡ \(msg)")
    case .textResponse(let text):
        print("💬 \(text)")
    case .finalResponse(let output):
        print("✅ \(output.summary)")
    }
}
```

### 3. 会話の継続

前回の会話を保持したまま追加の質問ができます：

```swift
let followUpStream: some ConversationalAgentStepStream<ResearchResult> = session.run(
    "セキュリティ面についてもっと詳しく",
    model: .sonnet
)

for try await step in followUpStream {
    if case .finalResponse(let output) = step {
        print(output.summary)
    }
}
```

## 割り込み機能

エージェント実行中に追加の指示を送信できます：

```swift
let stream: some ConversationalAgentStepStream<ResearchResult> = session.run(
    "長時間の調査タスク",
    model: .sonnet
)

let task = Task {
    for try await step in stream {
        switch step {
        case .interrupted(let message):
            print("⚡ 割り込み受信: \(message)")
        default:
            break
        }
    }
}

try await Task.sleep(for: .seconds(2))
await session.interrupt("特にセキュリティ面に焦点を当てて")

try await Task.sleep(for: .seconds(3))
await session.interrupt("コード例も含めて")

await task.value
```

## イベントストリーム

UI 更新用のイベントを監視できます：

```swift
Task {
    for await event in session.eventStream {
        switch event {
        case .sessionStarted:
            showLoading()
        case .userMessage(let msg):
            displayMessage(msg, isUser: true)
        case .assistantMessage(let msg):
            displayMessage(msg, isUser: false)
        case .interruptQueued(let msg):
            showNotification("割り込み: \(msg)")
        case .sessionCompleted:
            hideLoading()
        case .error(let error):
            showError(error)
        default:
            break
        }
    }
}
```

## ConversationalAgentStep

| ケース | 説明 |
|--------|------|
| `.userMessage(String)` | ユーザーメッセージ送信 |
| `.thinking(LLMResponse)` | LLM 思考中 |
| `.toolCall(ToolCall)` | ツール呼び出し |
| `.toolResult(ToolResponse)` | ツール実行結果 |
| `.interrupted(String)` | 割り込み処理 |
| `.textResponse(String)` | テキスト応答 |
| `.finalResponse(Output)` | 最終構造化出力 |

## ConversationalAgentEvent

| イベント | 説明 |
|----------|------|
| `.userMessage(LLMMessage)` | ユーザーメッセージ追加 |
| `.assistantMessage(LLMMessage)` | アシスタント応答追加 |
| `.interruptQueued(String)` | 割り込みキュー追加 |
| `.interruptProcessed(String)` | 割り込み処理完了 |
| `.sessionStarted` | セッション開始 |
| `.sessionCompleted` | セッション完了 |
| `.cleared` | 履歴クリア |
| `.error(ConversationalAgentError)` | エラー発生 |

## エラーハンドリング

```swift
do {
    for try await step in stream {
        // 処理
    }
} catch let error as ConversationalAgentError {
    switch error {
    case .maxStepsExceeded(let steps):
        print("最大ステップ数超過: \(steps)")
    case .toolNotFound(let name):
        print("ツールが見つかりません: \(name)")
    case .toolExecutionFailed(let name, let underlying):
        print("ツール実行エラー: \(name) - \(underlying)")
    case .outputDecodingFailed(let underlying):
        print("デコードエラー: \(underlying)")
    case .llmError(let llmError):
        print("LLMエラー: \(llmError)")
    case .sessionAlreadyRunning:
        print("セッション実行中")
    case .invalidState(let message):
        print("無効な状態: \(message)")
    }
}
```

## セッション管理

```swift
let messages = await session.getMessages()

let turns = await session.turnCount

let isRunning = await session.running

await session.clear()
```

## 次のステップ

- [エージェントループ](agent-loop.md) で単発のエージェント実行を確認
- [ツールコール](tool-calling.md) でツール定義の詳細を確認
- [会話](conversation.md) で `ConversationHistory` の使い方を確認
