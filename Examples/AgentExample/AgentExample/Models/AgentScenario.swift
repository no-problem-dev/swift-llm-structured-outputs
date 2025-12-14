//
//  AgentScenario.swift
//  AgentExample
//
//  エージェントシナリオ定義
//

import Foundation

// MARK: - Scenario Category

/// シナリオカテゴリ
enum ScenarioCategory: String, CaseIterable, Identifiable {
    case research = "リサーチ"
    case calculation = "計算"
    case temporal = "時間"
    case multiTool = "複合"
    case reasoning = "推論"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .research: return "magnifyingglass"
        case .calculation: return "function"
        case .temporal: return "clock"
        case .multiTool: return "square.stack.3d.up"
        case .reasoning: return "brain"
        }
    }

    var description: String {
        switch self {
        case .research: return "Web検索・情報収集"
        case .calculation: return "数学的計算・変換"
        case .temporal: return "日時・タイムゾーン"
        case .multiTool: return "複数ツール連携"
        case .reasoning: return "論理的推論"
        }
    }
}

// MARK: - Agent Scenario

/// エージェントシナリオ
struct AgentScenario: Identifiable {
    let id = UUID()
    let name: String
    let prompt: String
    let description: String
    let category: ScenarioCategory

    /// カテゴリ別にシナリオを取得
    static func scenarios(for category: ScenarioCategory) -> [AgentScenario] {
        allScenarios.filter { $0.category == category }
    }

    /// 全シナリオ
    static let allScenarios: [AgentScenario] = [
        // MARK: リサーチ
        AgentScenario(
            name: "最新技術調査",
            prompt: "最新のSwift Concurrency（async/await）の機能と使い方について調べて、初心者向けにわかりやすくまとめたレポートを作成してください。",
            description: "技術情報を検索し、複数のソースから情報を集めてレポートを生成",
            category: .research
        ),
        AgentScenario(
            name: "ニュース調査",
            prompt: "人工知能（AI）の最新ニュースを調べて、今注目されているトピックとその影響についてまとめたレポートを作成してください。",
            description: "Web検索でニュースを収集し、トレンドを分析",
            category: .research
        ),
        AgentScenario(
            name: "総合リサーチ",
            prompt: "「サステナブルな生活」について調べて、具体的な実践方法と最新のトレンドをまとめてください。情報源も明記してください。",
            description: "Web検索とページ取得を組み合わせた深い調査",
            category: .research
        ),

        // MARK: 計算
        AgentScenario(
            name: "複合計算",
            prompt: "以下の計算を行って結果をまとめてください：(1) 123 × 456、(2) 1000 ÷ 7（小数点以下4桁まで）、(3) (25 + 75) × 3",
            description: "複数の四則演算を順番に実行",
            category: .calculation
        ),
        AgentScenario(
            name: "単位変換計算",
            prompt: "マラソンの距離は42.195kmです。これをマイルに変換し、時速10kmで走った場合の所要時間を計算してください。",
            description: "単位変換と時間計算の組み合わせ",
            category: .calculation
        ),
        AgentScenario(
            name: "割り勘計算",
            prompt: "飲み会の合計金額が27,350円で、参加者が7人です。1人あたりの金額と、端数を幹事が負担する場合の幹事の支払額を計算してください。",
            description: "割り算と端数処理の計算",
            category: .calculation
        ),

        // MARK: 時間
        AgentScenario(
            name: "世界時計",
            prompt: "Tokyo、New York、London、Sydneyの現在時刻をそれぞれ取得して、一覧表示してください。",
            description: "複数タイムゾーンの時刻を取得",
            category: .temporal
        ),
        AgentScenario(
            name: "会議時間調整",
            prompt: "日本時間の午前10時にオンライン会議を設定したいです。New York、London、Singaporeの参加者にとって、それぞれ何時になるか確認してください。",
            description: "タイムゾーン間の時刻変換",
            category: .temporal
        ),

        // MARK: 複合
        AgentScenario(
            name: "都市比較",
            prompt: "TokyoとNew Yorkの現在の天気を調べて比較し、今週末に観光するならどちらがおすすめか、天気と時差を考慮してレポートにまとめてください。",
            description: "天気APIと時刻取得を組み合わせた比較分析",
            category: .multiTool
        ),
        AgentScenario(
            name: "旅行プランニング",
            prompt: "Parisへの旅行を計画しています。現在のParisの天気と時刻を確認し、1ユーロ=160円として、1日の予算5万円で何ユーロ使えるか計算してください。",
            description: "天気・時刻・計算を組み合わせた旅行計画",
            category: .multiTool
        ),
        AgentScenario(
            name: "スポーツイベント調査",
            prompt: "次のオリンピックについてWeb検索で情報を調べ、開催地の現在の天気と、日本との時差を確認してまとめてください。",
            description: "Web検索・天気・時刻の複合利用",
            category: .multiTool
        ),

        // MARK: 推論
        AgentScenario(
            name: "数列推論",
            prompt: "次の数列の規則性を見つけて、次の3つの数を予測してください：2, 6, 12, 20, 30, ?。計算ツールを使って検証もしてください。",
            description: "パターン認識と検証計算",
            category: .reasoning
        ),
        AgentScenario(
            name: "論理パズル",
            prompt: "3人の友人A、B、Cがいます。Aの年齢はBの2倍、BとCの年齢の合計は30歳、AとCの年齢差は5歳です。それぞれの年齢を求めてください。",
            description: "連立方程式的な論理問題",
            category: .reasoning
        ),
        AgentScenario(
            name: "比較分析",
            prompt: "りんご3個で450円、みかん5個で400円です。それぞれ1個あたりの価格を計算し、1000円でどちらをいくつ買えるか比較分析してください。",
            description: "単価計算と比較推論",
            category: .reasoning
        )
    ]
}
