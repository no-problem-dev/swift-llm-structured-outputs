//
//  AgentOutputTypes.swift
//  AgentExample
//
//  エージェント出力の構造化型定義
//

import Foundation
import LLMStructuredOutputs

// MARK: - Research Report

/// 信頼度レベル
@StructuredEnum("レポートの信頼度レベル")
enum ConfidenceLevel: String {
    @StructuredCase("複数の信頼できる情報源から確認された高い信頼度")
    case high

    @StructuredCase("情報源が限定的で中程度の信頼度")
    case medium

    @StructuredCase("未確認または推測が多い低い信頼度")
    case low

    var displayName: String {
        switch self {
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        }
    }
}

/// リサーチレポート
@Structured("Webリサーチの結果をまとめた構造化レポート")
struct ResearchReport: Equatable {
    @StructuredField("レポートのタイトル")
    var title: String

    @StructuredField("レポートの要約（3〜5文程度）")
    var summary: String

    @StructuredField("調査で発見した主要なポイント")
    var keyFindings: [String]

    @StructuredField("参照した情報源のURL一覧")
    var sources: [String]

    @StructuredField("追加の考察や推奨事項")
    var recommendations: String?

    @StructuredField("レポートの信頼度")
    var confidenceLevel: ConfidenceLevel
}

// MARK: - Calculation Report

/// 計算ステップ
@Structured("計算の各ステップ")
struct CalculationStep: Equatable {
    @StructuredField("計算式または操作の説明")
    var expression: String

    @StructuredField("この計算の結果")
    var result: String

    @StructuredField("計算の補足説明")
    var note: String?
}

/// 計算レポート
@Structured("計算処理の結果をまとめた構造化レポート")
struct CalculationReport: Equatable {
    @StructuredField("レポートのタイトル")
    var title: String

    @StructuredField("計算の目的や背景の説明")
    var description: String

    @StructuredField("実行した計算ステップの一覧")
    var steps: [CalculationStep]

    @StructuredField("最終的な計算結果のまとめ")
    var finalResult: String

    @StructuredField("結果に対する補足説明や注意点")
    var notes: String?
}

// MARK: - Temporal Report

/// 時刻情報
@Structured("特定の場所の時刻情報")
struct TimeInfo: Equatable {
    @StructuredField("都市名または場所名")
    var location: String

    @StructuredField("現在の日時（例: 2024年1月15日 14:30）")
    var dateTime: String

    @StructuredField("タイムゾーン名（例: JST, EST, GMT）")
    var timezone: String

    @StructuredField("UTCとの時差（例: +9:00）")
    var offsetFromUTC: String?
}

/// 時間レポート
@Structured("時間・日時に関する情報をまとめた構造化レポート")
struct TemporalReport: Equatable {
    @StructuredField("レポートのタイトル")
    var title: String

    @StructuredField("調査または計算の目的")
    var purpose: String

    @StructuredField("各場所の時刻情報一覧")
    var timeInfos: [TimeInfo]

    @StructuredField("時差や時刻に関する分析・まとめ")
    var summary: String

    @StructuredField("推奨事項やアドバイス")
    var recommendation: String?
}

// MARK: - MultiTool Report

/// 比較項目
@Structured("比較分析の各項目")
struct ComparisonItem: Equatable {
    @StructuredField("比較の観点（例: 天気、気温、時差）")
    var aspect: String

    @StructuredField("比較対象Aの値または状態")
    var valueA: String

    @StructuredField("比較対象Bの値または状態")
    var valueB: String

    @StructuredField("この観点での評価や判定")
    var evaluation: String?
}

/// 複合ツールレポート
@Structured("複数ツールを使用した総合分析の構造化レポート")
struct MultiToolReport: Equatable {
    @StructuredField("レポートのタイトル")
    var title: String

    @StructuredField("分析の目的や背景")
    var objective: String

    @StructuredField("収集した情報のまとめ")
    var findings: [String]

    @StructuredField("比較分析の結果")
    var comparisons: [ComparisonItem]?

    @StructuredField("数値計算の結果")
    var calculations: [String]?

    @StructuredField("総合的な結論")
    var conclusion: String

    @StructuredField("推奨事項やアドバイス")
    var recommendation: String?

    @StructuredField("参照した情報源")
    var sources: [String]?
}

// MARK: - Reasoning Report

/// 推論ステップ
@Structured("推論の各ステップ")
struct ReasoningStep: Equatable {
    @StructuredField("このステップの番号")
    var stepNumber: Int

    @StructuredField("このステップで行った分析や推論")
    var reasoning: String

    @StructuredField("このステップで得られた中間結果")
    var intermediateResult: String?
}

/// 推論レポート
@Structured("論理的推論・分析の結果をまとめた構造化レポート")
struct ReasoningReport: Equatable {
    @StructuredField("レポートのタイトル")
    var title: String

    @StructuredField("与えられた問題や課題の説明")
    var problemStatement: String

    @StructuredField("問題の分析・前提条件の整理")
    var analysis: String

    @StructuredField("推論のステップ一覧")
    var reasoningSteps: [ReasoningStep]

    @StructuredField("最終的な結論・答え")
    var conclusion: String

    @StructuredField("計算による検証結果")
    var verification: String?

    @StructuredField("追加の考察や別解")
    var additionalNotes: String?
}

// MARK: - Unified Agent Result

/// エージェント結果（全カテゴリ統合）
enum AgentResult: Equatable {
    case research(ResearchReport)
    case calculation(CalculationReport)
    case temporal(TemporalReport)
    case multiTool(MultiToolReport)
    case reasoning(ReasoningReport)

    var title: String {
        switch self {
        case .research(let r): return r.title
        case .calculation(let r): return r.title
        case .temporal(let r): return r.title
        case .multiTool(let r): return r.title
        case .reasoning(let r): return r.title
        }
    }
}
