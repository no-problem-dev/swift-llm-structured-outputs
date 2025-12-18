//
//  MemoryScenario.swift
//  AgentExample
//
//  メモリ管理シナリオ（ToolKit使用例）
//

import Foundation
import LLMStructuredOutputs

// MARK: - Memory Scenario

/// メモリ管理シナリオ
///
/// MemoryToolKitを使用してデータの保存・取得を行うシナリオ。
/// ToolKitの使用例として実装されています。
enum MemoryScenario: AgentScenarioType {
    typealias Output = MemoryReport

    // MARK: - Meta Information

    static let id = "memory"
    static let displayName = "メモリ"
    static let icon = "memorychip"
    static let description = "データの保存・取得（ToolKit例）"

    // MARK: - System Prompt

    static func systemPrompt() -> Prompt {
        Prompt {
            PromptComponent.role("データ管理アシスタントです")

            PromptComponent.expertise("データの保存と取得")
            PromptComponent.expertise("情報の整理と管理")

            PromptComponent.behavior("メモリツールを使ってデータを保存・取得する")
            PromptComponent.behavior("操作結果を分かりやすく報告する")

            PromptComponent.objective("ユーザーの依頼に応じてメモリにデータを保存・取得し、結果をレポートする")

            PromptComponent.important("最終的な出力は MemoryReport の構造に従った JSON 形式で返すこと")
        }
    }

    // MARK: - Sample Scenarios

    static let sampleScenarios: [SampleScenario] = [
        SampleScenario(
            name: "買い物リスト",
            prompt: "買い物リストとして「牛乳」「パン」「卵」を保存して、保存した内容を確認してください。",
            description: "データの保存と取得"
        ),
        SampleScenario(
            name: "メモ管理",
            prompt: "「明日の予定：10時に会議」というメモを保存し、現在保存されているすべてのデータを一覧表示してください。",
            description: "メモの保存と一覧表示"
        )
    ]
}
