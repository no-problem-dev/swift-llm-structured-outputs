# ``LLMStructuredOutputs``

Swift LLM クライアント向けの型安全な構造化出力生成ライブラリ。

## 概要

LLMStructuredOutputs は、大規模言語モデルから型安全な構造化出力を生成できる Swift ライブラリです。Swift マクロを使用して、完全なバリデーション制約付きの出力型を定義でき、ライブラリが自動的に JSON Schema を生成し、複数の LLM プロバイダーからのレスポンスを処理します。

### 主な機能

- **型安全な構造化出力** - Swift マクロを使用
- **マルチプロバイダー対応** - Claude (Anthropic)、GPT (OpenAI)、Gemini (Google)
- **ツールコール** - LLM に外部関数を呼び出させる
- **エージェントループ** - ツール実行と構造化出力の自動ループ
- **会話管理** - マルチターンのやり取りに対応
- **完全な Swift Concurrency サポート** - async/await 対応

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
- <doc:PromptBuilding>
- <doc:Providers>
- <doc:Conversations>
- <doc:AgentLoop>
- <doc:AgentLoopInternals>
- <doc:ConversationalAgent>
- <doc:ExampleApp>

### マクロ

- ``Structured(_:)``
- ``StructuredField(_:_:)``
- ``StructuredEnum(_:)``
- ``StructuredCase(_:)``
- ``Tool(_:name:)``
- ``ToolArgument(_:_:)``

### クライアント

- ``AnthropicClient``
- ``OpenAIClient``
- ``GeminiClient``
- ``StructuredLLMClient``

### モデル

- ``ClaudeModel``
- ``GPTModel``
- ``GeminiModel``

### 会話

- ``ConversationHistory``
- ``ConversationHistoryProtocol``
- ``ConversationEvent``
- ``ChatResponse``
- ``LLMMessage``
- ``TokenUsage``
- ``LLMResponse/StopReason``

### スキーマ

- ``JSONSchema``
- ``FieldConstraint``
- ``StructuredProtocol``

### ツール

- ``ToolSet``
- ``ToolChoice``
- ``ToolResult``
- ``ToolCallResponse``

### エージェント

- ``AgentStep``
- ``AgentStepStream``
- ``AgentConfiguration``
- ``AgentContext``
- ``AgentError``
- ``ToolCall``
- ``ToolResponse``

### 会話型エージェント

- ``ConversationalAgentSession``
- ``ConversationalAgentSessionProtocol``
- ``ConversationalAgentStep``
- ``ConversationalAgentStepStream``
- ``ConversationalAgentEvent``
- ``ConversationalAgentError``
- ``AskUserTool``

### エラー

- ``LLMError``
- ``AgentError``
