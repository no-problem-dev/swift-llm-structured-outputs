# 組み込みツール

LLM エージェントで使用できる組み込みツールの使い方を学びます。

## 概要

LLMToolkits は、エージェントが使用できる汎用的な組み込みツールを提供します。これらのツールは、計算、日時操作、テキスト分析などの一般的なタスクをサポートします。

## CalculatorTool

数学計算を実行するツールです。

### サポートされる演算

- **基本演算**: `+`, `-`, `*`, `/`, `%`（剰余）
- **べき乗**: `**` または `pow(x, y)`
- **平方根**: `sqrt(x)`
- **三角関数**: `sin`, `cos`, `tan`（ラジアン単位）
- **対数**: `log`（自然対数）, `log10`
- **絶対値**: `abs(x)`
- **丸め**: `floor`, `ceil`, `round`
- **定数**: `pi`, `e`

### 使用例

```swift
let tools = ToolSet {
    CalculatorTool()
}

// エージェントループで使用
let stream: some AgentStepStream<TaskPlan> = client.runAgent(
    prompt: "売上が100万円で、月間成長率が5%の場合、1年後の売上を計算して",
    model: .sonnet,
    tools: tools
)

// LLMは以下のようなツール呼び出しを行います：
// calculator(expression: "1000000 * (1.05 ** 12)")
// 結果: "1795856.326"
```

### 精度の制御

```swift
// LLMは precision パラメータで小数点以下桁数を指定できます
// expression: "22/7", precision: 10
// 結果: "3.1428571429"
```

## DateTimeTool

日時の取得と計算を行うツールです。

### サポートされる操作

- **now**: 現在の日時を取得
- **add**: 日時に期間を加算
- **subtract**: 日時から期間を減算
- **difference**: 2つの日時の差を計算
- **format**: 日時を指定形式に変換

### 使用例

```swift
let tools = ToolSet {
    DateTimeTool()
}

// エージェントループで使用
let stream: some AgentStepStream<TaskPlan> = client.runAgent(
    prompt: "今日から30日後の日付を計算して、プロジェクトの締め切りを設定して",
    model: .sonnet,
    tools: tools
)

// LLMは以下のようなツール呼び出しを行います：
// date_time(operation: "now", output_format: "iso8601")
// date_time(operation: "add", date: "2024-03-15T10:00:00Z", duration_value: 30, duration_unit: "days")
```

### 出力形式

- **iso8601**: `2024-03-15T10:30:00Z`
- **readable**: `Friday, March 15, 2024 at 10:30:00 AM JST`
- **date_only**: `2024-03-15`
- **time_only**: `10:30:00`
- **unix**: `1710499800`

### タイムゾーン

```swift
// LLMは timezone パラメータでタイムゾーンを指定できます
// date_time(operation: "now", timezone: "Asia/Tokyo")
```

## TextAnalysisTool

テキストの分析と変換を行うツールです。

### サポートされる操作

- **stats**: 文字数、単語数、文数などの統計を取得
- **find**: 正規表現パターンの検索
- **extract**: パターンにマッチする部分を抽出
- **replace**: パターンに基づく置換
- **split**: 区切り文字でテキストを分割
- **trim**: 前後の空白を除去
- **substring**: テキストの一部を抽出

### 使用例

```swift
let tools = ToolSet {
    TextAnalysisTool()
}

// エージェントループで使用
let stream: some AgentStepStream<KeyPointExtraction> = client.runAgent(
    prompt: "このテキストからメールアドレスを抽出して分析して: \(text)",
    model: .sonnet,
    tools: tools
)

// LLMは以下のようなツール呼び出しを行います：
// text_analysis(operation: "extract", text: "...", pattern: "\\b[\\w.]+@[\\w.]+\\.[\\w]+\\b")
```

### 統計情報の取得

```swift
// text_analysis(operation: "stats", text: "...")
// 結果:
// Text Statistics:
// - Characters (total): 150
// - Characters (no spaces): 120
// - Words: 25
// - Sentences (approx): 3
// - Lines: 1
// - Paragraphs: 1
// - Avg word length: 4.8
```

### 正規表現の使用

```swift
// 大文字小文字を区別しない検索
// text_analysis(operation: "find", text: "...", pattern: "error", case_sensitive: false)

// キャプチャグループを使用した置換
// text_analysis(operation: "replace", text: "...", pattern: "(\\d+)円", replacement: "$1 yen")
```

## 複数のツールを組み合わせる

```swift
let tools = ToolSet {
    CalculatorTool()
    DateTimeTool()
    TextAnalysisTool()
}

// すべてのツールを使用可能なエージェント
let stream: some AgentStepStream<AnalysisResult> = client.runAgent(
    prompt: """
    以下のタスクを実行してください：
    1. 今日の日付を取得
    2. 売上データから数値を抽出
    3. 合計と平均を計算
    4. 結果を分析レポートにまとめる
    """,
    model: .sonnet,
    tools: tools,
    systemPrompt: DataAnalystPreset.systemPrompt
)
```

## プリセットとの連携

各プリセットには適切なツールセットが事前設定されています：

```swift
// ResearcherPreset: Calculator + DateTime + TextAnalysis
let researcherTools = ResearcherPreset.defaultTools

// DataAnalystPreset: Calculator + DateTime + TextAnalysis
let analystTools = DataAnalystPreset.defaultTools

// CodingAssistantPreset: TextAnalysis + Calculator
let coderTools = CodingAssistantPreset.defaultTools

// WriterPreset: TextAnalysis
let writerTools = WriterPreset.defaultTools

// PlannerPreset: DateTime + Calculator
let plannerTools = PlannerPreset.defaultTools
```

## 関連項目

- ``CalculatorTool``
- ``DateTimeTool``
- ``TextAnalysisTool``
- <doc:AgentPresets>
