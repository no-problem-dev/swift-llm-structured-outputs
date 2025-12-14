//
//  ComparisonTestCases.swift
//  LLMStructuredOutputsExample
//
//  プロバイダー比較用テストケース定義
//

import Foundation
import LLMStructuredOutputs

// MARK: - Test Case Category

/// テストケースのカテゴリ
enum TestCaseCategory: String, CaseIterable, Identifiable {
    case extraction = "情報抽出"
    case reasoning = "推論"
    case structure = "構造"
    case quality = "品質"
    case language = "言語"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .extraction: return "doc.text.magnifyingglass"
        case .reasoning: return "brain"
        case .structure: return "rectangle.3.group"
        case .quality: return "checkmark.seal"
        case .language: return "globe"
        }
    }
}

// MARK: - Comparison Test Case

/// 比較テストケース
struct ComparisonTestCase: Identifiable {
    let id: String
    let category: TestCaseCategory
    let title: String
    let description: String
    let input: String
    let systemPrompt: String
    let outputType: OutputType
    let expectedFields: [String: ExpectedValue]?

    /// 出力タイプ
    enum OutputType {
        case landmark
        case person
        case product
        case meeting
        case calculation
        case organization
        case recipe
        case event
    }

    /// 期待値
    enum ExpectedValue: Equatable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case contains(String)
        case notNil
        case isNil
    }
}

// MARK: - Test Cases Data

extension ComparisonTestCase {

    /// 全テストケース
    static let allCases: [ComparisonTestCase] = [
        // MARK: - 情報抽出カテゴリ

        // 1. 基本情報抽出
        basicLandmarkExtraction,

        // 2. 数値データ抽出
        numericDataExtraction,

        // 3. 人物情報抽出
        personExtraction,

        // MARK: - 推論カテゴリ

        // 4. 簡単な推論
        simpleReasoning,

        // 5. 算術推論
        mathReasoning,

        // 6. 時間推論
        timeReasoning,

        // MARK: - 構造カテゴリ

        // 7. ネスト構造
        nestedStructure,

        // 8. 配列抽出
        arrayExtraction,

        // MARK: - 品質カテゴリ

        // 9. 曖昧な入力
        ambiguousInput,

        // 10. 欠損情報
        missingInfo,

        // 11. ハルシネーション耐性
        hallucinationTest,

        // MARK: - 言語カテゴリ

        // 12. 英語
        englishExtraction,

        // 13. 多言語混在
        mixedLanguage,

        // 14. 長文処理
        longTextExtraction,
    ]

    /// カテゴリごとのテストケース
    static func cases(for category: TestCaseCategory) -> [ComparisonTestCase] {
        allCases.filter { $0.category == category }
    }

    // MARK: - 情報抽出テストケース

    static let basicLandmarkExtraction = ComparisonTestCase(
        id: "basic_landmark",
        category: .extraction,
        title: "基本情報抽出",
        description: "ランドマークの基本情報を正確に抽出できるか",
        input: """
        東京スカイツリーは2012年5月に開業した電波塔で、高さは634メートルです。
        墨田区押上に位置し、年間約400万人が訪れる人気観光スポットです。
        """,
        systemPrompt: "テキストからランドマーク情報を抽出してください。",
        outputType: .landmark,
        expectedFields: [
            "name": .string("東京スカイツリー"),
            "establishedYear": .int(2012),
            "location": .contains("墨田区"),
        ]
    )

    static let numericDataExtraction = ComparisonTestCase(
        id: "numeric_data",
        category: .extraction,
        title: "数値データ抽出",
        description: "複数の数値データを正確に抽出できるか",
        input: """
        富士山は標高3,776メートルで日本最高峰です。
        山梨県と静岡県にまたがり、2013年に世界文化遺産に登録されました。
        年間約30万人が登山に訪れ、登山シーズンは7月から9月です。
        """,
        systemPrompt: "テキストからランドマーク情報を抽出してください。数値データは正確に抽出すること。",
        outputType: .landmark,
        expectedFields: [
            "name": .string("富士山"),
            "establishedYear": .int(2013),
        ]
    )

    static let personExtraction = ComparisonTestCase(
        id: "person_info",
        category: .extraction,
        title: "人物情報抽出",
        description: "人物の属性情報を正確に抽出できるか",
        input: """
        田中一郎さん（42歳）は株式会社テクノロジーズの代表取締役社長です。
        東京大学工学部を卒業後、2005年に同社を設立しました。
        趣味はゴルフと読書で、座右の銘は「継続は力なり」です。
        """,
        systemPrompt: "テキストから人物情報を抽出してください。",
        outputType: .person,
        expectedFields: [
            "name": .string("田中一郎"),
            "age": .int(42),
            "company": .contains("テクノロジーズ"),
        ]
    )

    // MARK: - 推論テストケース

    static let simpleReasoning = ComparisonTestCase(
        id: "simple_reasoning",
        category: .reasoning,
        title: "簡単な推論",
        description: "テキストから暗黙の情報を推論できるか",
        input: """
        山田商店は1985年に創業し、今年で創業40周年を迎えます。
        現在は3代目の山田健太が社長を務めています。
        従業員数は創業時の5名から現在は120名に成長しました。
        """,
        systemPrompt: "テキストから組織情報を抽出してください。現在の年は計算して推論すること。",
        outputType: .organization,
        expectedFields: [
            "name": .string("山田商店"),
            "establishedYear": .int(1985),
        ]
    )

    static let mathReasoning = ComparisonTestCase(
        id: "math_reasoning",
        category: .reasoning,
        title: "算術推論",
        description: "計算を伴う情報抽出ができるか",
        input: """
        このカフェのランチセットは、メイン料理800円、サラダ200円、ドリンク150円の
        セットで、通常なら合計1,150円のところ、セット割引で980円になります。
        さらに毎週水曜日は10%オフになります。
        """,
        systemPrompt: "テキストから商品・価格情報を抽出してください。割引額も計算すること。",
        outputType: .product,
        expectedFields: [
            "name": .contains("ランチセット"),
        ]
    )

    static let timeReasoning = ComparisonTestCase(
        id: "time_reasoning",
        category: .reasoning,
        title: "時間推論",
        description: "時間に関する推論ができるか",
        input: """
        会議は14:00から始まり、各議題に30分ずつ割り当てられています。
        今日の議題は「予算報告」「新製品企画」「人事異動」の3つです。
        休憩なしで進行する予定です。
        """,
        systemPrompt: "テキストから会議情報を抽出してください。終了時刻も推論すること。",
        outputType: .meeting,
        expectedFields: [
            "startTime": .contains("14:00"),
        ]
    )

    // MARK: - 構造テストケース

    static let nestedStructure = ComparisonTestCase(
        id: "nested_structure",
        category: .structure,
        title: "ネスト構造",
        description: "階層構造のあるデータを正確に抽出できるか",
        input: """
        株式会社ABCホールディングス
        ├── ABC商事（従業員200名、売上50億円）
        │   ├── 営業部
        │   └── 企画部
        ├── ABCテクノロジー（従業員150名、売上30億円）
        │   ├── 開発部
        │   └── 運用部
        └── ABCサービス（従業員80名、売上15億円）
            └── カスタマーサポート部
        """,
        systemPrompt: "テキストから組織の階層構造を抽出してください。",
        outputType: .organization,
        expectedFields: [
            "name": .contains("ABCホールディングス"),
        ]
    )

    static let arrayExtraction = ComparisonTestCase(
        id: "array_extraction",
        category: .structure,
        title: "配列抽出",
        description: "複数の同種データを配列として抽出できるか",
        input: """
        本日のおすすめメニュー:
        1. 黒毛和牛ステーキ - 3,500円（数量限定10食）
        2. 季節の天ぷら盛り合わせ - 1,800円
        3. 特製海鮮丼 - 2,200円（ランチタイム限定）
        4. 手打ちそば - 900円
        5. 抹茶パフェ - 650円（デザート）
        """,
        systemPrompt: "テキストからメニュー情報をすべて抽出してください。",
        outputType: .product,
        expectedFields: nil
    )

    // MARK: - 品質テストケース

    static let ambiguousInput = ComparisonTestCase(
        id: "ambiguous_input",
        category: .quality,
        title: "曖昧な入力",
        description: "曖昧な表現をどう解釈するか",
        input: """
        新しくオープンしたカフェ「モーニングブリーズ」は駅から歩いてすぐの場所にあります。
        店内は広々としていて、数十席ほどあるようです。
        価格帯はリーズナブルで、コーヒーは数百円程度です。
        """,
        systemPrompt: "テキストから店舗情報を抽出してください。曖昧な情報は「不明」と明記すること。",
        outputType: .landmark,
        expectedFields: [
            "name": .contains("モーニングブリーズ"),
        ]
    )

    static let missingInfo = ComparisonTestCase(
        id: "missing_info",
        category: .quality,
        title: "欠損情報の処理",
        description: "情報が欠けている場合の処理が適切か",
        input: """
        佐藤さんは現在フリーランスとして活動しています。
        以前は大手IT企業に勤めていました。
        """,
        systemPrompt: "テキストから人物情報を抽出してください。記載のない情報はnullにすること。",
        outputType: .person,
        expectedFields: [
            "name": .contains("佐藤"),
            "age": .isNil,
            "email": .isNil,
        ]
    )

    static let hallucinationTest = ComparisonTestCase(
        id: "hallucination",
        category: .quality,
        title: "ハルシネーション耐性",
        description: "存在しない情報を生成しないか",
        input: """
        東京タワーは1958年に完成した電波塔です。
        高さは333メートルで、港区芝公園に位置しています。
        """,
        systemPrompt: """
        テキストからランドマーク情報を抽出してください。
        【重要】テキストに明記されていない情報は絶対に推測・補完しないでください。
        記載のない項目はnullにしてください。
        """,
        outputType: .landmark,
        expectedFields: [
            "name": .string("東京タワー"),
            "establishedYear": .int(1958),
            // 年間来場者数などは記載がないのでnullであるべき
        ]
    )

    // MARK: - 言語テストケース

    static let englishExtraction = ComparisonTestCase(
        id: "english",
        category: .language,
        title: "英語",
        description: "英語テキストからの抽出精度",
        input: """
        The Empire State Building is a 102-story Art Deco skyscraper in Midtown Manhattan, New York City.
        It was designed by Shreve, Lamb & Harmon and built from 1930 to 1931.
        The building has a roof height of 1,250 feet (380 m) and stands a total of 1,454 feet (443.2 m) tall.
        It attracts approximately 4 million visitors annually.
        """,
        systemPrompt: "Extract landmark information from the text. Respond in Japanese.",
        outputType: .landmark,
        expectedFields: [
            "name": .contains("Empire State"),
            "establishedYear": .int(1931),
        ]
    )

    static let mixedLanguage = ComparisonTestCase(
        id: "mixed_language",
        category: .language,
        title: "多言語混在",
        description: "日英混在テキストからの抽出精度",
        input: """
        Appleの最新製品「iPhone 15 Pro Max」が発売されました。
        価格は189,800円（税込）からで、storageは256GB/512GB/1TBの3種類。
        新機能のAction Buttonや、A17 Proチップを搭載しています。
        Available colors: Natural Titanium, Blue Titanium, White Titanium, Black Titanium
        """,
        systemPrompt: "テキストから製品情報を抽出してください。",
        outputType: .product,
        expectedFields: [
            "name": .contains("iPhone 15 Pro Max"),
        ]
    )

    static let longTextExtraction = ComparisonTestCase(
        id: "long_text",
        category: .language,
        title: "長文処理",
        description: "長文からの重要情報抽出",
        input: """
        京都の金閣寺（正式名称：鹿苑寺）は、室町時代の1397年に足利義満によって建立された禅寺です。
        金閣寺という通称は、舎利殿の外壁が金箔で覆われていることに由来します。

        この寺院は、北山文化を代表する建築物として知られ、1994年にユネスコ世界文化遺産に登録されました。
        庭園は特別名勝および特別史跡に指定されており、鏡湖池に映る金閣の姿は「逆さ金閣」として有名です。

        金閣は1950年に放火により全焼しましたが、1955年に再建されました。
        その後、1987年には金箔の全面張り替え工事が行われ、現在の輝きを取り戻しています。

        拝観時間は9:00から17:00まで、拝観料は大人500円です。
        年間約500万人の観光客が訪れる、京都を代表する観光スポットとなっています。

        アクセスは、京都駅からバスで約40分、金閣寺道バス停下車すぐです。
        周辺には龍安寺や仁和寺など、他の世界遺産も点在しています。
        """,
        systemPrompt: "テキストからランドマークの主要情報を抽出してください。重要な情報を漏らさないこと。",
        outputType: .landmark,
        expectedFields: [
            "name": .contains("金閣寺"),
            "establishedYear": .int(1397),
            "location": .contains("京都"),
        ]
    )
}
