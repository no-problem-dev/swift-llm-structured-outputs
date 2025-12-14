//
//  ResearchToolSet.swift
//  AgentExample
//
//  リサーチエージェント用ツールセット
//

import Foundation
import LLMStructuredOutputs

/// エージェント用ツールセット
///
/// Web検索、ページ取得、天気、計算、時刻取得、単位変換、文字列操作、乱数生成の8つのツールを提供します。
/// ToolConfigurationと連携して、ユーザーが選択したツールのみを含むToolSetを生成できます。
enum ResearchToolSet {

    // MARK: - ToolSet Creation

    /// すべてのツールを含むToolSetを作成
    static var allTools: ToolSet {
        ToolSet {
            WebSearchTool.self
            FetchWebPageTool.self
            WeatherTool.self
            CalculatorTool.self
            CurrentTimeTool.self
            UnitConverterTool.self
            StringManipulationTool.self
            RandomGeneratorTool.self
        }
    }

    /// 後方互換性のためのエイリアス
    @MainActor
    static var tools: ToolSet {
        configuredTools
    }

    /// ToolConfigurationに基づいて選択されたツールのみを含むToolSetを作成
    @MainActor
    static var configuredTools: ToolSet {
        let config = ToolConfiguration.shared
        return buildToolSet(enabledTools: config.enabledTools)
    }

    /// 指定されたツール識別子のセットからToolSetを作成
    static func buildToolSet(enabledTools: Set<ToolIdentifier>) -> ToolSet {
        var toolSet = ToolSet()

        for tool in enabledTools {
            // APIキー要件を満たさないツールはスキップ
            guard tool.isAvailable else { continue }

            switch tool {
            case .webSearch:
                toolSet = toolSet.appending(WebSearchTool.self)
            case .fetchWebPage:
                toolSet = toolSet.appending(FetchWebPageTool.self)
            case .weather:
                toolSet = toolSet.appending(WeatherTool.self)
            case .calculator:
                toolSet = toolSet.appending(CalculatorTool.self)
            case .currentTime:
                toolSet = toolSet.appending(CurrentTimeTool.self)
            case .unitConverter:
                toolSet = toolSet.appending(UnitConverterTool.self)
            case .stringManipulation:
                toolSet = toolSet.appending(StringManipulationTool.self)
            case .randomGenerator:
                toolSet = toolSet.appending(RandomGeneratorTool.self)
            }
        }

        return toolSet
    }

    // MARK: - Legacy Support (Deprecated)

    /// ツールの説明一覧（UI表示用）
    /// - Note: ToolIdentifierを直接使用することを推奨
    @available(*, deprecated, message: "Use ToolIdentifier.allCases instead")
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
        isWebSearchAvailable ? 8 : 7
    }

    /// ツールセットの状態を取得
    static var status: ToolSetStatus {
        ToolSetStatus(
            webSearchAvailable: isWebSearchAvailable,
            webFetchAvailable: true,
            weatherAvailable: true,
            calculatorAvailable: true,
            currentTimeAvailable: true,
            unitConverterAvailable: true,
            stringManipulationAvailable: true,
            randomGeneratorAvailable: true
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
        let unitConverterAvailable: Bool
        let stringManipulationAvailable: Bool
        let randomGeneratorAvailable: Bool

        var allAvailable: Bool {
            webSearchAvailable && webFetchAvailable && weatherAvailable &&
            calculatorAvailable && currentTimeAvailable && unitConverterAvailable &&
            stringManipulationAvailable && randomGeneratorAvailable
        }

        var availableCount: Int {
            [webSearchAvailable, webFetchAvailable, weatherAvailable, calculatorAvailable,
             currentTimeAvailable, unitConverterAvailable, stringManipulationAvailable, randomGeneratorAvailable]
                .filter { $0 }.count
        }
    }
}
