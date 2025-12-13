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
| [プロバイダー](documentation/providers.md) | 各プロバイダーとモデルの詳細 |
| [会話](documentation/conversation.md) | マルチターン会話の実装 |

### 📚 APIリファレンス（DocC）

- [LLMStructuredOutputs](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/) - 型安全な構造化出力 API

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
