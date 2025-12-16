# ``LLMToolkits``

LLM エージェント開発を加速する高レベルツールキット。

## 概要

LLMToolkits は、LLMStructuredOutputs の上位モジュールとして、実用的なエージェント構築に必要な構成要素を提供します。GPT-4.1 および Anthropic のプロンプトエンジニアリングベストプラクティスに基づいて設計されています。

### 主な機能

- **システムプロンプト** - 研究者、データアナリスト、コーディングアシスタントなど、目的別の最適化済みプロンプト
- **組み込みツール** - 計算、日時操作、テキスト分析などの汎用ツール
- **共通出力構造体** - 分析結果、要約、分類など、再利用可能な構造化出力型
- **エージェントプリセット** - ツールセット、プロンプト、設定を組み合わせた即座に使えるエージェント構成

### 設計原則

このモジュールは以下のベストプラクティスを適用しています：

- **GPT-4.1 プロンプト構造**: Role → Objective → Instructions → Output Format → Examples
- **GPT-4.1 エージェント要素**: Persistence（永続性）+ Tool-calling（ツール呼び出し）+ Planning（計画立案）
- **Poka-yoke 設計**: 誤った入力を困難にする防御的な API 設計

## クイックスタート

### プリセットを使用したエージェント実行

```swift
import LLMToolkits
import LLMStructuredOutputs

let client = AnthropicClient(apiKey: "sk-ant-...")

// リサーチャープリセットを使用
let stream: some AgentStepStream<AnalysisResult> = client.runAgent(
    prompt: "市場トレンドを分析してください",
    model: .sonnet,
    tools: ResearcherPreset.defaultTools,
    systemPrompt: ResearcherPreset.systemPrompt,
    configuration: ResearcherPreset.configuration
)

for try await step in stream {
    switch step {
    case .toolCall(let call):
        print("🔧 ツール呼び出し: \(call.name)")
    case .finalResponse(let result):
        print("✅ 分析完了: \(result.summary)")
    default:
        break
    }
}
```

### 組み込みツールの使用

```swift
let tools = ToolSet {
    CalculatorTool()
    DateTimeTool()
    TextAnalysisTool()
}

let stream: some AgentStepStream<TaskPlan> = client.runAgent(
    prompt: "プロジェクトのスケジュールを計算して計画を立てて",
    model: .sonnet,
    tools: tools
)
```

### 共通出力構造体の使用

```swift
// 事前定義された構造体を使用
let analysis: AnalysisResult = try await client.generate(
    prompt: "このレポートを分析してください: \(reportText)",
    model: .sonnet
)

print(analysis.summary)
print(analysis.keyFindings)
print(analysis.recommendations)
```

## Topics

### 基本ガイド

- <doc:SystemPrompts>
- <doc:BuiltInTools>
- <doc:CommonOutputs>
- <doc:AgentPresets>

### システムプロンプト

- ``SystemPrompts``
- ``AgentBehaviors``
- ``PromptModifiers``

### 組み込みツール

- ``CalculatorTool``
- ``DateTimeTool``
- ``TextAnalysisTool``

### 共通出力構造体

- ``AnalysisResult``
- ``Summary``
- ``Classification``
- ``SentimentAnalysis``
- ``KeyPointExtraction``
- ``KeyPoint``
- ``QuestionAnswer``
- ``TaskPlan``
- ``TaskStep``
- ``ComparisonResult``
- ``ComparisonItem``
- ``EntityExtraction``
- ``ExtractedEntity``
- ``CodeReview``
- ``CodeIssue``

### エージェントプリセット

- ``AgentPreset``
- ``ResearcherPreset``
- ``DataAnalystPreset``
- ``CodingAssistantPreset``
- ``WriterPreset``
- ``PlannerPreset``
- ``MinimalPreset``
- ``CustomPresetBuilder``
- ``BuiltCustomPreset``
