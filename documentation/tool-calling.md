# ツールコール

LLM にどのツール（関数）を呼び出すべきか判断させる機能です。天気の取得、計算の実行、データベースへのアクセスなど、LLM 単体では実行できない処理について、どのツールをどの引数で呼ぶべきかを LLM に計画させることができます。

> **注意**: `planToolCalls` はツールの選択と引数の決定のみを行います。実際のツール実行は開発者が行う必要があります。

## 基本的な使い方

### 1. ツールを定義する

`@Tool` マクロを使用してツールを定義します:

```swift
import LLMStructuredOutputs

@Tool("指定された都市の天気を取得します")
struct GetWeather {
    @ToolArgument("天気を取得する都市名")
    var location: String

    @ToolArgument("温度の単位（celsius または fahrenheit）")
    var unit: String?

    func call() async throws -> String {
        // 実際の天気 API を呼び出す
        return "\(location): 晴れ、25°C"
    }
}
```

### 2. ツールセットを作成する

`ToolSet` の Result Builder でツールを登録します:

```swift
let tools = ToolSet {
    GetWeather.self
}
```

### 3. ツール呼び出しを計画する

`planToolCalls` メソッドでリクエストを送信します。LLM がどのツールを呼ぶべきか判断して返します:

```swift
let client = AnthropicClient(apiKey: "sk-ant-...")

let plan = try await client.planToolCalls(
    prompt: "東京の天気を教えて",
    model: .sonnet,
    tools: tools
)
```

### 4. 計画されたツール呼び出しを実行する

レスポンスからツール呼び出し計画を取得し、実行します:

```swift
for call in plan.toolCalls {
    let result = try await tools.execute(toolNamed: call.name, with: call.arguments)
    print(result.stringValue)  // "東京: 晴れ、25°C"
}
```

## ツールの定義

### @Tool マクロ

ツールには説明が必須です。LLM はこの説明を参考にツールを選択します:

```swift
@Tool("説明文")
struct ToolName {
    // 引数とcall()メソッド
}
```

カスタムのツール名を指定することもできます:

```swift
@Tool("現在時刻を取得します", name: "get_current_time")
struct CurrentTime {
    func call() async throws -> String {
        return ISO8601DateFormatter().string(from: Date())
    }
}
```

### @ToolArgument マクロ

各引数には説明を付けます。オプショナル型は必須ではない引数になります:

```swift
@Tool("計算を実行します")
struct Calculator {
    @ToolArgument("計算する数式")
    var expression: String

    @ToolArgument("小数点以下の桁数")
    var precision: Int?

    func call() async throws -> String {
        // 計算処理
    }
}
```

### 戻り値の型

`call()` メソッドは `ToolResultConvertible` に準拠した型を返します:

```swift
// String を返す（最も一般的）
func call() async throws -> String {
    return "結果"
}

// 数値を返す
func call() async throws -> Int {
    return 42
}

// ToolResult を直接返す
func call() async throws -> ToolResult {
    return .text("テキスト結果")
}

// 構造化データを返す
func call() async throws -> ToolResult {
    let data = MyData(value: 100)
    return try ToolResult.encoded(data)
}
```

## ToolSet

### 複数ツールの登録

```swift
let tools = ToolSet {
    GetWeather.self
    Calculator.self
    CurrentTime.self
}
```

### 条件付き登録

```swift
let tools = ToolSet {
    GetWeather.self

    if needsCalculator {
        Calculator.self
    }

    for tool in additionalTools {
        tool
    }
}
```

### ツールセットの結合

```swift
let baseTools = ToolSet {
    GetWeather.self
}

// 演算子で追加
let extended = baseTools + Calculator.self

// メソッドで追加
let extended = baseTools.appending(Calculator.self)

// ToolSet 同士の結合
let combined = baseTools + otherTools
```

### ツールの検索

```swift
// ツール名のリスト
let names = tools.toolNames  // ["get_weather", "calculator"]

// 名前でツール型を検索
if let toolType = tools.toolType(named: "get_weather") {
    // ツール型を使用
}
```

## ToolChoice

LLM がツールを選択するかどうかを制御します:

```swift
// 自動選択（デフォルト）- LLM が必要に応じてツールを選択
let plan = try await client.planToolCalls(
    prompt: "...",
    model: .sonnet,
    tools: tools,
    toolChoice: .auto
)

// 必須 - 必ずいずれかのツールを選択させる
let plan = try await client.planToolCalls(
    prompt: "...",
    model: .sonnet,
    tools: tools,
    toolChoice: .required
)

// 特定ツール指定 - 指定したツールを必ず選択させる
let plan = try await client.planToolCalls(
    prompt: "...",
    model: .sonnet,
    tools: tools,
    toolChoice: .tool("get_weather")
)

// 無効 - ツールを選択させない
let plan = try await client.planToolCalls(
    prompt: "...",
    model: .sonnet,
    tools: tools,
    toolChoice: .none
)
```

## ToolCallResponse

`planToolCalls` が返すレスポンスです。LLM がどのツールをどの引数で呼ぶべきか判断した結果が含まれます。

### プロパティ

```swift
let plan = try await client.planToolCalls(...)

// ツール呼び出し計画のリスト
let calls = plan.toolCalls

// ツール呼び出しがあるかどうか
if plan.hasToolCalls {
    // 処理
}

// テキスト応答（ある場合）
if let text = plan.text {
    print(text)
}

// トークン使用量
let usage = plan.usage

// 停止理由
let stopReason = plan.stopReason

// 使用されたモデル
let model = plan.model
```

### ToolCall

```swift
for call in plan.toolCalls {
    // ツール呼び出しID
    let id = call.id

    // ツール名
    let name = call.name

    // 引数データ（JSON形式）
    let arguments = call.arguments

    // 引数を辞書形式で取得
    let dict = try call.argumentsDictionary()

    // 引数を特定の型にデコード
    let args = try call.decodeArguments(as: MyArgs.self)
}
```

## ToolResult

ツール実行の結果を表す列挙型です:

```swift
public enum ToolResult {
    case text(String)     // テキスト形式の結果
    case json(Data)       // JSON エンコードされた構造化データ
    case error(String)    // エラーメッセージ
}
```

### プロパティ

```swift
let result = try await tools.execute(toolNamed: name, with: arguments)

// 文字列として取得
let text = result.stringValue

// エラーかどうか
if result.isError {
    // エラー処理
}
```

## 会話履歴を含むリクエスト

`messages` パラメータを使用して会話履歴を渡せます:

```swift
var messages: [LLMMessage] = []

// ユーザーメッセージを追加
messages.append(.user("東京の天気を教えて"))

// ツール呼び出しを計画
let plan = try await client.planToolCalls(
    messages: messages,
    model: .sonnet,
    tools: tools
)

// ツール結果を会話に追加して続行...
```

## planToolCalls のパラメータ

```swift
public func planToolCalls(
    prompt: String,              // ユーザープロンプト
    model: ClaudeModel,          // 使用するモデル
    tools: ToolSet,              // 使用可能なツール
    toolChoice: ToolChoice?,     // ツール選択オプション（デフォルト: nil = auto）
    systemPrompt: String?,       // システムプロンプト
    temperature: Double?,        // 温度パラメータ
    maxTokens: Int?              // 最大トークン数
) async throws -> ToolCallResponse
```

## エラーハンドリング

```swift
do {
    let plan = try await client.planToolCalls(...)

    for call in plan.toolCalls {
        do {
            let result = try await tools.execute(toolNamed: call.name, with: call.arguments)
            if result.isError {
                print("ツールエラー: \(result.stringValue)")
            } else {
                print("結果: \(result.stringValue)")
            }
        } catch ToolExecutionError.toolNotFound(let name) {
            print("ツールが見つかりません: \(name)")
        }
    }
} catch let error as LLMError {
    // API エラー処理
}
```

## 完全な使用例

```swift
import LLMStructuredOutputs

// ツールを定義
@Tool("指定された都市の天気を取得します")
struct GetWeather {
    @ToolArgument("都市名")
    var location: String

    func call() async throws -> String {
        // 実際の天気 API 呼び出し
        return "\(location): 晴れ、22°C"
    }
}

@Tool("数式を計算します")
struct Calculator {
    @ToolArgument("計算式")
    var expression: String

    func call() async throws -> String {
        let expr = NSExpression(format: expression)
        if let result = expr.expressionValue(with: nil, context: nil) as? NSNumber {
            return "\(expression) = \(result)"
        }
        return "計算できません"
    }
}

// ツールセットを作成
let tools = ToolSet {
    GetWeather.self
    Calculator.self
}

// クライアントを作成
let client = AnthropicClient(apiKey: "sk-ant-...")

// LLM にどのツールを呼ぶべきか計画させる
let plan = try await client.planToolCalls(
    prompt: "東京の天気と、100 * 5 + 50 の計算結果を教えて",
    model: .sonnet,
    tools: tools,
    toolChoice: .auto
)

// 計画されたツール呼び出しを実行
for call in plan.toolCalls {
    let result = try await tools.execute(toolNamed: call.name, with: call.arguments)
    print("[\(call.name)] \(result.stringValue)")
}
```

## 次のステップ

- [はじめに](getting-started.md) で基本的なセットアップを確認
- [プロバイダー](providers.md) で各プロバイダーとモデルの詳細を確認
- [会話](conversation.md) でマルチターン会話の実装を学ぶ
