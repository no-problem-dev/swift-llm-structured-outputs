# 共通出力構造体

再利用可能な構造化出力型を活用して開発を効率化する方法を学びます。

## 概要

LLMToolkits は、一般的な LLM タスク向けの構造化出力型を提供します。これらは GPT-4.1 および Anthropic の構造化出力ベストプラクティスに基づいて設計されており、制約付きの明確なスキーマを持っています。

## 分析系

### AnalysisResult

レポート分析、データ解釈、コンテンツ評価などの分析タスク向け：

```swift
let analysis: AnalysisResult = try await client.generate(
    prompt: "この市場レポートを分析してください: \(report)",
    model: .sonnet
)

print(analysis.summary)           // 分析の要約（2-4文）
print(analysis.keyFindings)       // 主要な発見（1-10項目）
print(analysis.recommendations)   // 推奨アクション（1-5項目）
print(analysis.risks)             // 潜在的リスク（最大5項目、オプション）
print(analysis.confidence)        // 信頼度スコア（0.0-1.0）
```

### SentimentAnalysis

テキストの感情分析向け：

```swift
let sentiment: SentimentAnalysis = try await client.generate(
    prompt: "このレビューの感情を分析してください: \(review)",
    model: .sonnet
)

print(sentiment.sentiment)    // "positive", "negative", "neutral", "mixed"
print(sentiment.intensity)    // 強度（0.0-1.0）
print(sentiment.emotions)     // 検出された感情（最大5項目）
print(sentiment.keyPhrases)   // 影響を与えたフレーズ（最大5項目）
print(sentiment.explanation)  // 分析の説明
```

### Classification

カテゴリ分類、トピック検出向け：

```swift
let classification: Classification = try await client.generate(
    prompt: "この問い合わせを分類してください: \(inquiry)",
    model: .sonnet
)

print(classification.primaryCategory)      // 主カテゴリ
print(classification.secondaryCategories)  // 副カテゴリ（最大3項目）
print(classification.confidence)           // 信頼度（0.0-1.0）
print(classification.reasoning)            // 分類理由
```

## 要約・抽出系

### Summary

長文の要約、記事のサマリー作成向け：

```swift
let summary: Summary = try await client.generate(
    prompt: "この記事を要約してください: \(article)",
    model: .sonnet
)

print(summary.briefSummary)    // 簡潔な要約（1-3文）
print(summary.mainPoints)      // 主要ポイント（1-7項目）
print(summary.keyTakeaways)    // 重要な結論（最大5項目）
print(summary.targetAudience)  // 対象読者（オプション）
```

### KeyPointExtraction

文書から重要ポイントを抽出：

```swift
let extraction: KeyPointExtraction = try await client.generate(
    prompt: "この議事録から重要ポイントを抽出してください: \(minutes)",
    model: .sonnet
)

print(extraction.overallTheme)  // 全体のテーマ
for point in extraction.keyPoints {
    print("\(point.point) - 重要度: \(point.importance)")  // 1-5
    print("  根拠: \(point.evidence ?? "なし")")
}
print(extraction.gaps)  // 情報が不足している領域
```

### EntityExtraction

固有名詞、日付、数値などのエンティティ抽出向け：

```swift
let entities: EntityExtraction = try await client.generate(
    prompt: "このテキストからエンティティを抽出してください: \(text)",
    model: .sonnet
)

print("抽出数: \(entities.totalCount)")
for entity in entities.entities {
    print("\(entity.entityType): \(entity.value) (信頼度: \(entity.confidence))")
    // entityType: person, organization, location, date, time, money, percentage, email, phone, url, other
}
```

## 質問応答・計画系

### QuestionAnswer

質問に対する回答を根拠とともに提示：

```swift
let qa: QuestionAnswer = try await client.generate(
    prompt: "Q: SwiftのActorとは何ですか？",
    model: .sonnet
)

print(qa.answer)              // 回答
print(qa.sources)             // 根拠（最大5項目）
print(qa.confidence)          // 信頼度（0.0-1.0）
print(qa.answerCompleteness)  // "complete", "partial", "unable_to_answer"
print(qa.followUpQuestions)   // フォローアップ質問（最大3項目）
```

### TaskPlan

複雑なタスクの計画と作業分解向け：

```swift
let plan: TaskPlan = try await client.generate(
    prompt: "モバイルアプリ開発プロジェクトの計画を立ててください",
    model: .sonnet
)

print("目標: \(plan.objective)")
print("前提条件: \(plan.prerequisites ?? [])")
print("成功基準: \(plan.successCriteria)")

for step in plan.steps {
    print("\(step.stepNumber). \(step.description)")
    print("   成果物: \(step.expectedOutput ?? "なし")")
    print("   依存: \(step.dependsOn ?? [])")
}

print("リスク: \(plan.risks ?? [])")
```

## 比較・レビュー系

### ComparisonResult

複数の選択肢の比較分析向け：

```swift
let comparison: ComparisonResult = try await client.generate(
    prompt: "SwiftUI と UIKit を比較してください",
    model: .sonnet
)

for item in comparison.items {
    print("📊 \(item.name) (スコア: \(item.score)/10)")
    print("   ✅ 長所: \(item.pros)")
    print("   ❌ 短所: \(item.cons)")
}

print("主な違い: \(comparison.keyDifferences)")
print("推奨: \(comparison.recommendation)")
print("理由: \(comparison.reasoning)")
print("注意点: \(comparison.caveats ?? [])")
```

### CodeReview

ソースコードの品質評価向け：

```swift
let review: CodeReview = try await client.generate(
    prompt: "このSwiftコードをレビューしてください: \(code)",
    model: .sonnet
)

print("総評: \(review.overallAssessment)")
print("品質スコア: \(review.qualityScore)/10")
print("良い点: \(review.strengths ?? [])")
print("改善提案: \(review.suggestions ?? [])")

for issue in review.issues ?? [] {
    print("⚠️ [\(issue.severity)] \(issue.category)")
    print("   \(issue.description)")
    print("   場所: \(issue.location ?? "不明")")
    print("   修正案: \(issue.suggestedFix ?? "なし")")
}
```

## エージェントループでの使用

これらの構造体はエージェントループの最終出力として特に効果的です：

```swift
let tools = ToolSet {
    CalculatorTool()
    TextAnalysisTool()
}

// ツールを使用して情報を収集し、構造化された分析結果を生成
let stream: some AgentStepStream<AnalysisResult> = client.runAgent(
    prompt: "この財務データを分析してレポートを作成してください: \(data)",
    model: .sonnet,
    tools: tools,
    systemPrompt: DataAnalystPreset.systemPrompt
)

for try await step in stream {
    switch step {
    case .toolCall(let call):
        print("🔧 \(call.name): \(call.arguments)")
    case .toolResult(let result):
        print("📤 結果: \(result.output)")
    case .finalResponse(let analysis):
        print("✅ 分析完了")
        print("要約: \(analysis.summary)")
        print("発見: \(analysis.keyFindings)")
    default:
        break
    }
}
```

## 関連項目

- ``AnalysisResult``
- ``Summary``
- ``Classification``
- ``SentimentAnalysis``
- ``KeyPointExtraction``
- ``QuestionAnswer``
- ``TaskPlan``
- ``ComparisonResult``
- ``EntityExtraction``
- ``CodeReview``
