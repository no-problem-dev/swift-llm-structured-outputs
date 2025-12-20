# ``LLMConversationalAgent``

マルチターン対話とセッション管理を備えた会話型エージェント。

@Metadata {
    @PageColor(purple)
}

## 概要

LLMConversationalAgent は、複数ターンにわたる対話を管理しながらエージェント機能を実行する高度なセッションシステムを提供します。ユーザーとの対話、セッションの中断・再開、対話モードでの質問応答など、実用的なチャットボット構築に必要な機能を備えています。

@Row {
    @Column(size: 2) {
        ### 主な機能

        - **セッション管理** - 会話状態を Actor で安全に管理
        - **マルチターン対話** - 複数回のやり取りでコンテキストを維持
        - **対話モード** - AI からユーザーへの質問を可能に
        - **中断・再開** - セッションの一時停止と復元
        - **状態追跡** - セッションのライフサイクルを詳細に追跡
    }

    @Column {
        ```swift
        let session = ConversationalAgentSession(
            client: client,
            systemPrompt: "アシスタント",
            tools: tools
        )

        for try await phase in session.run(
            "調査して",
            model: .sonnet,
            outputType: Report.self
        ) {
            // 各フェーズを処理
        }
        ```
    }
}

## セッションの作成と実行

### 基本的な使い方

```swift
import LLMConversationalAgent
import LLMClient
import LLMTool

let client = AnthropicClient(apiKey: "sk-ant-...")

let tools = ToolSet {
    WebSearch()
    Calculator()
}

@Structured("調査結果")
struct ResearchResult {
    @StructuredField("要約")
    var summary: String

    @StructuredField("詳細")
    var details: [String]
}

// セッションを作成
let session = ConversationalAgentSession(
    client: client,
    systemPrompt: Prompt {
        "あなたはリサーチアシスタントです。"
        "ユーザーの質問に対して、ツールを使って調査し、結果を報告します。"
    },
    tools: tools
)

// 実行
for try await phase in session.run(
    "AI市場の最新トレンドを調査して",
    model: .sonnet,
    outputType: ResearchResult.self
) {
    switch phase {
    case .running(let step):
        switch step {
        case .thinking:
            print("🤔 思考中...")
        case .toolCall(let call):
            print("🔧 ツール: \(call.name)")
        case .toolResult(let result):
            print("📄 結果取得")
        default:
            break
        }
    case .completed(let result):
        print("✅ 完了: \(result.summary)")
    case .failed(let error):
        print("❌ エラー: \(error)")
    default:
        break
    }
}
```

## マルチターン対話

同じセッションで複数回の対話を行えます。

```swift
let session = ConversationalAgentSession(
    client: client,
    systemPrompt: "分析アシスタント",
    tools: tools
)

// 1回目の対話
for try await phase in session.run(
    "このデータを分析して",
    model: .sonnet,
    outputType: InitialAnalysis.self
) {
    // 処理
}

// 2回目の対話（コンテキストが維持される）
for try await phase in session.run(
    "さらに深掘りして",
    model: .sonnet,
    outputType: DetailedAnalysis.self
) {
    // 処理
}

// ターン数を確認
print(await session.turnCount)  // 2
```

## 対話モード

AI からユーザーに質問できる対話モードを有効にします。

```swift
// interactiveMode: true で対話モードを有効化
let session = ConversationalAgentSession(
    client: client,
    systemPrompt: "カスタマーサポート",
    tools: tools,
    interactiveMode: true  // 対話モード有効
)

for try await phase in session.run(
    "注文をキャンセルしたい",
    model: .sonnet,
    outputType: SupportResult.self
) {
    switch phase {
    case .awaitingUserInput(let question):
        // AI からの質問
        print("❓ \(question)")

        // ユーザーの回答を渡す
        await session.reply("注文番号は12345です")

    case .completed(let result):
        print("✅ \(result.resolution)")

    default:
        break
    }
}
```

## セッション状態

`SessionStatus` でセッションの現在の状態を確認できます。

```swift
let status = await session.status

switch status {
case .idle:
    print("待機中 - 実行可能")
case .running(let step):
    print("実行中: \(step)")
case .awaitingUserInput(let question):
    print("ユーザー入力待ち: \(question)")
case .paused:
    print("一時停止中")
case .failed(let error):
    print("エラー: \(error)")
}

// 状態チェック用のプロパティ
if status.canRun {
    // 新しい対話を開始可能
}
if status.canReply {
    // ユーザー入力を受付可能
}
```

## セッションの中断と再開

### 中断

```swift
// 実行中に中断
await session.cancel()

// 状態を確認
print(await session.status)  // .paused
```

### 再開

```swift
// セッションを再開
for try await phase in session.resume(
    model: .sonnet,
    outputType: ResearchResult.self
) {
    // 中断箇所から継続
}
```

### 割り込み

実行中のセッションにメッセージを割り込ませます。

```swift
// 実行中に割り込み
await session.interrupt("優先度を変更: 緊急のタスクを先に")

// 次のステップで割り込みメッセージが処理される
```

## セッションの復元

過去の会話履歴からセッションを復元できます。

```swift
let savedMessages: [LLMMessage] = loadSavedMessages()

let session = ConversationalAgentSession(
    client: client,
    systemPrompt: "アシスタント",
    tools: tools,
    initialMessages: savedMessages  // 保存した履歴で初期化
)

// 会話を継続
for try await phase in session.run(
    "続きを教えて",
    model: .sonnet,
    outputType: Response.self
) {
    // 処理
}
```

## SessionPhase

セッションの各フェーズを表す列挙型です。

| フェーズ | 説明 |
|---------|------|
| `.idle` | 待機中 |
| `.running(step:)` | 実行中（ステップを含む） |
| `.awaitingUserInput(question:)` | ユーザー入力待ち |
| `.paused` | 一時停止中 |
| `.completed(output:)` | 完了（構造化出力を含む） |
| `.failed(error:)` | エラー発生 |

## Topics

### セッション

- ``ConversationalAgentSession``
- ``ConversationalAgentSessionProtocol``

### フェーズと状態

- ``SessionPhase``
- ``SessionStatus``
- ``AgentStep``

### ツール

- ``AskUserTool``

### エラー

- ``ConversationalAgentError``
