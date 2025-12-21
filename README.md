# swift-llm-structured-outputs

型安全な構造化出力を生成する Swift LLM クライアントライブラリ

🌐 **[English](README_EN.md)** | 日本語

![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%2B%20%7C%20macOS%2014%2B%20%7C%20Linux-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## 概要

Claude、GPT、Gemini から型安全な構造化出力を取得できる Swift ライブラリです。Swift Macro で定義した構造体に LLM の応答を直接マッピングします。

## 主要機能

- **構造化出力** - `@Structured` マクロで型安全な出力を定義、スキーマ自動生成
- **エージェント** - ツール自動実行と構造化出力生成（`runAgent`）
- **会話** - `ConversationHistory` でマルチターン会話のコンテキスト維持
- **マルチモーダル** - 画像・音声・動画の入力（Vision）と生成
- **3プロバイダー対応** - Claude、GPT、Gemini を統一 API で利用

## クイックスタート

```swift
import LLMStructuredOutputs

@Structured("ユーザー情報")
struct UserInfo {
    @StructuredField("名前") var name: String
    @StructuredField("年齢", .minimum(0)) var age: Int
}

let client = AnthropicClient(apiKey: "sk-ant-...")
let user: UserInfo = try await client.generate(
    input: "山田太郎さんは35歳です",
    model: .sonnet
)
// user.name → "山田太郎", user.age → 35
```

## インストール

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-llm-structured-outputs.git", from: "1.0.0")
]

.target(
    name: "YourApp",
    dependencies: [
        .product(name: "LLMStructuredOutputs", package: "swift-llm-structured-outputs"),
        // オプション
        .product(name: "LLMToolkits", package: "swift-llm-structured-outputs"),
        .product(name: "LLMMCP", package: "swift-llm-structured-outputs")
    ]
)
```

## ドキュメント

### API リファレンス（DocC）

| モジュール | 説明 |
|-----------|------|
| [LLMStructuredOutputs](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/) | メインモジュール（構造化出力、エージェント、会話） |
| [LLMClient](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmclient/) | LLMクライアント、プロンプト、マルチモーダル |
| [LLMToolkits](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmtoolkits/) | プリセット、組み込みツール、共通出力構造体 |
| [LLMMCP](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmmcp/) | MCP統合、組み込みToolKit |

### ガイド

| トピック | 説明 |
|---------|------|
| [はじめに](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/gettingstarted) | インストールと基本的な使い方 |
| [プロンプト構築](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/promptbuilding) | Prompt DSL によるプロンプト構築 |
| [会話](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/conversations) | マルチターン会話の実装 |
| [エージェントループ](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/agentloop) | ツール自動実行と構造化出力生成 |
| [会話型エージェント](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/conversationalagent) | マルチターン会話を保持したエージェント |
| [マルチモーダル](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmclient/multimodal) | 画像・音声・動画の入力と生成 |
| [プロバイダー](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/providers) | 各プロバイダーとモデルの詳細 |

## 機能マトリックス

### テキスト機能

| 機能 | Anthropic | OpenAI | Gemini |
|------|:---------:|:------:|:------:|
| 構造化出力 | ✓ | ✓ | ✓ |
| ストリーミング | ✓ | ✓ | ✓ |
| ツールコール | ✓ | ✓ | ✓ |
| エージェントループ | ✓ | ✓ | ✓ |

### マルチモーダル入力（Vision）

| 機能 | Anthropic | OpenAI | Gemini |
|------|:---------:|:------:|:------:|
| 画像解析 | ✓ | ✓ | ✓ |
| 音声解析 | - | ✓ | ✓ |
| 動画解析 | - | - | ✓ |

### マルチモーダル生成

| 機能 | Anthropic | OpenAI | Gemini |
|------|:---------:|:------:|:------:|
| 画像生成 | - | ✓ DALL-E, GPT-Image | ✓ Imagen 4 |
| 音声生成 | - | ✓ TTS-1, TTS-1-HD | - |
| 動画生成 | - | ✓ Sora 2 | ✓ Veo 2.0-3.1 |

## 対応プロバイダー

| プロバイダー | クライアント | モデル例 |
|-------------|-------------|---------|
| Anthropic | `AnthropicClient` | `.sonnet`, `.opus`, `.haiku` |
| OpenAI | `OpenAIClient` | `.gpt4o`, `.gpt4oMini`, `.o1`, `.o3Mini` |
| Google | `GeminiClient` | `.flash3`, `.pro25`, `.flash25` |

## 要件

- iOS 17.0+ / macOS 14.0+ / Linux
- Swift 6.0+
- Xcode 16+

## サンプルアプリ

`Examples/LLMStructuredOutputsExample` に iOS サンプルアプリがあります。

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照

---

Made with ❤️ by [NOPROBLEM](https://github.com/no-problem-dev)
