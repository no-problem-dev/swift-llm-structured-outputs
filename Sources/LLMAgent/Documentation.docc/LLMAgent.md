# ``LLMAgent``

ツールを自動実行し、構造化出力を生成するエージェントループ機能。

@Metadata {
    @PageColor(red)
}

## 概要

LLMAgent は、LLM がツールを選択・実行し、最終的な構造化出力を生成するまで自動的にループする「エージェント」機能を提供します。複雑なタスクを複数のステップに分解し、各ステップでツールを活用しながら目標を達成します。

@Row {
    @Column(size: 2) {
        ### 主な機能

        - **自動ツール実行** - LLM の判断でツールを選択・実行
        - **ステップ追跡** - 各ステップを AsyncSequence で受信
        - **重複検出** - 同じツール呼び出しの繰り返しを防止
        - **最大ステップ制限** - 無限ループを防止する安全機構
        - **構造化出力** - 最終結果を型安全な形式で取得
    }

    @Column {
        ```swift
        for try await step in client.runAgent(
            input: "調査してレポートを作成",
            model: .sonnet,
            tools: tools
        ) {
            switch step {
            case .toolCall(let call):
                print("🔧 \(call.name)")
            case .finalResponse(let report):
                print("✅ \(report.summary)")
            default: break
            }
        }
        ```
    }
}

## エージェントループの実行

### 基本的な使い方

```swift
import LLMAgent
import LLMTool
import LLMClient

let client = AnthropicClient(apiKey: "sk-ant-...")

let tools = ToolSet {
    WebSearch()
    Calculator()
    DateTimeTool()
}

@Structured("調査レポート")
struct ResearchReport {
    @StructuredField("要約")
    var summary: String

    @StructuredField("主要な発見")
    var findings: [String]
}

// エージェントを実行
for try await step in client.runAgent(
    input: "2024年のAI市場動向を調査してレポートを作成して",
    model: .sonnet,
    tools: tools
) as AgentStepSequence<ResearchReport> {
    switch step {
    case .thinking(let response):
        print("🤔 思考中: \(response.textContent ?? "")")
    case .toolCall(let call):
        print("🔧 ツール: \(call.name)")
    case .toolResult(let result):
        print("📄 結果: \(result.output.prefix(100))...")
    case .finalResponse(let report):
        print("✅ レポート完成:")
        print("  要約: \(report.summary)")
        print("  発見: \(report.findings.joined(separator: ", "))")
    }
}
```

### システムプロンプトの指定

```swift
let systemPrompt = Prompt {
    "あなたは経験豊富なリサーチアナリストです。"

    Section("行動指針") {
        "- 複数の情報源を確認する"
        "- 事実と意見を区別する"
        "- 数値データを重視する"
    }
}

for try await step in client.runAgent(
    input: "市場分析を行って",
    model: .sonnet,
    tools: tools,
    systemPrompt: systemPrompt
) as AgentStepSequence<MarketAnalysis> {
    // ステップを処理
}
```

## AgentConfiguration

エージェントの動作を細かく制御できます。

```swift
let config = AgentConfiguration(
    maxSteps: 15,              // 最大ステップ数（デフォルト: 10）
    autoExecuteTools: true,    // ツール自動実行（デフォルト: true）
    maxDuplicateToolCalls: 3,  // 同一引数での重複呼び出し制限
    maxToolCallsPerTool: 10    // ツールごとの呼び出し回数制限
)

for try await step in client.runAgent(
    input: "複雑なタスク",
    model: .sonnet,
    tools: tools,
    configuration: config
) as AgentStepSequence<Result> {
    // ステップを処理
}
```

## AgentStep

エージェントの各ステップを表す列挙型です。

| ケース | 説明 |
|-------|------|
| `.thinking` | LLM が思考中（テキスト生成） |
| `.toolCall` | ツール呼び出しを要求 |
| `.toolResult` | ツール実行結果 |
| `.finalResponse` | 最終的な構造化出力 |

```swift
for try await step in agentStream {
    switch step {
    case .thinking(let response):
        // LLM の思考内容
        if let text = response.textContent {
            print("思考: \(text)")
        }

    case .toolCall(let call):
        // ツール呼び出し情報
        print("ツール: \(call.name)")
        print("引数: \(call.arguments)")

    case .toolResult(let result):
        // ツール実行結果
        print("結果: \(result.output)")
        if result.isError {
            print("エラー発生")
        }

    case .finalResponse(let output):
        // 型安全な最終出力
        print("完了: \(output)")
    }
}
```

## エラーハンドリング

### AgentError

エージェント固有のエラーを適切に処理します。

```swift
do {
    for try await step in client.runAgent(...) {
        // 処理
    }
} catch let error as AgentError {
    switch error {
    case .maxStepsExceeded(let steps):
        print("最大ステップ数(\(steps))を超過")
    case .toolNotFound(let name):
        print("ツールが見つかりません: \(name)")
    case .toolExecutionFailed(let name, let underlying):
        print("ツール実行エラー (\(name)): \(underlying)")
    case .outputDecodingFailed(let error):
        print("出力のデコードに失敗: \(error)")
    default:
        print("エージェントエラー: \(error)")
    }
}
```

## Topics

### エージェント実行

- ``AgentStep``
- ``AgentStepSequence``
- ``AgentStepStream``

### 設定

- ``AgentConfiguration``

### コンテキスト

- ``AgentContext``

### エラー

- ``AgentError``

### クライアント拡張

- ``AgentCapableClient``
