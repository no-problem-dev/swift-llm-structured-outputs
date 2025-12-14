# はじめに

swift-llm-structured-outputs をプロジェクトに追加して、構造化出力の生成を開始するためのガイドです。

## インストール

`Package.swift` にパッケージを追加します:

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-llm-structured-outputs.git", from: "1.0.0")
]
```

ターゲットの依存関係に `LLMStructuredOutputs` を追加します:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "LLMStructuredOutputs", package: "swift-llm-structured-outputs")
    ]
)
```

## 基本的な使い方

### 1. 出力型を定義する

`@Structured` マクロを使用して、構造化出力として使用できる型を定義します:

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

### 2. クライアントを作成する

使用する LLM プロバイダーに応じてクライアントを選択します:

```swift
// Anthropic Claude
let anthropic = AnthropicClient(apiKey: "sk-ant-...")

// OpenAI GPT
let openai = OpenAIClient(apiKey: "sk-...")

// Google Gemini
let gemini = GeminiClient(apiKey: "...")
```

### 3. 構造化出力を生成する

`generate` メソッドを呼び出して構造化出力を取得します:

```swift
let book: BookInfo = try await anthropic.generate(
    prompt: "ジョージ・オーウェルの1984年について教えて",
    model: .sonnet
)

print(book.title)   // "1984年"
print(book.author)  // "ジョージ・オーウェル"
print(book.year)    // 1949
```

## 制約の追加

LLM の出力を検証するための制約を追加できます:

```swift
@Structured("商品情報")
struct Product {
    @StructuredField("商品名", .minLength(1), .maxLength(100))
    var name: String

    @StructuredField("価格（円）", .minimum(0))
    var price: Int

    @StructuredField("在庫数", .minimum(0), .maximum(10000))
    var stock: Int

    @StructuredField("タグ", .minItems(1), .maxItems(10))
    var tags: [String]
}
```

## 列挙型の使用

固定の選択肢には `@StructuredEnum` を使用します:

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

エラーを適切に処理します:

```swift
do {
    let result: BookInfo = try await client.generate(
        prompt: "...",
        model: .sonnet
    )
} catch let error as LLMError {
    switch error {
    case .apiError(let message):
        print("APIエラー: \(message)")
    case .decodingError(let message):
        print("デコードエラー: \(message)")
    case .invalidResponse:
        print("無効なレスポンス")
    case .networkError(let underlying):
        print("ネットワークエラー: \(underlying)")
    }
}
```

## 次のステップ

- [プロンプト構築](prompt-building.md) で構造化プロンプトの作成方法を学ぶ
- [プロバイダー](providers.md) で各プロバイダーとモデルについて学ぶ
- [会話](conversation.md) でマルチターン会話を実装する
