//
//  CalculationScenario.swift
//  AgentExample
//
//  計算シナリオの定義
//  カテゴリ情報・プロンプト・サンプルシナリオを一箇所で管理
//

import Foundation
import LLMStructuredOutputs

// MARK: - Calculation Scenario

/// 計算シナリオ
///
/// 数学的計算と単位変換に特化したシナリオ。
/// 計算ツールを使用して正確な結果を提供します。
enum CalculationScenario: AgentScenarioType {
    typealias Output = CalculationReport

    // MARK: - Meta Information

    static let id = "calculation"
    static let displayName = "計算"
    static let icon = "function"
    static let description = "数学的計算・変換"

    // MARK: - System Prompt

    static func systemPrompt() -> Prompt {
        Prompt {
            PromptComponent.role("正確な計算と数値分析を行う数学アシスタントです")

            PromptComponent.expertise("四則演算と複雑な数式計算")
            PromptComponent.expertise("単位変換")
            PromptComponent.expertise("端数処理と丸め計算")

            PromptComponent.behavior("計算は必ずツールを使用して正確に行う")
            PromptComponent.behavior("計算過程を明確に説明する")

            PromptComponent.objective("ユーザーの計算依頼に対して、計算ツールを使用して正確な結果を提供し、計算過程を含めた構造化レポートを作成する")

            PromptComponent.instruction("複数の計算がある場合は、一つずつ順番に計算ツールを使用する")
            PromptComponent.instruction("単位変換が必要な場合は単位変換ツールを使用する")
            PromptComponent.instruction("各計算ステップの結果と説明を記録する")

            PromptComponent.constraint("暗算や推測で計算しないこと、必ず計算ツールを使用すること")
            PromptComponent.constraint("計算結果の単位を明確にすること")

            PromptComponent.important("最終的な出力は必ず CalculationReport の構造に従った JSON 形式で返すこと")
            PromptComponent.important("steps には各計算ステップの式(expression)、結果(result)、補足(note)を含めること")
        }
    }

    // MARK: - Sample Scenarios

    static let sampleScenarios: [SampleScenario] = [
        SampleScenario(
            name: "複合計算",
            prompt: "以下の計算を行って結果をまとめてください：(1) 123 × 456、(2) 1000 ÷ 7（小数点以下4桁まで）、(3) (25 + 75) × 3",
            description: "複数の四則演算を順番に実行"
        ),
        SampleScenario(
            name: "単位変換計算",
            prompt: "マラソンの距離は42.195kmです。これをマイルに変換し、時速10kmで走った場合の所要時間を計算してください。",
            description: "単位変換と時間計算の組み合わせ"
        ),
        SampleScenario(
            name: "割り勘計算",
            prompt: "飲み会の合計金額が27,350円で、参加者が7人です。1人あたりの金額と、端数を幹事が負担する場合の幹事の支払額を計算してください。",
            description: "割り算と端数処理の計算"
        )
    ]
}
