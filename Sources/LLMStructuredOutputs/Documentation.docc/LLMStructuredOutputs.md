# ``LLMStructuredOutputs``

Swift LLM クライアント向けの型安全な構造化出力生成ライブラリ。

@Metadata {
    @PageColor(blue)
}

## 概要

LLMStructuredOutputs は、大規模言語モデルから型安全な構造化出力を生成できる Swift ライブラリです。Swift マクロを使用して、完全なバリデーション制約付きの出力型を定義でき、ライブラリが自動的に JSON Schema を生成し、複数の LLM プロバイダーからのレスポンスを処理します。

@Row {
    @Column(size: 2) {
        ### 主な機能

        - **型安全な構造化出力** - Swift マクロを使用して出力型を定義
        - **マルチプロバイダー** - Claude、GPT、Gemini に対応
        - **ツールコール** - LLM に外部関数を呼び出させる
        - **エージェントループ** - ツール実行と出力の自動ループ
        - **会話管理** - マルチターンのやり取りに対応
        - **Swift Concurrency** - async/await に完全対応
    }

    @Column {
        ```swift
        @Structured("ユーザー情報")
        struct UserInfo {
            @StructuredField("名前")
            var name: String

            @StructuredField("年齢", .minimum(0))
            var age: Int
        }
        ```
    }
}

## クイックスタート

### 1. 出力型を定義

```swift
import LLMStructuredOutputs

@Structured("ユーザー情報")
struct UserInfo {
    @StructuredField("名前")
    var name: String

    @StructuredField("年齢", .minimum(0))
    var age: Int
}
```

### 2. 構造化出力を生成

@TabNavigator {
    @Tab("Claude") {
        ```swift
        let client = AnthropicClient(apiKey: "sk-ant-...")
        let user: UserInfo = try await client.generate(
            input: "山田太郎さんは30歳です",
            model: .sonnet
        )
        ```
    }

    @Tab("GPT") {
        ```swift
        let client = OpenAIClient(apiKey: "sk-...")
        let user: UserInfo = try await client.generate(
            input: "山田太郎さんは30歳です",
            model: .gpt4o
        )
        ```
    }

    @Tab("Gemini") {
        ```swift
        let client = GeminiClient(apiKey: "...")
        let user: UserInfo = try await client.generate(
            input: "山田太郎さんは30歳です",
            model: .flash
        )
        ```
    }
}

### 3. 結果を使用

```swift
print(user.name)  // "山田太郎"
print(user.age)   // 30
```

## Topics

### はじめに

@Links(visualStyle: detailedGrid) {
    - <doc:GettingStarted>
    - <doc:PromptBuilding>
}

### コアモジュール

- ``/LLMClient``
- ``/LLMTool``
- ``/LLMConversation``
- ``/LLMAgent``
- ``/LLMConversationalAgent``
- ``/LLMDynamicStructured``

### プロバイダーと会話

- <doc:Providers>
- <doc:Conversations>

### エージェント

- <doc:AgentLoop>
- <doc:AgentLoopInternals>
- <doc:ConversationalAgent>

### サンプル

- <doc:ExampleApp>
