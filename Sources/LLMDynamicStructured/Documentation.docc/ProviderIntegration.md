# プロバイダー連携

DynamicStructured を各 LLM プロバイダーで使用する方法を学びます。

@Metadata {
    @PageColor(purple)
}

## 概要

LLMDynamicStructured は、Claude (Anthropic)、GPT (OpenAI)、Gemini (Google) の3つのプロバイダーすべてで動作します。各プロバイダーは統一された API を提供しており、同じスキーマ定義を使い回すことができます。

## プロバイダー別の使用方法

@TabNavigator {
    @Tab("Claude (Anthropic)") {
        ### セットアップ

        ```swift
        import LLMDynamicStructured

        let client = AnthropicClient(apiKey: "sk-ant-...")
        ```

        ### 基本的な生成

        ```swift
        let result = try await client.generate(
            input: "田中太郎さん（35歳）の情報を抽出",
            model: .sonnet,
            output: userInfo
        )
        ```

        ### オプションの指定

        ```swift
        let result = try await client.generate(
            input: "...",
            model: .sonnet,
            output: userInfo,
            systemPrompt: "あなたは情報抽出の専門家です。",
            temperature: 0.7,
            maxTokens: 1024
        )
        ```

        ### 会話履歴を使用

        ```swift
        let result = try await client.generate(
            messages: [
                .user("これはテストメッセージです"),
                .assistant("了解しました"),
                .user("田中太郎さんの情報を教えて")
            ],
            model: .sonnet,
            output: userInfo
        )
        ```
    }

    @Tab("GPT (OpenAI)") {
        ### セットアップ

        ```swift
        import LLMDynamicStructured

        let client = OpenAIClient(apiKey: "sk-...")
        ```

        ### 基本的な生成

        ```swift
        let result = try await client.generate(
            input: "田中太郎さん（35歳）の情報を抽出",
            model: .gpt4o,
            output: userInfo
        )
        ```

        ### オプションの指定

        ```swift
        let result = try await client.generate(
            input: "...",
            model: .gpt4oMini,
            output: userInfo,
            systemPrompt: "あなたは情報抽出の専門家です。",
            temperature: 0.7,
            maxTokens: 1024
        )
        ```

        ### 会話履歴を使用

        ```swift
        let result = try await client.generate(
            messages: [
                .user("これはテストメッセージです"),
                .assistant("了解しました"),
                .user("田中太郎さんの情報を教えて")
            ],
            model: .gpt4o,
            output: userInfo
        )
        ```
    }

    @Tab("Gemini (Google)") {
        ### セットアップ

        ```swift
        import LLMDynamicStructured

        let client = GeminiClient(apiKey: "...")
        ```

        ### 基本的な生成

        ```swift
        let result = try await client.generate(
            input: "田中太郎さん（35歳）の情報を抽出",
            model: .flash,
            output: userInfo
        )
        ```

        ### オプションの指定

        ```swift
        let result = try await client.generate(
            input: "...",
            model: .pro,
            output: userInfo,
            systemPrompt: "あなたは情報抽出の専門家です。",
            temperature: 0.7,
            maxTokens: 1024
        )
        ```

        ### 会話履歴を使用

        ```swift
        let result = try await client.generate(
            messages: [
                .user("これはテストメッセージです"),
                .assistant("了解しました"),
                .user("田中太郎さんの情報を教えて")
            ],
            model: .flash,
            output: userInfo
        )
        ```
    }
}

## 結果へのアクセス

`DynamicStructuredResult` は、生成された構造化データにアクセスするための型安全なメソッドを提供します。

### 型安全なアクセサ

@Row {
    @Column {
        **プリミティブ型**

        ```swift
        // 文字列
        let name = result.string("name")

        // 整数
        let age = result.int("age")

        // 浮動小数点数
        let price = result.double("price")

        // 真偽値
        let isActive = result.bool("isActive")
        ```
    }

    @Column {
        **配列型**

        ```swift
        // 文字列配列
        let tags = result.stringArray("tags")

        // 整数配列
        let scores = result.intArray("scores")

        // ネストされたオブジェクト
        let address = result.nested("address")
        let city = address?.string("city")

        // オブジェクト配列
        let items = result.nestedArray("items")
        ```
    }
}

### subscript アクセス

```swift
// Any? 型で取得
let rawValue = result["fieldName"]

// キーの存在確認
if result.hasKey("optionalField") {
    // ...
}

// すべてのキーを取得
let allKeys = result.keys

// 生の辞書として取得
let rawDict = result.rawValues
```

## エラーハンドリング

```swift
do {
    let result = try await client.generate(
        input: "...",
        model: .sonnet,
        output: userInfo
    )
    // 成功
} catch let error as LLMError {
    switch error {
    case .apiError(let message):
        print("API エラー: \(message)")
    case .decodingError(let message):
        print("デコードエラー: \(message)")
    case .emptyResponse:
        print("空のレスポンス")
    case .networkError(let underlying):
        print("ネットワークエラー: \(underlying)")
    default:
        print("その他のエラー: \(error)")
    }
} catch let error as DynamicStructuredResultError {
    switch error {
    case .invalidJSON:
        print("無効な JSON")
    case .invalidEncoding:
        print("無効なエンコーディング")
    }
}
```

## マルチプロバイダー対応

同じスキーマを複数のプロバイダーで使用するパターン:

```swift
protocol DynamicStructuredProvider {
    func generate(
        input: LLMInput,
        output: DynamicStructured
    ) async throws -> DynamicStructuredResult
}

struct MultiProviderClient {
    private let anthropic: AnthropicClient
    private let openai: OpenAIClient
    private let gemini: GeminiClient

    enum Provider {
        case claude(ClaudeModel)
        case gpt(GPTModel)
        case gemini(GeminiModel)
    }

    func generate(
        input: LLMInput,
        provider: Provider,
        output: DynamicStructured
    ) async throws -> DynamicStructuredResult {
        switch provider {
        case .claude(let model):
            return try await anthropic.generate(
                input: input,
                model: model,
                output: output
            )
        case .gpt(let model):
            return try await openai.generate(
                input: input,
                model: model,
                output: output
            )
        case .gemini(let model):
            return try await gemini.generate(
                input: input,
                model: model,
                output: output
            )
        }
    }
}
```

## ベストプラクティス

### 1. スキーマの再利用

```swift
// 共通スキーマを定義
let userSchema = DynamicStructured("User") {
    JSONSchema.string(description: "名前").named("name")
    JSONSchema.integer(description: "年齢").named("age")
}

// 複数のリクエストで再利用
let result1 = try await client.generate(input: "...", model: .sonnet, output: userSchema)
let result2 = try await client.generate(input: "...", model: .sonnet, output: userSchema)
```

### 2. 適切なモデル選択

| 用途 | 推奨モデル |
|------|-----------|
| 高精度が必要 | Claude Sonnet, GPT-4o, Gemini Pro |
| 高速処理 | Claude Haiku, GPT-4o-mini, Gemini Flash |
| コスト重視 | Claude Haiku, GPT-4o-mini, Gemini Flash |

### 3. 温度設定

- **0.0 - 0.3**: 一貫性のある出力（データ抽出向け）
- **0.4 - 0.7**: バランスの取れた出力
- **0.8 - 1.0**: 創造的な出力

```swift
// データ抽出には低温度を推奨
let result = try await client.generate(
    input: "...",
    model: .sonnet,
    output: schema,
    temperature: 0.1
)
```
