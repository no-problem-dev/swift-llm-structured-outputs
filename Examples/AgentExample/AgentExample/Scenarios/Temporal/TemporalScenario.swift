//
//  TemporalScenario.swift
//  AgentExample
//
//  時間シナリオの定義
//  カテゴリ情報・プロンプト・サンプルシナリオを一箇所で管理
//

import Foundation
import LLMStructuredOutputs

// MARK: - Temporal Scenario

/// 時間シナリオ
///
/// 時刻とタイムゾーンに特化したシナリオ。
/// 世界各地の時刻取得やタイムゾーン変換を行います。
enum TemporalScenario: AgentScenarioType {
    typealias Output = TemporalReport

    // MARK: - Meta Information

    static let id = "temporal"
    static let displayName = "時間"
    static let icon = "clock"
    static let description = "日時・タイムゾーン"

    // MARK: - System Prompt

    static func systemPrompt() -> Prompt {
        Prompt {
            PromptComponent.role("世界各地の時刻とタイムゾーンの専門家です")

            PromptComponent.expertise("タイムゾーン変換")
            PromptComponent.expertise("世界各都市の現在時刻取得")
            PromptComponent.expertise("国際会議の時間調整")

            PromptComponent.behavior("時刻情報は必ずツールを使用して取得する")
            PromptComponent.behavior("タイムゾーンの略称と UTC オフセットを明記する")

            PromptComponent.objective("ユーザーの時刻に関する依頼に対して、時刻取得ツールを使用して正確な情報を提供し、構造化レポートを作成する")

            PromptComponent.instruction("各都市の時刻を取得する際は、現在時刻取得ツールを使用する")
            PromptComponent.instruction("タイムゾーンの変換や比較を行う際は、UTC を基準にする")
            PromptComponent.instruction("夏時間（DST）の影響がある場合は明記する")

            PromptComponent.constraint("推測で時刻を答えないこと、必ずツールで確認すること")

            PromptComponent.important("最終的な出力は必ず TemporalReport の構造に従った JSON 形式で返すこと")
            PromptComponent.important("timeInfos には各都市の location, dateTime, timezone, offsetFromUTC を含めること")
        }
    }

    // MARK: - Sample Scenarios

    static let sampleScenarios: [SampleScenario] = [
        SampleScenario(
            name: "世界時計",
            prompt: "Tokyo、New York、London、Sydneyの現在時刻をそれぞれ取得して、一覧表示してください。",
            description: "複数タイムゾーンの時刻を取得"
        ),
        SampleScenario(
            name: "会議時間調整",
            prompt: "日本時間の午前10時にオンライン会議を設定したいです。New York、London、Singaporeの参加者にとって、それぞれ何時になるか確認してください。",
            description: "タイムゾーン間の時刻変換"
        )
    ]
}
