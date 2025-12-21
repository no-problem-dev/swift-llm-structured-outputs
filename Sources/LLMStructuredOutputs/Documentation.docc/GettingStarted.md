# はじめに

swift-llm-structured-outputs をプロジェクトに追加して、LLM から構造化出力を生成する方法を学びます。

@Metadata {
    @PageColor(blue)
}

## 概要

このガイドでは、LLMStructuredOutputs の基本的なセットアップと使い方を説明します。

## インストール

`Package.swift` にパッケージを追加:

```swift
dependencies: [
    .package(
        url: "https://github.com/no-problem-dev/swift-llm-structured-outputs.git",
        from: "1.0.0"
    )
]
```

ターゲットの依存関係に `LLMStructuredOutputs` を追加:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "LLMStructuredOutputs", package: "swift-llm-structured-outputs")
    ]
)
```

## 出力型の定義

`@Structured` マクロを使用して、構造化出力として使用できる型を定義:

@Row {
    @Column(size: 2) {
        ```swift
        import LLMStructuredOutputs

        @Structured("書籍情報")
        struct BookInfo {
            @StructuredField("書籍のタイトル")
            var title: String

            @StructuredField("著者名")
            var author: String

            @StructuredField("出版年", .minimum(1000), .maximum(2100))
            var year: Int

            @StructuredField("ジャンル")
            var genres: [String]
        }
        ```
    }

    @Column {
        ### ポイント

        - `@Structured` でクラスまたは構造体をマーク
        - `@StructuredField` で各フィールドに説明を追加
        - 制約（`.minimum`, `.maximum` など）でバリデーション
        - 配列型もサポート
    }
}

## クライアントの作成

使用する LLM プロバイダーに応じてクライアントを選択:

@TabNavigator {
    @Tab("Anthropic Claude") {
        ```swift
        import LLMStructuredOutputs

        let client = AnthropicClient(apiKey: "sk-ant-...")
        ```

        **対応モデル**: Sonnet, Haiku, Opus
    }

    @Tab("OpenAI GPT") {
        ```swift
        import LLMStructuredOutputs

        let client = OpenAIClient(apiKey: "sk-...")
        ```

        **対応モデル**: GPT-4o, GPT-4o-mini, o1, o1-mini
    }

    @Tab("Google Gemini") {
        ```swift
        import LLMStructuredOutputs

        let client = GeminiClient(apiKey: "...")
        ```

        **対応モデル**: Flash, Pro
    }
}

## 出力の生成

プロンプトを指定して `generate` メソッドを呼び出す:

```swift
let book: BookInfo = try await client.generate(
    input: "ジョージ・オーウェルの1984年について教えて",
    model: .sonnet
)

print(book.title)   // "1984年"
print(book.author)  // "ジョージ・オーウェル"
print(book.year)    // 1949
print(book.genres)  // ["ディストピア", "SF", "政治小説"]
```

## 制約の使用

LLM の出力を検証するための制約を追加:

@Row {
    @Column {
        ### 文字列の制約

        ```swift
        @StructuredField("商品名",
            .minLength(1),
            .maxLength(100))
        var name: String

        @StructuredField("メール",
            .pattern("^[\\w.-]+@[\\w.-]+$"))
        var email: String
        ```
    }

    @Column {
        ### 数値の制約

        ```swift
        @StructuredField("価格（円）",
            .minimum(0))
        var price: Int

        @StructuredField("在庫数",
            .minimum(0),
            .maximum(10000))
        var stock: Int
        ```
    }

    @Column {
        ### 配列の制約

        ```swift
        @StructuredField("タグ",
            .minItems(1),
            .maxItems(10))
        var tags: [String]
        ```
    }
}

## 列挙型の使用

固定の選択肢には `@StructuredEnum` を使用:

```swift
@StructuredEnum("感情分析結果")
enum Sentiment: String {
    @StructuredCase("ポジティブな感情を表現")
    case positive

    @StructuredCase("中立的な内容")
    case neutral

    @StructuredCase("ネガティブな感情を表現")
    case negative
}

@Structured("分析結果")
struct Analysis {
    @StructuredField("全体的な感情")
    var sentiment: Sentiment

    @StructuredField("確信度スコア", .minimum(0), .maximum(100))
    var confidence: Int
}
```

## エラーハンドリング

エラーを適切に処理:

```swift
do {
    let result: BookInfo = try await client.generate(
        input: "...",
        model: .sonnet
    )
    // 成功
} catch let error as LLMError {
    switch error {
    case .apiError(let message):
        print("APIエラー: \(message)")
    case .decodingError(let message):
        print("デコードに失敗: \(message)")
    case .invalidResponse:
        print("無効なレスポンス")
    case .networkError(let underlying):
        print("ネットワークエラー: \(underlying)")
    default:
        print("その他のエラー: \(error)")
    }
}
```

## 次のステップ

@Links(visualStyle: detailedGrid) {
    - <doc:Providers>
    - <doc:Conversations>
}
