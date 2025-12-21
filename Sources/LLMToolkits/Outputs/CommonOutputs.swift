import Foundation
import LLMClient

// MARK: - CommonOutputs

/// 一般的なLLMタスク向けの構造化出力型
///
/// これらの構造体は一般的なLLMユースケースに最適化されており、
/// GPT-4.1およびAnthropicの構造化出力ベストプラクティスに基づいて
/// 制約付きの明確なスキーマを提供します。
///
/// ## 使用例
///
/// ```swift
/// let result: AnalysisResult = try await client.generate(
///     input: "Analyze the market trends in this report: \(reportText)",
///     model: .sonnet
/// )
/// print(result.summary)
/// print(result.keyFindings)
/// ```

// MARK: - AnalysisResult

/// 分析タスクの結果を構造化した出力型
///
/// レポート分析、データ解釈、コンテンツ評価など、
/// 複数の観点から分析結果を提示する場合に使用します。
///
/// ## 適用されたベストプラクティス
/// - **明確なフィールド名**: 各フィールドの目的が自明
/// - **制約付き配列**: minItems/maxItemsで出力の一貫性を確保
/// - **信頼度スコア**: 分析の確実性を定量化
@Structured("Structured analysis result with findings, recommendations, and confidence score")
public struct AnalysisResult {

    @StructuredField("Brief one-paragraph summary of the analysis (2-4 sentences)")
    public var summary: String

    @StructuredField("Key findings from the analysis")
    public var keyFindings: [String]

    @StructuredField("Actionable recommendations based on the analysis")
    public var recommendations: [String]

    @StructuredField("Potential risks or concerns identified")
    public var risks: [String]?

    @StructuredField("Confidence score from 0.0 (uncertain) to 1.0 (highly confident)")
    public var confidence: Double
}

// MARK: - Summary

/// テキスト要約の結果を構造化した出力型
///
/// 長文の要約、記事のサマリー作成、
/// 文書の概要抽出などに使用します。
@Structured("Text summarization output with main points and key takeaways")
public struct Summary {

    @StructuredField("Concise summary of the main content (1-3 sentences)")
    public var briefSummary: String

    @StructuredField("Main points covered in the content")
    public var mainPoints: [String]

    @StructuredField("Key takeaways or action items")
    public var keyTakeaways: [String]?

    @StructuredField("Target audience this content is intended for")
    public var targetAudience: String?
}

// MARK: - Classification

/// 分類タスクの結果を構造化した出力型
///
/// カテゴリ分類、トピック検出、コンテンツタグ付けなど、
/// 入力を1つ以上のカテゴリに分類する場合に使用します。
@Structured("Classification result with category, confidence, and reasoning")
public struct Classification {

    @StructuredField("Primary category or label for the input")
    public var primaryCategory: String

    @StructuredField("Secondary categories if applicable")
    public var secondaryCategories: [String]?

    @StructuredField("Confidence score for the classification from 0.0 to 1.0")
    public var confidence: Double

    @StructuredField("Brief explanation for why this classification was chosen")
    public var reasoning: String
}

// MARK: - SentimentAnalysis

/// 感情分析の結果を構造化した出力型
///
/// テキストの感情極性、トーン、感情の強さを分析する場合に使用します。
/// レビュー分析、フィードバック処理、ソーシャルメディア分析などに最適。
@Structured("Sentiment analysis result with polarity, emotions, and intensity")
public struct SentimentAnalysis {

    @StructuredField(
        "Overall sentiment polarity",
        .enum(["positive", "negative", "neutral", "mixed"])
    )
    public var sentiment: String

    @StructuredField("Sentiment intensity from 0.0 (weak) to 1.0 (strong)")
    public var intensity: Double

    @StructuredField("Detected emotions in the text")
    public var emotions: [String]?

    @StructuredField("Key phrases that influenced the sentiment analysis")
    public var keyPhrases: [String]?

    @StructuredField("Brief explanation of the sentiment analysis")
    public var explanation: String
}

// MARK: - KeyPointExtraction

/// キーポイント抽出の結果を構造化した出力型
///
/// 文書やテキストから重要なポイントを抽出し、
/// 優先度付きで整理する場合に使用します。
@Structured("Extracted key points with importance ranking and supporting evidence")
public struct KeyPointExtraction {

    @StructuredField("Extracted key points with details")
    public var keyPoints: [KeyPoint]

    @StructuredField("Overall theme or topic of the content")
    public var overallTheme: String

    @StructuredField("Areas that need more information or clarification")
    public var gaps: [String]?
}

/// 個々のキーポイントを表す構造体
@Structured("A single key point with importance and evidence")
public struct KeyPoint {

    @StructuredField("The key point statement")
    public var point: String

    @StructuredField("Importance level from 1 (low) to 5 (critical)")
    public var importance: Int

    @StructuredField("Supporting evidence or quote from the source")
    public var evidence: String?
}

// MARK: - QuestionAnswer

/// 質問応答タスクの結果を構造化した出力型
///
/// 質問に対する回答を、根拠や信頼度とともに提示する場合に使用します。
/// RAGシステム、FAQ応答、知識ベースクエリなどに最適。
@Structured("Question answering result with answer, sources, and confidence")
public struct QuestionAnswer {

    @StructuredField("Direct answer to the question")
    public var answer: String

    @StructuredField("Supporting evidence or sources for the answer")
    public var sources: [String]?

    @StructuredField("Confidence in the answer from 0.0 to 1.0")
    public var confidence: Double

    @StructuredField(
        "Whether the answer fully addresses the question",
        .enum(["complete", "partial", "unable_to_answer"])
    )
    public var answerCompleteness: String

    @StructuredField("Follow-up questions that might help clarify")
    public var followUpQuestions: [String]?
}

// MARK: - TaskPlan

/// タスク計画の結果を構造化した出力型
///
/// 複雑なタスクを分解し、実行可能なステップに整理する場合に使用します。
/// プロジェクト計画、作業分解、ロードマップ作成などに最適。
@Structured("Task planning output with steps, dependencies, and resource estimates")
public struct TaskPlan {

    @StructuredField("Goal or objective this plan achieves")
    public var objective: String

    @StructuredField("Ordered list of steps to complete the task")
    public var steps: [TaskStep]

    @StructuredField("Prerequisites or requirements before starting")
    public var prerequisites: [String]?

    @StructuredField("Potential risks or blockers to be aware of")
    public var risks: [String]?

    @StructuredField("Success criteria for the completed task")
    public var successCriteria: [String]
}

/// タスク計画内の個々のステップを表す構造体
@Structured("A single step in a task plan")
public struct TaskStep {

    @StructuredField("Step number in sequence (starting from 1)")
    public var stepNumber: Int

    @StructuredField("Description of what to do in this step")
    public var description: String

    @StructuredField("Expected output or deliverable from this step")
    public var expectedOutput: String?

    @StructuredField("Step numbers this step depends on")
    public var dependsOn: [Int]?
}

// MARK: - ComparisonResult

/// 比較分析の結果を構造化した出力型
///
/// 複数の選択肢、オプション、アイテムを比較分析する場合に使用します。
/// 製品比較、意思決定支援、トレードオフ分析などに最適。
@Structured("Comparison analysis result with pros, cons, and recommendation")
public struct ComparisonResult {

    @StructuredField("Items being compared")
    public var items: [ComparisonItem]

    @StructuredField("Key differences between the items")
    public var keyDifferences: [String]

    @StructuredField("Recommended choice based on the comparison")
    public var recommendation: String

    @StructuredField("Reasoning for the recommendation")
    public var reasoning: String

    @StructuredField("Factors that might change this recommendation")
    public var caveats: [String]?
}

/// 比較対象のアイテムを表す構造体
@Structured("An item in a comparison with its pros and cons")
public struct ComparisonItem {

    @StructuredField("Name or identifier of the item")
    public var name: String

    @StructuredField("Advantages or strengths")
    public var pros: [String]

    @StructuredField("Disadvantages or weaknesses")
    public var cons: [String]

    @StructuredField("Overall score from 1 (poor) to 10 (excellent)")
    public var score: Int
}

// MARK: - EntityExtraction

/// エンティティ抽出の結果を構造化した出力型
///
/// テキストから固有名詞、日付、数値などのエンティティを抽出する場合に使用します。
/// NER（固有表現認識）、データ抽出、情報整理などに最適。
@Structured("Entity extraction result with categorized entities")
public struct EntityExtraction {

    @StructuredField("Extracted entities organized by type")
    public var entities: [ExtractedEntity]

    @StructuredField("Total count of entities extracted")
    public var totalCount: Int

    @StructuredField("Entity types that were searched but not found")
    public var notFoundTypes: [String]?
}

/// 抽出されたエンティティを表す構造体
@Structured("A single extracted entity with its type and context")
public struct ExtractedEntity {

    @StructuredField("The extracted entity value")
    public var value: String

    @StructuredField(
        "Type of entity",
        .enum([
            "person", "organization", "location", "date", "time",
            "money", "percentage", "email", "phone", "url", "other"
        ])
    )
    public var entityType: String

    @StructuredField("Confidence in the extraction from 0.0 to 1.0")
    public var confidence: Double

    @StructuredField("Context or sentence where the entity was found")
    public var context: String?
}

// MARK: - CodeReview

/// コードレビューの結果を構造化した出力型
///
/// ソースコードの品質評価、問題点の指摘、改善提案などに使用します。
/// 自動コードレビュー、品質チェック、リファクタリング提案などに最適。
@Structured("Code review result with issues, suggestions, and quality score")
public struct CodeReview {

    @StructuredField("Overall assessment of the code quality")
    public var overallAssessment: String

    @StructuredField("Issues found in the code")
    public var issues: [CodeIssue]?

    @StructuredField("Suggestions for improvement")
    public var suggestions: [String]?

    @StructuredField("Positive aspects of the code")
    public var strengths: [String]?

    @StructuredField("Overall quality score from 1 (poor) to 10 (excellent)")
    public var qualityScore: Int
}

/// コードの問題点を表す構造体
@Structured("A single code issue with severity and location")
public struct CodeIssue {

    @StructuredField("Description of the issue")
    public var description: String

    @StructuredField(
        "Severity level of the issue",
        .enum(["critical", "major", "minor", "suggestion"])
    )
    public var severity: String

    @StructuredField(
        "Category of the issue",
        .enum([
            "bug", "security", "performance", "maintainability",
            "style", "documentation", "testing", "other"
        ])
    )
    public var category: String

    @StructuredField("Line number or location where the issue was found")
    public var location: String?

    @StructuredField("Suggested fix for the issue")
    public var suggestedFix: String?
}
