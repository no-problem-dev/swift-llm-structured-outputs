import Foundation
import LLMStructuredOutputs

// MARK: - ResearchReport

/// リサーチレポート
///
/// 調査結果をまとめた構造化出力です。
@Structured("Research report with findings and sources")
struct ResearchReport {
    @StructuredField("Research topic")
    var topic: String

    @StructuredField("Summary of findings (200-400 words)")
    var summary: String

    @StructuredField("Key findings (3-5 items)")
    var keyFindings: [String]

    @StructuredField("Source URLs referenced")
    var sources: [String]

    @StructuredField("Questions for further investigation (2-3 items)")
    var furtherQuestions: [String]
}

// MARK: - SummaryReport

/// サマリーレポート
///
/// シンプルな要約を提供する構造化出力です。
@Structured("Concise summary report")
struct SummaryReport {
    @StructuredField("Summary title")
    var title: String

    @StructuredField("Brief summary (around 100 words)")
    var summary: String

    @StructuredField("Key bullet points (3-5 items)")
    var bulletPoints: [String]
}

// MARK: - ComparisonReport

/// 比較レポート
///
/// 複数の対象を比較する構造化出力です。
@Structured("Comparative analysis report")
struct ComparisonReport {
    @StructuredField("Subject being compared")
    var subject: String

    @StructuredField("List of items being compared")
    var items: [ComparisonItem]

    @StructuredField("Overall recommendation and conclusion")
    var recommendation: String
}

@Structured("Item in comparison")
struct ComparisonItem {
    @StructuredField("Name of the item")
    var name: String

    @StructuredField("Advantages/Pros")
    var pros: [String]

    @StructuredField("Disadvantages/Cons")
    var cons: [String]
}
