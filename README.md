# swift-llm-structured-outputs

型安全な構造化出力を生成する Swift LLM クライアントライブラリ

🌐 **[English](README_EN.md)** | 日本語

![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%2B%20%7C%20macOS%2014%2B-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## できること

- LLM からの応答を Swift 構造体として型安全に取得
- Claude、GPT、Gemini の 3 大プロバイダーをサポート
- マルチターン会話の状態管理
- JSON Schema の自動生成とバリデーション

## 特徴

- **Swift Macro DSL** - `@Structured`、`@StructuredField`、`@StructuredEnum` で構造化出力の型を定義
- **コンパイル時型安全** - プロバイダーとモデルの組み合わせをコンパイル時にチェック
- **会話継続** - `Conversation` クラスによるコンテキスト維持とトークン使用量追跡
- **制約サポート** - 最小/最大値、文字数制限、正規表現パターンなど

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

### プロンプト DSL

構造化されたプロンプトを DSL で構築できます：

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

### エージェントループ

`runAgent` で LLM がツールを自動実行し、構造化出力を生成するまでループします：

```swift
@Structured("天気レポート")
struct WeatherReport {
    @StructuredField("場所") var location: String
    @StructuredField("天気") var conditions: String
    @StructuredField("気温") var temperature: Int
}

let tools = ToolSet { GetWeather.self }

let sequence: AgentStepSequence<AnthropicClient, WeatherReport> = client.runAgent(
    prompt: "東京の天気を調べてレポートを作成して",
    model: .sonnet,
    tools: tools
)

for try await step in sequence {
    switch step {
    case .toolCall(let info): print("🔧 \(info.name)")
    case .toolResult(let info): print("📤 \(info.content)")
    case .finalResponse(let report): print("✅ \(report.location): \(report.conditions)")
    default: break
    }
}
```

詳細は[エージェントループガイド](documentation/agent-loop.md)を参照してください。

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
| [プロンプト構築](documentation/prompt-building.md) | DSL を使ったプロンプト構築 |
| [ツールコール](documentation/tool-calling.md) | LLM に外部関数を呼び出させる |
| [エージェントループ](documentation/agent-loop.md) | ツール自動実行と構造化出力の生成 |
| [プロバイダー](documentation/providers.md) | 各プロバイダーとモデルの詳細 |
| [会話](documentation/conversation.md) | マルチターン会話の実装 |

### 📚 APIリファレンス（DocC）

- [LLMStructuredOutputs](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/) - 型安全な構造化出力 API

## サンプルアプリ

`Examples/LLMStructuredOutputsExample` に iOS サンプルアプリを同梱。全機能をインタラクティブに確認できます。

### デモ一覧

| デモ | 確認できる機能 |
|-----|--------------|
| 基本的な構造化出力 | `@Structured` による型定義、`generate()` による出力生成 |
| フィールド制約 | `.minimum()`, `.maximum()`, `.pattern()` 等の制約 |
| 列挙型サポート | `@StructuredEnum` による enum 出力 |
| 会話機能 | `Conversation` によるマルチターン会話 |
| イベントストリーム | `chatStream()` によるストリーミング応答 |
| プロンプト DSL | `Prompt { }` ビルダーによるプロンプト構築 |
| ツールコール | `@Tool` によるツール定義、`planToolCalls()` による計画 |
| エージェントループ | `runAgent()` によるツール自動実行と構造化出力生成 |
| **プロバイダー比較** | Claude/GPT/Gemini の並列比較、レスポンス時間・トークン計測 |

### プロバイダー比較デモ

3大プロバイダーの構造化出力品質を比較検証：

- **モデル選択**: 各プロバイダーのモデルを個別に選択
- **テストケース**: 5カテゴリ・14種類（情報抽出、推論、構造、品質、言語）
- **カスタム入力**: 任意のプロンプトで比較テスト実行
- **計測項目**: レスポンス時間、トークン使用量、出力 JSON

```bash
# サンプルアプリを開く
open Examples/LLMStructuredOutputsExample/LLMStructuredOutputsExample.xcodeproj
```

## 対応プロバイダー

| プロバイダー | クライアント | モデル例 |
|-------------|-------------|---------|
| Anthropic | `AnthropicClient` | `.sonnet`, `.opus`, `.haiku` |
| OpenAI | `OpenAIClient` | `.gpt4o`, `.gpt4oMini`, `.o1` |
| Google | `GeminiClient` | `.pro25`, `.flash25`, `.flash25Lite` |

## 要件

- iOS 17.0+ / macOS 14.0+
- Swift 6.0+
- Xcode 16+

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照

## 開発者向け情報

- 🚀 **リリース作業**: [リリースプロセス](RELEASE_PROCESS.md)

## サポート

- 🐛 [Issue報告](https://github.com/no-problem-dev/swift-llm-structured-outputs/issues)
- 💬 [ディスカッション](https://github.com/no-problem-dev/swift-llm-structured-outputs/discussions)

---

Made with ❤️ by [NOPROBLEM](https://github.com/no-problem-dev)
