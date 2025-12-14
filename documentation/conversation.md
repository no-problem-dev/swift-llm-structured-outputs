# 会話

`Conversation` は、型安全な構造化出力を維持しながら、LLM とのマルチターン会話を管理する Actor です。
Actor として実装されているため、並行アクセスに対して安全であり、二重送信も自動的に防止されます。

## 基本的な使い方

### 会話の作成

```swift
import LLMStructuredOutputs

let client = AnthropicClient(apiKey: "sk-ant-...")

let conversation = Conversation(
    client: client,
    model: .sonnet,
    systemPrompt: "あなたは親切な料理アシスタントです"
)
```

### メッセージの送信

`send` メソッドを使用してメッセージを送信し、構造化されたレスポンスを受け取ります:

```swift
@Structured("レシピ情報")
struct Recipe {
    @StructuredField("レシピ名")
    var name: String

    @StructuredField("材料リスト")
    var ingredients: [String]

    @StructuredField("調理手順")
    var instructions: [String]
}

// 最初のメッセージ
let recipe: Recipe = try await conversation.send("カルボナーラの作り方を教えて")
print(recipe.name)  // "カルボナーラ"

// フォローアップの質問（コンテキストが維持される）
@Structured("料理のコツ")
struct CookingTips {
    @StructuredField("コツのリスト")
    var tips: [String]
}

let tips: CookingTips = try await conversation.send("初心者向けのコツは？")
```

## 会話の状態

### メッセージの追跡

```swift
// 会話内のすべてのメッセージを取得（Actor なので await が必要）
let messages = await conversation.messages

// ターン数（ユーザー・アシスタントのペア）を取得
let turns = await conversation.turnCount
```

### トークン使用量

```swift
// すべてのターンの合計トークン使用量を追跡（Actor なので await が必要）
let totalUsage = await conversation.totalUsage
print("入力トークン: \(totalUsage.inputTokens)")
print("出力トークン: \(totalUsage.outputTokens)")
print("合計トークン: \(totalUsage.totalTokens)")
```

### 会話のクリア

```swift
// 会話をリセットして最初からやり直す（Actor なので await が必要）
await conversation.clear()
```

## 既存のメッセージで開始

既存のメッセージ履歴で会話を初期化できます:

```swift
let existingMessages: [LLMMessage] = [
    .user("フランスの首都は？"),
    .assistant("{\"name\": \"パリ\", \"country\": \"フランス\"}")
]

let conversation = Conversation(
    client: client,
    model: .sonnet,
    messages: existingMessages
)
```

## 異なる出力型の使用

会話内の各メッセージは異なる構造化型を返すことができます:

```swift
@Structured
struct CityInfo {
    var name: String
    var country: String
}

@Structured
struct PopulationInfo {
    var population: Int
    var year: Int
}

@Structured
struct WeatherInfo {
    var temperature: Double
    var condition: String
}

// 同じ会話で、異なるレスポンス型
let city: CityInfo = try await conversation.send("日本の首都は？")
let population: PopulationInfo = try await conversation.send("その都市の人口は？")
let weather: WeatherInfo = try await conversation.send("今の天気は？")
```

## 低レベル Chat API

より細かい制御が必要な場合は、クライアントの `chat` メソッドを直接使用できます:

```swift
var messages: [LLMMessage] = []

// 最初のターン
messages.append(.user("2 + 2 は？"))
let response1: ChatResponse<MathAnswer> = try await client.chat(
    messages: messages,
    model: .sonnet
)
messages.append(response1.assistantMessage)

// 2番目のターン
messages.append(.user("それを3倍して"))
let response2: ChatResponse<MathAnswer> = try await client.chat(
    messages: messages,
    model: .sonnet
)
```

### ChatResponse のプロパティ

```swift
let response: ChatResponse<MyType> = try await client.chat(...)

// 構造化された結果
let result = response.result

// アシスタントの生メッセージ（履歴に追加用）
let assistantMessage = response.assistantMessage

// このターンのトークン使用量
let usage = response.usage

// レスポンスが終了した理由
let stopReason = response.stopReason

// 使用されたモデル
let model = response.model

// パース前の生テキスト
let rawText = response.rawText
```

## 設定オプション

### Temperature

レスポンスのランダム性を制御:

```swift
let conversation = Conversation(
    client: client,
    model: .sonnet,
    temperature: 0.7  // 0.0 = 確定的、1.0 = 創造的
)
```

### 最大トークン

レスポンスの長さを制限:

```swift
let conversation = Conversation(
    client: client,
    model: .sonnet,
    maxTokens: 500
)
```

## 型安全性

`Conversation` はクライアント型に対してジェネリックであり、モデルの互換性を保証します:

```swift
// Anthropic クライアントを使用 - ClaudeModel のみ許可
let anthropicConv = Conversation(
    client: AnthropicClient(apiKey: "..."),
    model: .sonnet  // ✅ ClaudeModel
)

// OpenAI クライアントを使用 - GPTModel のみ許可
let openaiConv = Conversation(
    client: OpenAIClient(apiKey: "..."),
    model: .gpt4o  // ✅ GPTModel
)

// Gemini クライアントを使用 - GeminiModel のみ許可
let geminiConv = Conversation(
    client: GeminiClient(apiKey: "..."),
    model: .flash25  // ✅ GeminiModel
)
```

## 並行処理

`Conversation` は Actor として実装されており、並行アクセスに対して安全です。
複数の Task から同じ会話インスタンスにアクセスしても、状態の一貫性が保証されます:

```swift
let conversation = Conversation(
    client: client,
    model: .sonnet
)

// 複数の Task から安全にアクセス可能
Task {
    let result: MyType = try await conversation.send("こんにちは")
}

// 二重送信は自動的に防止される（ConversationError.alreadySending がスロー）
```

### 二重送信の防止

同じ会話で複数のリクエストを同時に送信しようとすると、`ConversationError.alreadySending` がスローされます:

```swift
do {
    let result: MyType = try await conversation.send("質問")
} catch ConversationError.alreadySending {
    print("前のリクエストが完了するまで待ってください")
}
```

## イベントストリーム

`eventStream` を使用すると、会話中に発生するイベントを AsyncSequence として購読できます。
メッセージの送受信だけでなく、エラーや会話のクリアなど、すべてのイベントをリアルタイムで監視できます。

### ConversationEvent

会話イベントは以下の種類があります：

| イベント | 説明 |
|----------|------|
| `.userMessage(LLMMessage)` | ユーザーメッセージが送信された |
| `.assistantMessage(LLMMessage)` | アシスタントからの応答を受信した |
| `.error(Error)` | API エラーが発生した |
| `.cleared` | 会話がクリアされた |

### 基本的な使い方

```swift
let conversation = Conversation(
    client: client,
    model: .sonnet
)

// バックグラウンドでイベントを監視
Task {
    for await event in await conversation.eventStream {
        switch event {
        case .userMessage(let message):
            print("👤 User: \(message.content)")
        case .assistantMessage(let message):
            print("🤖 Assistant: \(message.content)")
        case .error(let error):
            print("❌ Error: \(error)")
        case .cleared:
            print("🗑️ Conversation cleared")
        }
    }
}

// メッセージを送信するとイベントが流れる
let result: CityInfo = try await conversation.send("日本の首都は？")
```

### エラーハンドリング

イベントストリームを使用すると、`send` メソッドの `try-catch` とは別に、エラーを監視できます：

```swift
Task {
    for await event in await conversation.eventStream {
        if case .error(let error) = event {
            // エラーをログに記録、UI に表示など
            logger.error("会話エラー: \(error)")
        }
    }
}

// send はエラーをスローするが、ストリームでも同じエラーを受け取れる
do {
    let result: MyType = try await conversation.send("質問")
} catch {
    // エラー処理
}
```

### UI 連携の例

SwiftUI でリアルタイムに会話を表示する例：

```swift
@MainActor
class ConversationViewModel: ObservableObject {
    @Published var events: [ConversationEvent] = []

    private let conversation: Conversation<AnthropicClient>

    init(client: AnthropicClient) {
        self.conversation = Conversation(client: client, model: .sonnet)
        startMonitoring()
    }

    private func startMonitoring() {
        Task {
            for await event in await conversation.eventStream {
                events.append(event)
            }
        }
    }

    func send(_ prompt: String) async throws -> SomeResponse {
        try await conversation.send(prompt)
    }
}
```

### 注意事項

- 1つの `Conversation` につき1つのストリームのみ有効です
- 新しいストリームを作成すると、以前のストリームは自動的に終了します
- ストリームは `send` や `clear` の呼び出しに応じてイベントを発行します

## ベストプラクティス

1. **関連する質問には会話を再利用** - コンテキストを維持
2. **新しいトピックでは会話をクリア** - 不要なコンテキストを削除
3. **トークン使用量を監視** - コスト管理のため
4. **タスクの複雑さに応じたモデルを使用** - 適切なモデル選択
5. **エラーを適切に処理** - do-catch ブロックで

## 次のステップ

- [ツールコール](tool-calling.md) で LLM に外部関数を呼び出させる方法を学ぶ
- [プロバイダー](providers.md) ガイドでプロバイダー固有の詳細を確認
- [はじめに](getting-started.md) で基本的なセットアップを確認
- [API リファレンス](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/) で完全なドキュメントを閲覧
