# システムプロンプト

最適化されたシステムプロンプトとエージェント行動指示を活用する方法を学びます。

## 概要

LLMToolkits は、GPT-4.1 および Anthropic のプロンプトエンジニアリングベストプラクティスに基づいた、目的別に最適化されたシステムプロンプトを提供します。

## システムプロンプトの構造

各システムプロンプトは以下の構造に従っています：

1. **Role（役割）** - LLM が演じるべき専門家の役割
2. **Objective（目的）** - 達成すべき主要な目標
3. **Instructions（指示）** - 従うべき具体的な手順
4. **Output Format（出力形式）** - 期待される出力の形式
5. **Constraints（制約）** - 守るべきルールや制限

## 利用可能なプロンプト

### リサーチャー

情報収集と分析に特化したプロンプト：

```swift
let systemPrompt = SystemPrompts.researcher

// 使用例
let stream: some AgentStepStream<AnalysisResult> = client.runAgent(
    prompt: "AI市場のトレンドを調査してください",
    model: .sonnet,
    tools: tools,
    systemPrompt: systemPrompt
)
```

### データアナリスト

数値分析と統計処理に特化したプロンプト：

```swift
let systemPrompt = SystemPrompts.dataAnalyst

// 使用例
let analysis: AnalysisResult = try await client.generate(
    prompt: "売上データを分析してください",
    model: .sonnet,
    systemPrompt: systemPrompt
)
```

### コーディングアシスタント

コード生成とレビューに特化したプロンプト：

```swift
let systemPrompt = SystemPrompts.codingAssistant

// 使用例
let review: CodeReview = try await client.generate(
    prompt: "このコードをレビューしてください: \(code)",
    model: .sonnet,
    systemPrompt: systemPrompt
)
```

### ライター

コンテンツ作成と編集に特化したプロンプト：

```swift
let systemPrompt = SystemPrompts.writer

// 使用例
let summary: Summary = try await client.generate(
    prompt: "この記事を要約してください: \(article)",
    model: .sonnet,
    systemPrompt: systemPrompt
)
```

### プランナー

タスク計画と作業分解に特化したプロンプト：

```swift
let systemPrompt = SystemPrompts.planner

// 使用例
let plan: TaskPlan = try await client.generate(
    prompt: "アプリ開発プロジェクトの計画を立ててください",
    model: .sonnet,
    systemPrompt: systemPrompt
)
```

## エージェント行動指示

`AgentBehaviors` は、GPT-4.1 のエージェント要素に基づいた行動指示を提供します。

### 永続性（Persistence）

タスクが完了するまで実行を継続する指示：

```swift
let persistence = AgentBehaviors.persistence

// 内容例:
// - 最終目標が達成されるまで作業を継続
// - 障害が発生した場合は代替アプローチを試行
// - ツールエラーには異なるパラメータで再試行
```

### ツール呼び出し（Tool Calling）

適切なツールを効果的に使用する指示：

```swift
let toolCalling = AgentBehaviors.toolCalling

// 内容例:
// - 思い込みではなくツールを使用して情報を確認
// - 利用可能なツールから最も適切なものを選択
// - ツールの結果を注意深く解釈
```

### 計画立案（Planning）

複雑なタスクを段階的に分解する指示：

```swift
let planning = AgentBehaviors.planning

// 内容例:
// - 複雑なタスクを管理可能なステップに分解
// - 各ステップを実行する前に計画を立案
// - 必要に応じて計画を調整
```

### すべての行動指示を組み合わせる

```swift
let allBehaviors = AgentBehaviors.allBehaviors

// すべてのエージェント行動指示を含む
// MinimalPreset はこれを使用
```

## プロンプトのカスタマイズ

`PromptModifiers` を使用してプロンプトをカスタマイズできます。

### 出力形式の指定

```swift
let modifiedPrompt = Prompt.customized(
    base: SystemPrompts.researcher,
    modifiers: [PromptModifiers.outputFormat(.json)]
)
```

### 応答言語の指定

```swift
let japaneseFriendly = Prompt.customized(
    base: SystemPrompts.dataAnalyst,
    modifiers: [PromptModifiers.responseLanguage("Japanese")]
)
```

### 詳細度の指定

```swift
let detailedPrompt = Prompt.customized(
    base: SystemPrompts.researcher,
    modifiers: [PromptModifiers.Verbosity.detailed.instruction]
)
```

### 専門レベルの指定

```swift
let expertPrompt = Prompt.customized(
    base: SystemPrompts.codingAssistant,
    modifiers: [PromptModifiers.ExpertiseLevel.expert.instruction]
)
```

## 関連項目

- ``SystemPrompts``
- ``AgentBehaviors``
- ``PromptModifiers``
- <doc:AgentPresets>
