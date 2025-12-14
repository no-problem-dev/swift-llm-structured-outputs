//
//  MultiToolScenario.swift
//  AgentExample
//
//  複合ツールシナリオの定義
//  カテゴリ情報・プロンプト・サンプルシナリオを一箇所で管理
//

import Foundation
import LLMStructuredOutputs

// MARK: - MultiTool Scenario

/// 複合ツールシナリオ
///
/// 複数のツールを組み合わせた総合分析に特化したシナリオ。
/// Web検索、天気、時刻、計算など複数のツールを連携させます。
enum MultiToolScenario: AgentScenarioType {
    typealias Output = MultiToolReport

    // MARK: - Meta Information

    static let id = "multiTool"
    static let displayName = "複合"
    static let icon = "square.stack.3d.up"
    static let description = "複数ツール連携"

    // MARK: - System Prompt

    static func systemPrompt() -> Prompt {
        Prompt {
            PromptComponent.role("複数の情報源とツールを組み合わせて総合的な分析を行う専門家です")

            PromptComponent.expertise("Web検索による情報収集")
            PromptComponent.expertise("天気情報の取得と分析")
            PromptComponent.expertise("時刻とタイムゾーンの管理")
            PromptComponent.expertise("数値計算と単位変換")

            PromptComponent.behavior("必要に応じて複数のツールを組み合わせて使用する")
            PromptComponent.behavior("異なるソースからの情報を統合して分析する")
            PromptComponent.behavior("比較分析の際は明確な基準を設定する")

            PromptComponent.objective("ユーザーの複合的な依頼に対して、複数のツールを効果的に活用し、総合的な分析と推奨を含む構造化レポートを作成する")

            PromptComponent.instruction("依頼内容を分析し、必要なツールを特定する")
            PromptComponent.instruction("天気、時刻、計算、検索など必要なツールを順番に使用する")
            PromptComponent.instruction("収集した情報を統合し、比較分析を行う")
            PromptComponent.instruction("結論と推奨事項を明確に述べる")

            PromptComponent.constraint("各ツールの結果を混同しないこと")
            PromptComponent.constraint("比較を行う際は同じ基準で評価すること")

            PromptComponent.important("最終的な出力は必ず MultiToolReport の構造に従った JSON 形式で返すこと")
            PromptComponent.important("findings に収集した情報、comparisons に比較分析（該当する場合）、conclusion に総合的な結論を含めること")
        }
    }

    // MARK: - Sample Scenarios

    static let sampleScenarios: [SampleScenario] = [
        SampleScenario(
            name: "都市比較",
            prompt: "TokyoとNew Yorkの現在の天気を調べて比較し、今週末に観光するならどちらがおすすめか、天気と時差を考慮してレポートにまとめてください。",
            description: "天気APIと時刻取得を組み合わせた比較分析"
        ),
        SampleScenario(
            name: "旅行プランニング",
            prompt: "Parisへの旅行を計画しています。現在のParisの天気と時刻を確認し、1ユーロ=160円として、1日の予算5万円で何ユーロ使えるか計算してください。",
            description: "天気・時刻・計算を組み合わせた旅行計画"
        ),
        SampleScenario(
            name: "スポーツイベント調査",
            prompt: "次のオリンピックについてWeb検索で情報を調べ、開催地の現在の天気と、日本との時差を確認してまとめてください。",
            description: "Web検索・天気・時刻の複合利用"
        )
    ]
}
