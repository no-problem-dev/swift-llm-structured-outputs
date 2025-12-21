# ``LLMTool``

LLM が呼び出し可能なツール（関数）を定義・管理するモジュール。

@Metadata {
    @PageColor(green)
}

## 概要

LLMTool は、LLM に外部機能を呼び出させるためのツール定義システムを提供します。`@Tool` マクロを使用することで、Swift の関数を LLM から呼び出し可能なツールとして簡単に公開できます。

@Row {
    @Column(size: 2) {
        ### 主な機能

        - **@Tool マクロ** - Swift 関数をツールとして宣言的に定義
        - **@ToolArgument** - 引数に説明と制約を付与
        - **ToolSet** - 複数ツールをまとめて管理
        - **型安全な実行** - 引数の自動デコードと結果の型付け
        - **エラーハンドリング** - 実行エラーの適切な伝播
    }

    @Column {
        ```swift
        @Tool("天気を取得します")
        struct GetWeather {
            @ToolArgument("都市名")
            var city: String

            func call() async throws -> String {
                // API 呼び出し
                return "東京: 晴れ、25°C"
            }
        }
        ```
    }
}

## ツールの定義

### 基本的なツール

`@Tool` マクロでツールを定義し、`@ToolArgument` で引数に説明を付けます。

```swift
@Tool("2つの数値を計算します")
struct Calculator {
    @ToolArgument("最初の数値")
    var a: Double

    @ToolArgument("2番目の数値")
    var b: Double

    @ToolArgument("演算子", .enum(["+", "-", "*", "/"]))
    var operation: String

    func call() async throws -> String {
        let result: Double
        switch operation {
        case "+": result = a + b
        case "-": result = a - b
        case "*": result = a * b
        case "/": result = a / b
        default: throw ToolError.invalidOperation
        }
        return String(result)
    }
}
```

### オプショナル引数

引数を Optional 型にすると、LLM が省略可能な引数として認識します。

```swift
@Tool("Webを検索します")
struct WebSearch {
    @ToolArgument("検索クエリ")
    var query: String

    @ToolArgument("結果の最大件数")
    var maxResults: Int?  // 省略可能

    func call() async throws -> String {
        let limit = maxResults ?? 10
        // 検索実行
        return "検索結果..."
    }
}
```

### 設定プロパティ

`@ToolArgument` を付けないプロパティは設定値として扱われ、LLM からは見えません。

```swift
@Tool("APIを呼び出します")
struct APIClient {
    // 設定プロパティ（LLMからは見えない）
    var apiKey: String
    var baseURL: URL

    @ToolArgument("エンドポイント")
    var endpoint: String

    func call() async throws -> String {
        // apiKey と baseURL を使用
        return "レスポンス..."
    }
}
```

## ToolSet

複数のツールをまとめて管理します。

```swift
let tools = ToolSet {
    Calculator()
    WebSearch()
    APIClient(apiKey: "xxx", baseURL: URL(string: "https://api.example.com")!)
}

// ツール数の確認
print(tools.count)  // 3

// ツール定義の取得
let definitions = tools.definitions
```

### ToolSet の結合

複数の ToolSet を結合できます。

```swift
let basicTools = ToolSet {
    Calculator()
    DateTimeTool()
}

let webTools = ToolSet {
    WebSearch()
    FetchPage()
}

// 結合
let allTools = basicTools.appending(contentsOf: webTools)
```

## エージェントでの使用

ツールはエージェントループで自動的に実行されます。

```swift
let client = AnthropicClient(apiKey: "sk-ant-...")

let tools = ToolSet {
    Calculator()
    WebSearch()
}

for try await step in client.runAgent(
    input: "東京の明日の気温を調べて、華氏に変換して",
    model: .sonnet,
    tools: tools
) {
    switch step {
    case .toolCall(let call):
        print("🔧 \(call.name): \(call.arguments)")
    case .toolResult(let result):
        print("📄 結果: \(result.output)")
    case .finalResponse(let output):
        print("✅ \(output)")
    default:
        break
    }
}
```

## Topics

### ツール定義

- ``Tool``
- ``ToolDefinition``
- ``EmptyArguments``

### ツール管理

- ``ToolSet``
- ``ToolSetBuilder``

### ツール呼び出し

- ``ToolCall``
- ``ToolResponse``
- ``ToolResult``
- ``ToolChoice``

### クライアント拡張

- ``ToolCallableClient``
- ``ToolCallResponse``
