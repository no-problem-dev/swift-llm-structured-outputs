# swift-llm-structured-outputs

型安全な構造化出力を生成する Swift LLM クライアントライブラリ

🌐 **[English](README_EN.md)** | 日本語

![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%2B%20%7C%20macOS%2014%2B%20%7C%20Linux-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## できること

- **LLM エージェントの構築** - ツールを自動実行し、構造化された結果を生成
- **型安全な構造化出力** - LLM の応答を Swift 構造体として取得
- **マルチターン会話** - コンテキストを保持した継続的な対話
- **3大プロバイダー対応** - Claude、GPT、Gemini を統一 API で利用

## 特徴

- **Swift Macro DSL** - `@Structured`、`@Tool` で宣言的に定義、スキーマ自動生成
- **エンドツーエンド** - ツール定義から自動実行、構造化出力まで一貫したフロー
- **自動リトライ** - レート制限・サーバーエラー時に指数バックオフで自動再試行
- **クロスプラットフォーム** - iOS / macOS / Linux（Docker）対応

## クイックスタート

```swift
import LLMStructuredOutputs

@Structured("ユーザー情報")
struct UserInfo {
    @StructuredField("名前")
    var name: String

    @StructuredField("年齢", .minimum(0), .maximum(150))
    var age: Int
}

// Claude を使用
let client = AnthropicClient(apiKey: "sk-ant-...")
let user: UserInfo = try await client.generate(
    prompt: "山田太郎さんは35歳です",
    model: .sonnet
)

print(user.name)  // "山田太郎"
print(user.age)   // 35
```

### プロンプトビルダー

構造化されたプロンプトをビルダーで構築できます：

```swift
let prompt = Prompt {
    PromptComponent.role("データ分析の専門家")
    PromptComponent.objective("ユーザー情報を抽出する")
    PromptComponent.instruction("名前は敬称を除いて抽出")
    PromptComponent.constraint("推測はしない")
    PromptComponent.example(
        input: "佐藤花子さん（28）は東京在住",
        output: #"{"name": "佐藤花子", "age": 28}"#
    )
}

let user: UserInfo = try await client.generate(
    prompt: prompt,
    model: .sonnet
)
```

### ツール定義

`@Tool` マクロで LLM が呼び出せるツールを定義します：

```swift
@Tool("指定された都市の天気を取得する")
struct GetWeather {
    @ToolArgument("都市名")
    var location: String

    func call() async throws -> String {
        return "\(location): 晴れ、22°C"
    }
}
```

### 会話

`ConversationHistory` でマルチターン会話のコンテキストを維持します：

```swift
let client = AnthropicClient(apiKey: "...")
let history = ConversationHistory()

// 最初の会話
let response1: UserInfo = try await client.chat(
    prompt: "山田太郎さんは35歳です",
    model: .sonnet,
    history: history
)

// 会話を継続（前のコンテキストを保持）
let response2: UserInfo = try await client.chat(
    prompt: "彼の年齢を1歳増やして",
    model: .sonnet,
    history: history
)

print(response2.age)  // 36
```

### エージェントループ

`runAgent` で LLM がツールを自動実行し、構造化出力を生成するまでループします：

```swift
@Structured("天気レポート")
struct WeatherReport {
    @StructuredField("場所") var location: String
    @StructuredField("天気") var conditions: String
    @StructuredField("気温") var temperature: Int
}

let tools = ToolSet { GetWeather() }

let stream: some AgentStepStream<WeatherReport> = client.runAgent(
    prompt: "東京の天気を調べてレポートを作成して",
    model: .sonnet,
    tools: tools
)

for try await step in stream {
    switch step {
    case .toolCall(let call): print("🔧 \(call.name)")
    case .toolResult(let result): print("📤 \(result.output)")
    case .finalResponse(let report): print("✅ \(report.location): \(report.conditions)")
    default: break
    }
}
```

### 会話型エージェント

`ConversationalAgentSession` でマルチターン会話を保持しながらエージェントループを実行します：

```swift
let session = ConversationalAgentSession(
    client: AnthropicClient(apiKey: "..."),
    systemPrompt: Prompt { PromptComponent.role("リサーチアシスタント") },
    tools: ToolSet { WebSearchTool() }
)

let stream: some ConversationalAgentStepStream<ResearchResult> = session.run(
    "AIエージェントについて調査して",
    model: .sonnet
)

for try await step in stream {
    switch step {
    case .toolCall(let call): print("🔧 \(call.name)")
    case .finalResponse(let output): print("✅ \(output.summary)")
    default: break
    }
}

let followUp: some ConversationalAgentStepStream<ResearchResult> = session.run(
    "セキュリティ面について詳しく",
    model: .sonnet
)
```

詳細は[エージェントループガイド](documentation/agent-loop.md)、[会話型エージェントガイド](documentation/conversational-agent.md)を参照してください。

## インストール

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-llm-structured-outputs.git", .upToNextMajor(from: "1.0.0"))
]

.target(
    name: "YourApp",
    dependencies: [
        .product(name: "LLMStructuredOutputs", package: "swift-llm-structured-outputs")
    ]
)
```

## ドキュメント

### 📖 使用ガイド

| ガイド | 説明 |
|--------|------|
| [はじめに](documentation/getting-started.md) | インストールと基本的な使い方 |
| [プロンプト構築](documentation/prompt-building.md) | ビルダーを使ったプロンプト構築 |
| [会話](documentation/conversation.md) | マルチターン会話の実装 |
| [ツールコール](documentation/tool-calling.md) | LLM に外部関数を呼び出させる |
| [エージェントループ](documentation/agent-loop.md) | ツール自動実行と構造化出力の生成 |
| [会話型エージェント](documentation/conversational-agent.md) | マルチターン会話を保持したエージェント |
| [プロバイダー](documentation/providers.md) | 各プロバイダーとモデルの詳細 |

### 📚 APIリファレンス（DocC）

- [LLMStructuredOutputs](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/) - 型安全な構造化出力 API

## 対応プロバイダー

| プロバイダー | クライアント | モデル例 |
|-------------|-------------|---------|
| Anthropic | `AnthropicClient` | `.sonnet`, `.opus`, `.haiku` |
| OpenAI | `OpenAIClient` | `.gpt4o`, `.gpt4oMini`, `.o1` |
| Google | `GeminiClient` | `.pro25`, `.flash25`, `.flash25Lite` |

## 要件

### Apple プラットフォーム
- iOS 17.0+ / macOS 14.0+
- Swift 6.0+
- Xcode 16+

### Linux
- Swift 6.0+
- Docker 対応（`Dockerfile` 同梱）

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照

## 開発者向け情報

- 🚀 **リリース作業**: [リリースプロセス](RELEASE_PROCESS.md)

## サポート

- 🐛 [Issue報告](https://github.com/no-problem-dev/swift-llm-structured-outputs/issues)
- 💬 [ディスカッション](https://github.com/no-problem-dev/swift-llm-structured-outputs/discussions)

---

Made with ❤️ by [NOPROBLEM](https://github.com/no-problem-dev)
