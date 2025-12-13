# ``LLMStructuredOutputs``

Swift LLM クライアント向けの型安全な構造化出力生成ライブラリ。

## 概要

LLMStructuredOutputs は、大規模言語モデルから型安全な構造化出力を生成できる Swift ライブラリです。Swift マクロを使用して、完全なバリデーション制約付きの出力型を定義でき、ライブラリが自動的に JSON Schema を生成し、複数の LLM プロバイダーからのレスポンスを処理します。

### 主な機能

- **型安全な構造化出力** - Swift マクロを使用
- **マルチプロバイダー対応** - Claude (Anthropic)、GPT (OpenAI)、Gemini (Google)
- **会話管理** - マルチターンのやり取りに対応
- **完全な Swift Concurrency サポート** - async/await 対応
- **ゼロ依存** - swift-syntax のみ使用

## クイックスタート

出力型を定義:

```swift
@Structured("ユーザー情報")
struct UserInfo {
    @StructuredField("名前")
    var name: String

    @StructuredField("年齢", .minimum(0))
    var age: Int
}
```

構造化出力を生成:

```swift
let client = AnthropicClient(apiKey: "sk-ant-...")
let user: UserInfo = try await client.generate(
    prompt: "山田太郎さんは30歳です",
    model: .sonnet
)
```

## Topics

### 基本

- <doc:GettingStarted>
- <doc:Providers>
- <doc:Conversations>

### マクロ

- ``Structured(_:)``
- ``StructuredField(_:_:)``
- ``StructuredEnum(_:)``
- ``StructuredCase(_:)``

### クライアント

- ``AnthropicClient``
- ``OpenAIClient``
- ``GeminiClient``
- ``StructuredLLMClient``

### モデル

- ``ClaudeModel``
- ``GPTModel``
- ``GeminiModel``
- ``LLMModel``

### 会話

- ``Conversation``
- ``ChatResponse``
- ``LLMMessage``
- ``TokenUsage``
- ``StopReason``

### スキーマ

- ``JSONSchema``
- ``FieldConstraint``
- ``StructuredProtocol``

### エラー

- ``LLMError``
