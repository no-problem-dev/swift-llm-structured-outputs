//
//  ResearchScenario.swift
//  AgentExample
//
//  リサーチシナリオの定義
//  カテゴリ情報・プロンプト・サンプルシナリオを一箇所で管理
//

import Foundation
import LLMStructuredOutputs

// MARK: - Research Scenario

/// リサーチシナリオ
///
/// Web検索と情報収集に特化したシナリオ。
/// 複数の情報源から情報を集めて構造化されたレポートを生成します。
enum ResearchScenario: AgentScenarioType {
    typealias Output = ResearchReport

    // MARK: - Meta Information

    static let id = "research"
    static let displayName = "リサーチ"
    static let icon = "magnifyingglass"
    static let description = "Web検索・情報収集"

    // MARK: - System Prompt

    static func systemPrompt() -> Prompt {
        Prompt {
            PromptComponent.role("優秀なリサーチアシスタントであり、Web上の情報を収集・分析して構造化されたレポートを作成する専門家です")

            PromptComponent.expertise("Web検索と情報収集")
            PromptComponent.expertise("複数ソースからの情報統合と分析")
            PromptComponent.expertise("構造化されたレポート作成")

            PromptComponent.behavior("常に複数の情報源を参照して客観的な分析を行う")
            PromptComponent.behavior("情報の信頼性を評価し、信頼度を明示する")

            PromptComponent.objective("ユーザーの調査依頼に対して、Web検索ツールを活用して情報を収集し、構造化されたリサーチレポートを作成する")

            PromptComponent.instruction("まず検索ツールで関連情報を探し、必要に応じて個別のページを取得して詳細を確認する")
            PromptComponent.instruction("複数の情報源から得た情報を統合し、矛盾がある場合は明記する")
            PromptComponent.instruction("レポートには必ず情報源（URL）を含める")

            PromptComponent.constraint("事実と推測を明確に区別すること")
            PromptComponent.constraint("情報源が確認できない情報は、その旨を明記すること")

            PromptComponent.important("最終的な出力は必ず ResearchReport の構造に従った JSON 形式で返すこと")
            PromptComponent.important("keyFindings は具体的で actionable な項目を 3〜5 個含めること")
            PromptComponent.important("情報の信頼度（confidenceLevel）は、情報源の数と質に基づいて適切に設定すること")
        }
    }

    // MARK: - Sample Scenarios

    static let sampleScenarios: [SampleScenario] = [
        SampleScenario(
            name: "最新技術調査",
            prompt: "最新のSwift Concurrency（async/await）の機能と使い方について調べて、初心者向けにわかりやすくまとめたレポートを作成してください。",
            description: "技術情報を検索し、複数のソースから情報を集めてレポートを生成"
        ),
        SampleScenario(
            name: "ニュース調査",
            prompt: "人工知能（AI）の最新ニュースを調べて、今注目されているトピックとその影響についてまとめたレポートを作成してください。",
            description: "Web検索でニュースを収集し、トレンドを分析"
        ),
        SampleScenario(
            name: "総合リサーチ",
            prompt: "「サステナブルな生活」について調べて、具体的な実践方法と最新のトレンドをまとめてください。情報源も明記してください。",
            description: "Web検索とページ取得を組み合わせた深い調査"
        )
    ]
}
