//
//  ResearchReport.swift
//  AgentExample
//
//  リサーチレポート構造化出力型
//

import Foundation
import LLMStructuredOutputs

// MARK: - Confidence Level Enum

/// レポートの信頼度
@StructuredEnum("レポートの信頼度レベル")
enum ConfidenceLevel: String {
    @StructuredCase("複数の信頼できる情報源から確認された高い信頼度")
    case high

    @StructuredCase("情報源が限定的で中程度の信頼度")
    case medium

    @StructuredCase("未確認または推測が多い低い信頼度")
    case low
}

extension ConfidenceLevel {
    var displayName: String {
        switch self {
        case .high: return "高信頼度"
        case .medium: return "中程度"
        case .low: return "低信頼度"
        }
    }

    var icon: String {
        switch self {
        case .high: return "checkmark.shield.fill"
        case .medium: return "shield.fill"
        case .low: return "exclamationmark.shield.fill"
        }
    }
}

/// リサーチレポート
///
/// エージェントが生成する最終的な調査レポートの構造化出力型です。
/// 複数の情報源からの情報を統合し、構造化されたレポートを生成します。
@Structured("Webリサーチの結果をまとめた構造化レポート")
struct ResearchReport: Equatable {
    @StructuredField("レポートのタイトル")
    var title: String

    @StructuredField("レポートの要約（3〜5文程度）")
    var summary: String

    @StructuredField("調査で発見した主要なポイント（箇条書き形式）")
    var keyFindings: [String]

    @StructuredField("参照した情報源のURL一覧")
    var sources: [String]

    @StructuredField("追加の考察や推奨事項")
    var recommendations: String?

    @StructuredField("レポートの信頼度（high: 複数の信頼できる情報源から確認、medium: 情報源が限定的、low: 未確認または推測が多い）")
    var confidenceLevel: ConfidenceLevel
}

// MARK: - Agent Step Types

/// エージェントステップの種類
enum AgentStepType {
    case thinking
    case toolCall
    case toolResult
    case finalResponse

    var icon: String {
        switch self {
        case .thinking: return "brain.head.profile"
        case .toolCall: return "wrench.and.screwdriver"
        case .toolResult: return "doc.text"
        case .finalResponse: return "checkmark.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .thinking: return "思考中"
        case .toolCall: return "ツール呼び出し"
        case .toolResult: return "ツール結果"
        case .finalResponse: return "最終レスポンス"
        }
    }
}

/// エージェントステップ情報
struct AgentStepInfo: Identifiable {
    let id = UUID()
    let type: AgentStepType
    let content: String
    var detail: String?
    var isError: Bool = false
    let timestamp: Date = Date()
}

// MARK: - Agent Execution State

/// エージェント実行状態
enum AgentExecutionState: Equatable {
    case idle
    case loading
    case success(ResearchReport)
    case error(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    var report: ResearchReport? {
        if case .success(let report) = self { return report }
        return nil
    }

    var errorMessage: String? {
        if case .error(let message) = self { return message }
        return nil
    }
}

// MARK: - Research Scenario

/// リサーチシナリオ
struct ResearchScenario: Identifiable {
    let id = UUID()
    let name: String
    let prompt: String
    let description: String

    static let scenarios: [ResearchScenario] = [
        ResearchScenario(
            name: "最新技術調査",
            prompt: "最新のSwift Concurrency（async/await）の機能と使い方について調べて、初心者向けにわかりやすくまとめたレポートを作成してください。",
            description: "技術情報を検索し、複数のソースから情報を集めてレポートを生成"
        ),
        ResearchScenario(
            name: "都市比較",
            prompt: "東京とニューヨークの現在の天気を調べて比較し、今週末に観光するならどちらがおすすめか、天気と時差を考慮してレポートにまとめてください。",
            description: "天気APIと時刻取得を組み合わせた比較分析"
        ),
        ResearchScenario(
            name: "ニュース調査",
            prompt: "人工知能（AI）の最新ニュースを調べて、今注目されているトピックとその影響についてまとめたレポートを作成してください。",
            description: "Web検索でニュースを収集し、トレンドを分析"
        ),
        ResearchScenario(
            name: "総合リサーチ",
            prompt: "「サステナブルな生活」について調べて、具体的な実践方法と最新のトレンドをまとめてください。情報源も明記してください。",
            description: "Web検索とページ取得を組み合わせた深い調査"
        )
    ]
}
