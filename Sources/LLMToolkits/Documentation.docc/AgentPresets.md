# エージェントプリセット

事前構成されたエージェントプリセットを使用してすぐに始める方法を学びます。

## 概要

エージェントプリセットは、システムプロンプト、ツールセット、設定を組み合わせた、すぐに使えるエージェント構成です。特定のタスクに最適化されており、迅速な開発と一貫した結果を実現します。

## 利用可能なプリセット

### ResearcherPreset

情報収集、分析、統合タスク向け：

```swift
let stream: some AgentStepStream<AnalysisResult> = client.runAgent(
    input: "AIエージェントの最新トレンドを調査してください",
    model: .sonnet,
    tools: ResearcherPreset.defaultTools,
    systemPrompt: ResearcherPreset.systemPrompt,
    configuration: ResearcherPreset.configuration
)

// 含まれるツール: Calculator, DateTime, TextAnalysis
// maxSteps: 15
// 多めのステップ数で複雑な調査タスクに対応
```

### DataAnalystPreset

数値分析、統計処理、データ解釈タスク向け：

```swift
let stream: some AgentStepStream<AnalysisResult> = client.runAgent(
    input: "Q1: 100万, Q2: 120万, Q3: 150万 の成長率を計算して分析してください",
    model: .sonnet,
    tools: DataAnalystPreset.defaultTools,
    systemPrompt: DataAnalystPreset.systemPrompt,
    configuration: DataAnalystPreset.configuration
)

// 含まれるツール: Calculator, DateTime, TextAnalysis
// maxSteps: 12
// 計算の繰り返しに対応
```

### CodingAssistantPreset

コード生成、デバッグ、リファクタリングタスク向け：

```swift
let stream: some AgentStepStream<CodeReview> = client.runAgent(
    input: "このSwiftコードをレビューして改善点を提案してください",
    model: .sonnet,
    tools: CodingAssistantPreset.defaultTools,
    systemPrompt: CodingAssistantPreset.systemPrompt,
    configuration: CodingAssistantPreset.configuration
)

// 含まれるツール: TextAnalysis, Calculator
// maxSteps: 10
// コード分析に特化
```

### WriterPreset

コンテンツ作成、編集、推敲タスク向け：

```swift
let stream: some AgentStepStream<Summary> = client.runAgent(
    input: "この記事を要約して重要ポイントをハイライトしてください",
    model: .sonnet,
    tools: WriterPreset.defaultTools,
    systemPrompt: WriterPreset.systemPrompt,
    configuration: WriterPreset.configuration
)

// 含まれるツール: TextAnalysis
// maxSteps: 8
// テキスト処理に特化
```

### PlannerPreset

タスク計画、プロジェクト管理、作業分解タスク向け：

```swift
let stream: some AgentStepStream<TaskPlan> = client.runAgent(
    input: "新しいモバイルアプリのローンチ計画を作成してください",
    model: .sonnet,
    tools: PlannerPreset.defaultTools,
    systemPrompt: PlannerPreset.systemPrompt,
    configuration: PlannerPreset.configuration
)

// 含まれるツール: DateTime, Calculator
// maxSteps: 12
// スケジュール計算に対応
```

### MinimalPreset

ツールを使用せず、純粋な会話・生成タスク向け：

```swift
let stream: some AgentStepStream<Summary> = client.runAgent(
    input: "機械学習の概念を説明してください",
    model: .sonnet,
    tools: MinimalPreset.defaultTools,
    systemPrompt: MinimalPreset.systemPrompt,
    configuration: MinimalPreset.configuration
)

// 含まれるツール: なし
// maxSteps: 5
// エージェント行動指示のみを含む軽量構成
```

## プリセットの構成要素

各プリセットは `AgentPreset` プロトコルに準拠しており、以下の要素を持ちます：

```swift
public protocol AgentPreset: Sendable {
    /// システムプロンプト
    static var systemPrompt: Prompt { get }

    /// デフォルトツールセット
    static var defaultTools: ToolSet { get }

    /// エージェント設定
    static var configuration: AgentConfiguration { get }
}
```

## カスタムプリセットの作成

`CustomPresetBuilder` を使用して、既存のプリセットをベースにカスタマイズしたプリセットを作成できます。

### 基本的なカスタマイズ

```swift
let customPreset = CustomPresetBuilder()
    .withSystemPrompt(SystemPrompts.researcher)
    .withTools {
        CalculatorTool()
        DateTimeTool()
        TextAnalysisTool()
        MyCustomTool()  // カスタムツールを追加
    }
    .withConfiguration(maxSteps: 20)
    .build()

// 使用
let stream: some AgentStepStream<AnalysisResult> = client.runAgent(
    input: "...",
    model: .sonnet,
    tools: customPreset.tools,
    systemPrompt: customPreset.systemPrompt,
    configuration: customPreset.configuration
)
```

### 既存プリセットをベースにカスタマイズ

```swift
let customPreset = CustomPresetBuilder(basedOn: ResearcherPreset.self)
    .addingLanguage("Japanese")
    .addingVerbosity(.detailed)
    .withConfiguration(
        maxSteps: 25,
        maxDuplicateToolCalls: 3
    )
    .build()
```

### 専門レベルを指定

```swift
let expertPreset = CustomPresetBuilder(basedOn: DataAnalystPreset.self)
    .addingExpertiseLevel(.expert)
    .build()

// 利用可能なレベル: .beginner, .intermediate, .expert
```

## プリセットにツールを追加

既存のプリセットのツールセットに追加のツールを含める：

```swift
// 追加ツールを定義
let additionalTools = ToolSet {
    WebSearchTool()
    FileReadTool()
}

// 既存のデフォルトツールに追加
let expandedTools = ResearcherPreset.toolsWithAdditions(additionalTools)

let stream: some AgentStepStream<AnalysisResult> = client.runAgent(
    input: "ウェブから情報を収集して分析してください",
    model: .sonnet,
    tools: expandedTools,
    systemPrompt: ResearcherPreset.systemPrompt,
    configuration: ResearcherPreset.configuration
)
```

## 会話型エージェントでの使用

プリセットは `ConversationalAgentSession` とも連携できます：

```swift
let session = ConversationalAgentSession(
    client: AnthropicClient(apiKey: "..."),
    systemPrompt: ResearcherPreset.systemPrompt,
    tools: ResearcherPreset.defaultTools
)

// マルチターン会話を維持しながらエージェントを実行
let stream1: some ConversationalAgentStepStream<AnalysisResult> = session.run(
    "市場トレンドを調査してください",
    model: .sonnet
)

// 前の会話コンテキストを保持して続行
let stream2: some ConversationalAgentStepStream<AnalysisResult> = session.run(
    "特にAI分野について詳しく",
    model: .sonnet
)
```

## 各プリセットの設定比較

| プリセット | maxSteps | ツール数 | 用途 |
|-----------|----------|---------|------|
| Researcher | 15 | 3 | 調査・分析 |
| DataAnalyst | 12 | 3 | 数値分析 |
| CodingAssistant | 10 | 2 | コード支援 |
| Writer | 8 | 1 | 文章作成 |
| Planner | 12 | 2 | 計画立案 |
| Minimal | 5 | 0 | 会話・生成 |

## 関連項目

- ``AgentPreset``
- ``ResearcherPreset``
- ``DataAnalystPreset``
- ``CodingAssistantPreset``
- ``WriterPreset``
- ``PlannerPreset``
- ``MinimalPreset``
- ``CustomPresetBuilder``
- ``BuiltCustomPreset``
- <doc:SystemPrompts>
- <doc:BuiltInTools>
