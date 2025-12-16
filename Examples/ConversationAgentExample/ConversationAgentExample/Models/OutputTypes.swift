//
//  OutputTypes.swift
//  ConversationAgentExample
//
//  構造化出力の型定義
//

import Foundation
import LLMStructuredOutputs

// MARK: - ResearchReport

/// リサーチレポート
///
/// 調査結果をまとめた構造化出力です。
@Structured("調査結果のレポート")
struct ResearchReport {
    @StructuredField("調査トピック")
    var topic: String

    @StructuredField("調査結果の要約（200-400文字程度）")
    var summary: String

    @StructuredField("重要な発見事項（3-5項目）")
    var keyFindings: [String]

    @StructuredField("参照した情報源のURL")
    var sources: [String]

    @StructuredField("さらに調査すべき質問（2-3項目）")
    var furtherQuestions: [String]
}

// MARK: - SummaryReport

/// サマリーレポート
///
/// シンプルな要約を提供する構造化出力です。
@Structured("シンプルな要約レポート")
struct SummaryReport {
    @StructuredField("要約のタイトル")
    var title: String

    @StructuredField("100文字程度の簡潔な要約")
    var summary: String

    @StructuredField("箇条書きのポイント（3-5項目）")
    var bulletPoints: [String]
}

// MARK: - ComparisonReport

/// 比較レポート
///
/// 複数の対象を比較する構造化出力です。
@Structured("比較分析レポート")
struct ComparisonReport {
    @StructuredField("比較の対象となるテーマ")
    var subject: String

    @StructuredField("比較対象のリスト")
    var items: [ComparisonItem]

    @StructuredField("総合的な推奨・結論")
    var recommendation: String
}

/// 比較対象
@Structured("比較対象の詳細")
struct ComparisonItem {
    @StructuredField("対象の名前")
    var name: String

    @StructuredField("メリット")
    var pros: [String]

    @StructuredField("デメリット")
    var cons: [String]
}

// MARK: - OutputType Selection

/// 出力タイプの選択
enum OutputTypeSelection: String, CaseIterable, Identifiable {
    case research = "research"
    case summary = "summary"
    case comparison = "comparison"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .research:
            return "リサーチレポート"
        case .summary:
            return "サマリーレポート"
        case .comparison:
            return "比較レポート"
        }
    }

    var description: String {
        switch self {
        case .research:
            return "詳細な調査結果と情報源を含む"
        case .summary:
            return "シンプルな要約と箇条書き"
        case .comparison:
            return "複数対象の比較分析"
        }
    }

    var systemPromptHint: String {
        switch self {
        case .research:
            return "詳細に調査し、情報源を明記してレポートを作成してください。"
        case .summary:
            return "簡潔にまとめてください。"
        case .comparison:
            return "複数の選択肢を比較し、メリット・デメリットを分析してください。"
        }
    }
}
