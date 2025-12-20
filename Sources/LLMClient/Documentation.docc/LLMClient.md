# ``LLMClient``

Claude、GPT、Gemini に対応したマルチプロバイダー LLM クライアント。

@Metadata {
    @PageColor(blue)
}

## 概要

LLMClient は、主要な LLM プロバイダーへの統一されたインターフェースを提供するコアモジュールです。構造化出力の生成、プロンプト構築、自動リトライ、スキーマ管理など、LLM アプリケーション開発に必要な基盤機能をすべて備えています。

@Row {
    @Column(size: 2) {
        ### 主な機能

        - **マルチプロバイダー** - Claude、GPT、Gemini を同じ API で利用
        - **構造化出力** - `@Structured` マクロで型安全な出力を定義
        - **Prompt DSL** - 宣言的にプロンプトを構築
        - **自動リトライ** - レート制限・サーバーエラーの自動リトライ
        - **スキーマ変換** - 各プロバイダーに最適化されたスキーマ変換
    }

    @Column {
        ```swift
        let client = AnthropicClient(
            apiKey: "sk-ant-..."
        )

        let result: UserInfo = try await client.generate(
            prompt: "山田太郎さん、35歳",
            model: .sonnet
        )
        ```
    }
}

## プロバイダー

@Links(visualStyle: detailedGrid) {
    - ``AnthropicClient``
    - ``OpenAIClient``
    - ``GeminiClient``
}

### AnthropicClient

Claude モデル（Opus、Sonnet、Haiku）を使用します。構造化出力に最適化されており、高品質な結果を得られます。

```swift
let client = AnthropicClient(apiKey: "sk-ant-...")

// モデル選択
let result: Analysis = try await client.generate(
    prompt: "この文章を分析して",
    model: .sonnet  // .opus, .haiku も選択可能
)
```

### OpenAIClient

GPT モデル（GPT-4o、o1、o3-mini 等）を使用します。Structured Outputs API を活用した高精度な出力を生成します。

```swift
let client = OpenAIClient(apiKey: "sk-...")

let result: Summary = try await client.generate(
    prompt: "要約してください",
    model: .gpt4o  // .o1, .o3Mini も選択可能
)
```

### GeminiClient

Gemini モデル（Pro、Flash、Flash-Lite）を使用します。高速な推論と柔軟な出力形式に対応しています。

```swift
let client = GeminiClient(apiKey: "...")

let result: Report = try await client.generate(
    prompt: "レポートを生成",
    model: .flash  // .pro, .flashLite も選択可能
)
```

## Prompt DSL

宣言的な構文でプロンプトを構築できます。

```swift
let prompt = Prompt {
    "あなたは専門的なアシスタントです。"

    Section("タスク") {
        "以下のテキストを分析してください。"
    }

    Section("制約") {
        "- 簡潔に回答する"
        "- 具体例を含める"
    }

    ConstraintsSection(for: Analysis.self)
}

let result: Analysis = try await client.generate(
    prompt: prompt,
    model: .sonnet
)
```

## 自動リトライ

レート制限（429）やサーバーエラー（5xx）を自動でリトライします。

```swift
// カスタムリトライ設定
let client = AnthropicClient(
    apiKey: "sk-ant-...",
    retryConfiguration: .aggressive,  // .default, .conservative, .disabled
    retryEventHandler: { event in
        print("リトライ: \(event)")
    }
)
```

## Topics

### クライアント

- ``AnthropicClient``
- ``OpenAIClient``
- ``GeminiClient``
- ``StructuredLLMClient``

### モデル

- ``ClaudeModel``
- ``GPTModel``
- ``GeminiModel``
- ``LLMModelIdentifier``

### プロンプト

- ``Prompt``
- ``PromptComponent``
- ``Section``
- ``ConstraintsSection``

### スキーマ

- ``JSONSchema``
- ``StructuredProtocol``
- ``FieldConstraint``

### リトライ

- ``RetryConfiguration``
- ``RetryPolicy``
- ``RetryEventHandler``
- ``RetryEvent``

### レスポンス

- ``LLMResponse``
- ``LLMMessage``
- ``TokenUsage``
- ``LLMError``
