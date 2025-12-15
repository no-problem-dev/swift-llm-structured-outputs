//
//  ReasoningScenario.swift
//  AgentExample
//
//  推論シナリオの定義
//  カテゴリ情報・プロンプト・サンプルシナリオを一箇所で管理
//

import Foundation
import LLMStructuredOutputs

// MARK: - Reasoning Scenario

/// 推論シナリオ
///
/// 論理的推論と問題解決に特化したシナリオ。
/// パターン認識、論理パズル、比較分析などを行います。
enum ReasoningScenario: AgentScenarioType {
    typealias Output = ReasoningReport

    // MARK: - Meta Information

    static let id = "reasoning"
    static let displayName = "推論"
    static let icon = "brain"
    static let description = "論理的推論"

    // MARK: - System Prompt

    static func systemPrompt() -> Prompt {
        Prompt {
            PromptComponent.role("論理的推論と問題解決の専門家です")

            PromptComponent.expertise("パターン認識と数列分析")
            PromptComponent.expertise("論理パズルの解決")
            PromptComponent.expertise("比較分析と意思決定支援")

            PromptComponent.behavior("問題を段階的に分析し、推論過程を明確にする")
            PromptComponent.behavior("仮説を立てて検証する")
            PromptComponent.behavior("計算が必要な場合はツールを使用して検証する")

            PromptComponent.objective("ユーザーの推論・分析依頼に対して、論理的な思考過程を示しながら、計算ツールで検証した結論を含む構造化レポートを作成する")

            PromptComponent.instruction("まず問題を明確に理解し、前提条件を整理する")
            PromptComponent.instruction("推論を段階的に進め、各ステップの根拠を明記する")
            PromptComponent.instruction("数値的な検証が可能な場合は計算ツールを使用する")
            PromptComponent.instruction("最終的な結論と、その導出過程を明確に示す")

            PromptComponent.constraint("論理の飛躍がないようにすること")
            PromptComponent.constraint("前提条件を明確にすること")

            PromptComponent.important("最終的な出力は必ず ReasoningReport の構造に従った JSON 形式で返すこと")
            PromptComponent.important("reasoningSteps に各推論ステップの stepNumber, reasoning, intermediateResult を含めること")
            PromptComponent.important("verification に計算ツールによる検証結果を含めること（検証した場合）")
        }
    }

    // MARK: - Sample Scenarios

    static let sampleScenarios: [SampleScenario] = [
        SampleScenario(
            name: "数列推論",
            prompt: "次の数列の規則性を見つけて、次の3つの数を予測してください：2, 6, 12, 20, 30, ?。計算ツールを使って検証もしてください。",
            description: "パターン認識と検証計算"
        ),
        SampleScenario(
            name: "論理パズル",
            prompt: "3人の友人A、B、Cがいます。Aの年齢はBの2倍、BとCの年齢の合計は30歳、AとCの年齢差は5歳です。それぞれの年齢を求めてください。",
            description: "連立方程式的な論理問題"
        ),
        SampleScenario(
            name: "比較分析",
            prompt: "りんご3個で450円、みかん5個で400円です。それぞれ1個あたりの価格を計算し、1000円でどちらをいくつ買えるか比較分析してください。",
            description: "単価計算と比較推論"
        )
    ]
}
