# エージェントループ

LLM が自動的にツールを選択・実行し、最終的に構造化出力を生成するまでループする機能です。

## 概要

`runAgent` は以下を自動化します：

1. LLM にプロンプトを送信
2. LLM がツール呼び出しを判断
3. ツールを自動実行
4. 結果を LLM に返却
5. 最終的な構造化出力を取得

手動でツール実行ループを書く必要がなく、`for await` で各ステップを監視できます。

## 基本的な使い方

### 1. 出力型を定義

```swift
import LLMStructuredOutputs

@Structured("天気レポート")
struct WeatherReport {
    @StructuredField("場所")
    var location: String

    @StructuredField("天気")
    var conditions: String

    @StructuredField("気温")
    var temperature: Int

    @StructuredField("単位")
    var unit: String

    @StructuredField("要約")
    var summary: String
}
```

### 2. ツールを定義

```swift
@Tool("指定された都市の天気を取得します")
struct GetWeather {
    @ToolArgument("都市名")
    var location: String

    func call() async throws -> String {
        // 実際の天気 API を呼び出す
        return "\(location): 晴れ、25°C"
    }
}

@Tool("数式を計算します")
struct Calculator {
    @ToolArgument("計算式")
    var expression: String

    func call() async throws -> String {
        let expr = NSExpression(format: expression)
        if let result = expr.expressionValue(with: nil, context: nil) as? NSNumber {
            return "\(expression) = \(result)"
        }
        return "計算できません"
    }
}
```

### 3. エージェントループを実行

```swift
let client = AnthropicClient(apiKey: "sk-ant-...")

let tools = ToolSet {
    GetWeather.self
    Calculator.self
}

let agentStream: some AgentStepStream<WeatherReport> = client.runAgent(
    prompt: "東京の天気を調べて、気温を華氏に変換してレポートを作成して",
    model: .sonnet,
    tools: tools
)

for try await step in agentStream {
    switch step {
    case .thinking:
        print("💭 思考中...")
    case .toolCall(let call):
        print("🔧 ツール呼び出し: \(call.name)")
    case .toolResult(let result):
        print("📤 結果: \(result.output)")
    case .finalResponse(let report):
        print("✅ 完了: \(report.location) - \(report.temperature)°\(report.unit)")
    }
}
```

## AgentStep

`runAgent` が返す `AsyncSequence` の各要素です：

| ケース | 説明 |
|--------|------|
| `.thinking(LLMResponse)` | LLM の思考プロセス |
| `.toolCall(ToolCall)` | ツール呼び出し要求 |
| `.toolResult(ToolResponse)` | ツール実行結果 |
| `.finalResponse(Output)` | 最終的な構造化出力 |

### ToolCall

```swift
case .toolCall(let call):
    call.id
    call.name
    call.arguments
```

### ToolResponse

```swift
case .toolResult(let result):
    result.callId
    result.name
    result.output
    result.isError
```

## AgentConfiguration

エージェントの動作を設定します：

```swift
let config = AgentConfiguration(
    maxSteps: 10,        // 最大ステップ数（デフォルト: 10）
    autoExecuteTools: true  // ツール自動実行（デフォルト: true）
)

let stream: some AgentStepStream<WeatherReport> = client.runAgent(
    prompt: "...",
    model: .sonnet,
    tools: tools,
    configuration: config
)
```

## エラーハンドリング

```swift
do {
    for try await step in agentSequence {
        // 処理
    }
} catch let error as AgentError {
    switch error {
    case .maxStepsExceeded(let steps):
        print("最大ステップ数(\(steps))を超過")
    case .toolNotFound(let name):
        print("ツールが見つかりません: \(name)")
    case .toolExecutionFailed(let name, let underlying):
        print("ツール実行エラー: \(name) - \(underlying)")
    case .outputDecodingFailed(let underlying):
        print("出力デコードエラー: \(underlying)")
    case .invalidState(let message):
        print("不正な状態: \(message)")
    case .llmError(let llmError):
        print("LLMエラー: \(llmError)")
    }
}
```

## 対応プロバイダー

| プロバイダー | 対応状況 |
|-------------|---------|
| Anthropic (Claude) | ✅ 対応 |
| OpenAI (GPT) | ✅ 対応 |
| Google (Gemini) | ✅ 対応 |

## planToolCalls との違い

| 機能 | planToolCalls | runAgent |
|------|---------------|----------|
| ツール実行 | 手動 | 自動 |
| ループ処理 | 手動 | 自動 |
| 最終出力 | テキスト/ツール計画 | 構造化出力 |
| 用途 | 細かい制御が必要な場合 | 一般的なエージェント処理 |

## 次のステップ

- [内部実装ガイド](agent-loop-internals.md) でフェーズ管理、終了ポリシー、状態管理の詳細を確認
- [ツールコール](tool-calling.md) で手動制御が必要な場合の実装を確認
- [はじめに](getting-started.md) で基本的なセットアップを確認
