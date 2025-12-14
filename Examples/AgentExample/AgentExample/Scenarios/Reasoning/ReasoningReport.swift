//
//  ReasoningReport.swift
//  AgentExample
//
//  推論シナリオの出力型定義
//

import Foundation
import LLMStructuredOutputs

// MARK: - Reasoning Step

/// 推論ステップ
@Structured("推論の各ステップ")
struct ReasoningStep: Equatable, Sendable {
    @StructuredField("このステップの番号")
    var stepNumber: Int

    @StructuredField("このステップで行った分析や推論")
    var reasoning: String

    @StructuredField("このステップで得られた中間結果")
    var intermediateResult: String?
}

// MARK: - Reasoning Report

/// 推論レポート
@Structured("論理的推論・分析の結果をまとめた構造化レポート")
struct ReasoningReport: Equatable, Sendable {
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
