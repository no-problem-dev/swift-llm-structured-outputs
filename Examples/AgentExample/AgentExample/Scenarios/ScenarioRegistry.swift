//
//  ScenarioRegistry.swift
//  AgentExample
//
//  全シナリオの静的レジストリ
//  UI表示用にシナリオ情報を提供
//

import Foundation

// MARK: - Scenario Registry

/// シナリオレジストリ
///
/// 全シナリオタイプを管理し、UI表示用のメタ情報を提供します。
/// 新しいシナリオを追加する場合は `allScenarios` に追加するだけで完了します。
enum ScenarioRegistry {

    // MARK: - All Scenarios

    /// 全シナリオ情報のリスト
    ///
    /// 新しいシナリオを追加する場合はここに追加してください。
    static let allScenarios: [ScenarioInfo] = [
        ScenarioInfo(ResearchScenario.self),
        ScenarioInfo(CalculationScenario.self),
        ScenarioInfo(TemporalScenario.self),
        ScenarioInfo(MultiToolScenario.self),
        ScenarioInfo(ReasoningScenario.self)
    ]

    // MARK: - Lookup

    /// IDでシナリオ情報を取得
    static func scenario(for id: String) -> ScenarioInfo? {
        allScenarios.first { $0.id == id }
    }

    /// 指定IDのサンプルシナリオを取得
    static func sampleScenarios(for id: String) -> [SampleScenario] {
        scenario(for: id)?.sampleScenarios ?? []
    }
}

// MARK: - Agent Result

/// エージェント結果（全カテゴリ統合）
///
/// 各シナリオの出力型をラップして統一的に扱うための列挙型。
enum AgentResult: Equatable, Sendable {
    case research(ResearchReport)
    case calculation(CalculationReport)
    case temporal(TemporalReport)
    case multiTool(MultiToolReport)
    case reasoning(ReasoningReport)

    /// レポートのタイトル
    var title: String {
        switch self {
        case .research(let r): return r.title
        case .calculation(let r): return r.title
        case .temporal(let r): return r.title
        case .multiTool(let r): return r.title
        case .reasoning(let r): return r.title
        }
    }

    /// シナリオID
    var scenarioID: String {
        switch self {
        case .research: return ResearchScenario.id
        case .calculation: return CalculationScenario.id
        case .temporal: return TemporalScenario.id
        case .multiTool: return MultiToolScenario.id
        case .reasoning: return ReasoningScenario.id
        }
    }
}
