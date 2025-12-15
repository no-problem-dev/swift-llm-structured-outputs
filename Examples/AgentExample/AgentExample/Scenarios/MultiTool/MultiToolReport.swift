//
//  MultiToolReport.swift
//  AgentExample
//
//  複合ツールシナリオの出力型定義
//

import Foundation
import LLMStructuredOutputs

// MARK: - Comparison Item

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

// MARK: - MultiTool Report

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
