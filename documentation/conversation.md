# 会話

`ConversationHistory` は、LLM とのマルチターン会話を管理する Actor です。
履歴はクライアントやモデルから独立しており、異なるプロバイダー間で同じ会話を継続できます。

## 基本的な使い方

### 会話の作成と実行

```swift
import LLMStructuredOutputs

// 履歴を作成
let history = ConversationHistory()

// クライアントを作成
let client = AnthropicClient(apiKey: "sk-ant-...")

// 構造化出力の定義
@Structured("レシピ情報")
struct Recipe {
    @StructuredField("レシピ名")
    var name: String

    @StructuredField("材料リスト")
    var ingredients: [String]

    @StructuredField("調理手順")
    var instructions: [String]
}

// メッセージを送信
let recipe: Recipe = try await client.chat(
    "カルボナーラの作り方を教えて",
    history: history,
    model: .sonnet,
    systemPrompt: "あなたは親切な料理アシスタントです"
)

print(recipe.name)  // "カルボナーラ"
```

### コンテキストを維持した会話

履歴を使い回すことで、コンテキストが維持されます：

```swift
// 最初の質問
let city: CityInfo = try await client.chat(
    "日本の首都は？",
    history: history,
    model: .sonnet
)

// フォローアップ（「その都市」が東京を指すことをLLMが理解）
let population: PopulationInfo = try await client.chat(
    "その都市の人口は？",
    history: history,
    model: .sonnet
)
```

## 異なるプロバイダー間での継続

履歴はクライアントから独立しているため、途中でプロバイダーを切り替えられます：

```swift
let history = ConversationHistory()

// Claude で会話開始
let claude = AnthropicClient(apiKey: "...")
let city: CityInfo = try await claude.chat(
    "日本の首都は？",
    history: history,
    model: .sonnet
)

// 同じ履歴で GPT に切り替え
let openai = OpenAIClient(apiKey: "...")
let population: PopulationInfo = try await openai.chat(
    "その都市の人口は？",
    history: history,
    model: .gpt4o
)

// さらに Gemini に切り替え
let gemini = GeminiClient(apiKey: "...")
let weather: WeatherInfo = try await gemini.chat(
    "今の天気は？",
    history: history,
    model: .flash25
)
```

## 会話の状態

### メッセージ履歴とターン数

```swift
// メッセージ履歴を取得
let messages = await history.getMessages()

// ターン数（ユーザー・アシスタントのペア）
let turns = await history.turnCount
```

### トークン使用量

```swift
// 累計トークン使用量
let usage = await history.getTotalUsage()
print("入力: \(usage.inputTokens)")
print("出力: \(usage.outputTokens)")
print("合計: \(usage.totalTokens)")
```

### 会話のクリア

```swift
// 履歴をリセット
await history.clear()
```

## 既存のメッセージで開始

既存のメッセージ履歴から会話を再開できます：

```swift
let existingMessages: [LLMMessage] = [
    .user("フランスの首都は？"),
    .assistant("{\"name\": \"パリ\", \"country\": \"フランス\"}")
]

let history = ConversationHistory(messages: existingMessages)

// 会話を継続
let population: PopulationInfo = try await client.chat(
    "その都市の人口は？",
    history: history,
    model: .sonnet
)
```

## Prompt DSL との組み合わせ

構造化された `Prompt` をシステムプロンプトとして使用できます：

```swift
let systemPrompt = Prompt {
    PromptComponent.role("データ分析の専門家")
    PromptComponent.objective("ユーザーの入力から構造化データを抽出する")
    PromptComponent.instruction("会話の文脈を理解し、前の回答を踏まえた応答をする")
}

let result: AnalysisResult = try await client.chat(
    "売上データを分析して",
    history: history,
    model: .sonnet,
    systemPrompt: systemPrompt
)
```

## イベントストリーム

`eventStream` を使用すると、会話中のイベントをリアルタイムで監視できます。

### ConversationEvent

| イベント | 説明 |
|----------|------|
| `.userMessage(LLMMessage)` | ユーザーメッセージが追加された |
| `.assistantMessage(LLMMessage)` | アシスタント応答が追加された |
| `.usageUpdated(TokenUsage)` | トークン使用量が更新された |
| `.cleared` | 履歴がクリアされた |
| `.error(LLMError)` | API呼び出しでエラーが発生した |

### 基本的な使い方

```swift
let history = ConversationHistory()

// イベントを監視
Task {
    for await event in history.eventStream {
        switch event {
        case .userMessage(let message):
            print("👤 User: \(message.content)")
        case .assistantMessage(let message):
            print("🤖 Assistant: \(message.content)")
        case .usageUpdated(let usage):
            print("📊 Tokens: \(usage.totalTokens)")
        case .cleared:
            print("🗑️ History cleared")
        case .error(let error):
            print("❌ Error: \(error.localizedDescription)")
        }
    }
}

// メッセージを送信するとイベントが発行される
let result: CityInfo = try await client.chat(
    "日本の首都は？",
    history: history,
    model: .sonnet
)
```

### SwiftUI での使用例

```swift
struct ConversationView: View {
    @State private var history = ConversationHistory()
    @State private var messages: [DisplayMessage] = []
    @State private var totalTokens = 0

    var body: some View {
        VStack {
            // メッセージ表示
            List(messages) { message in
                MessageRow(message: message)
            }

            // トークン表示
            Text("使用トークン: \(totalTokens)")
        }
        .task {
            await subscribeToEvents()
        }
    }

    @MainActor
    private func subscribeToEvents() async {
        for await event in history.eventStream {
            switch event {
            case .userMessage(let msg):
                messages.append(DisplayMessage(role: .user, content: msg.content))
            case .assistantMessage(let msg):
                messages.append(DisplayMessage(role: .assistant, content: msg.content))
            case .usageUpdated(let usage):
                totalTokens = usage.totalTokens
            case .cleared:
                messages = []
                totalTokens = 0
            case .error(let error):
                // エラー発生時の処理（UIにエラー表示など）
                print("Error: \(error.localizedDescription)")
            }
        }
    }
}
```

## 設定オプション

### Temperature

```swift
let result: Recipe = try await client.chat(
    "創作料理を提案して",
    history: history,
    model: .sonnet,
    temperature: 0.8  // 0.0 = 確定的、1.0 = 創造的
)
```

### 最大トークン

```swift
let result: Summary = try await client.chat(
    "この文章を要約して",
    history: history,
    model: .sonnet,
    maxTokens: 500
)
```

## ベストプラクティス

1. **関連する質問には同じ履歴を使用** - コンテキストを維持
2. **新しいトピックでは履歴をクリア** - 不要なコンテキストを削除
3. **トークン使用量を監視** - コスト管理のため
4. **イベントストリームで UI を更新** - リアルタイムなフィードバック

## 次のステップ

- [ツールコール](tool-calling.md) で LLM に外部関数を呼び出させる
- [エージェントループ](agent-loop.md) でツール自動実行と構造化出力を確認
- [会話型エージェント](conversational-agent.md) でマルチターン対応のエージェントを確認
- [プロバイダー](providers.md) でプロバイダー固有の詳細を確認
