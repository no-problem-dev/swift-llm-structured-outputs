# エージェントループ

LLM が自動的にツールを選択・実行し、構造化出力を生成するまでループします。

## 概要

`runAgent` メソッドを使用すると、LLM がツールを呼び出し、その結果を元に次のアクションを判断し、最終的に構造化出力を生成するまでの一連の処理を自動化できます。

## 基本的な使い方

出力型とツールを定義し、`runAgent` を呼び出します：

```swift
import LLMStructuredOutputs

// 出力型
@Structured("天気レポート")
struct WeatherReport {
    @StructuredField("場所")
    var location: String
    @StructuredField("天気")
    var conditions: String
    @StructuredField("気温")
    var temperature: Int
}

// ツール
@Tool("天気を取得する")
struct GetWeather {
    @ToolArgument("都市名")
    var location: String

    func call() async throws -> String {
        return "\(location): 晴れ、25°C"
    }
}

// 実行
let client = AnthropicClient(apiKey: "...")
let tools = ToolSet { GetWeather.self }

let stream: some AgentStepStream<WeatherReport> = client.runAgent(
    prompt: "東京の天気を調べてレポートを作成して",
    model: .sonnet,
    tools: tools
)

for try await step in stream {
    switch step {
    case .thinking:
        print("思考中...")
    case .toolCall(let call):
        print("ツール: \(call.name)")
    case .toolResult(let result):
        print("結果: \(result.output)")
    case .finalResponse(let report):
        print("完了: \(report.location)")
    }
}
```

## AgentStep

各ステップの種類：

- ``AgentStep/thinking(_:)`` - LLM の思考
- ``AgentStep/toolCall(_:)`` - ツール呼び出し
- ``AgentStep/toolResult(_:)`` - ツール実行結果
- ``AgentStep/finalResponse(_:)`` - 構造化出力

## 対応プロバイダー

- **Anthropic (Claude)**: 対応
- **OpenAI (GPT)**: 対応
- **Google (Gemini)**: 対応

## 内部実装

エージェントループの内部動作（フェーズ管理、終了ポリシー、状態管理など）について詳しく知りたい場合は、<doc:AgentLoopInternals> を参照してください。

## Topics

### 型

- ``AgentStep``
- ``AgentStepStream``
- ``AgentConfiguration``
- ``AgentContext``
- ``AgentError``

### ツール関連

- ``ToolCall``
- ``ToolResponse``
