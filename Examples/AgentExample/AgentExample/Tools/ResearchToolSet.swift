//
//  ResearchToolSet.swift
//  AgentExample
//
//  リサーチエージェント用ツールセット
//

import Foundation
import LLMStructuredOutputs

/// リサーチエージェント用ツールセット
///
/// Web検索、ページ取得、天気、計算、時刻取得の5つのツールを提供します。
enum ResearchToolSet {

    /// すべてのツールを含むToolSetを作成
    static var tools: ToolSet {
        ToolSet {
            WebSearchTool.self
            FetchWebPageTool.self
            WeatherTool.self
            CalculatorTool.self
            CurrentTimeTool.self
        }
    }

    /// ツールの説明一覧（UI表示用）
    static let descriptions: [(name: String, description: String, icon: String)] = [
        ("web_search_tool", "Webを検索", "magnifyingglass"),
        ("fetch_web_page", "Webページを取得", "doc.text"),
        ("get_weather", "天気情報を取得", "cloud.sun.fill"),
        ("calculator", "数式を計算", "function"),
        ("get_current_time", "現在時刻を取得", "clock.fill")
    ]

    /// ツールが利用可能かどうか
    static var isWebSearchAvailable: Bool {
        APIKeyManager.hasBraveSearchKey
    }

    /// 利用可能なツールの数
    static var availableToolCount: Int {
        // WebSearchToolはAPIキーが必要、それ以外は常に利用可能
        isWebSearchAvailable ? 5 : 4
    }

    /// ツールセットの状態を取得
    static var status: ToolSetStatus {
        ToolSetStatus(
            webSearchAvailable: isWebSearchAvailable,
            webFetchAvailable: true,
            weatherAvailable: true,
            calculatorAvailable: true,
            currentTimeAvailable: true
        )
    }
}

// MARK: - ToolSet Status

extension ResearchToolSet {
    struct ToolSetStatus {
        let webSearchAvailable: Bool
        let webFetchAvailable: Bool
        let weatherAvailable: Bool
        let calculatorAvailable: Bool
        let currentTimeAvailable: Bool

        var allAvailable: Bool {
            webSearchAvailable && webFetchAvailable && weatherAvailable && calculatorAvailable && currentTimeAvailable
        }

        var availableCount: Int {
            [webSearchAvailable, webFetchAvailable, weatherAvailable, calculatorAvailable, currentTimeAvailable]
                .filter { $0 }.count
        }
    }
}
