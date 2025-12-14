//
//  ResearchReport.swift
//  AgentExample
//
//  リサーチシナリオの出力型定義
//

import Foundation
import LLMStructuredOutputs

// MARK: - Confidence Level

/// 信頼度レベル
@StructuredEnum("レポートの信頼度レベル")
enum ConfidenceLevel: String, Sendable {
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

// MARK: - Research Report

/// リサーチレポート
@Structured("Webリサーチの結果をまとめた構造化レポート")
struct ResearchReport: Equatable, Sendable {
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
