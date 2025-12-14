//
//  CalculationReport.swift
//  AgentExample
//
//  計算シナリオの出力型定義
//

import Foundation
import LLMStructuredOutputs

// MARK: - Calculation Step

/// 計算ステップ
@Structured("計算の各ステップ")
struct CalculationStep: Equatable, Sendable {
    @StructuredField("計算式または操作の説明")
    var expression: String

    @StructuredField("この計算の結果")
    var result: String

    @StructuredField("計算の補足説明")
    var note: String?
}

// MARK: - Calculation Report

/// 計算レポート
@Structured("計算処理の結果をまとめた構造化レポート")
struct CalculationReport: Equatable, Sendable {
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
