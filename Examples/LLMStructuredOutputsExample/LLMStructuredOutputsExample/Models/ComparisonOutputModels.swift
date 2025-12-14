//
//  ComparisonOutputModels.swift
//  LLMStructuredOutputsExample
//
//  プロバイダー比較用出力モデル定義
//

import Foundation
import LLMStructuredOutputs

// MARK: - Landmark Output

/// ランドマーク情報（比較用）
@Structured("ランドマーク・施設情報")
struct LandmarkOutput: Equatable {
    @StructuredField("名称")
    var name: String

    @StructuredField("種類（電波塔、寺院、ビル、山など）")
    var type: String

    @StructuredField("所在地")
    var location: String?

    @StructuredField("設立/開業/完成年（西暦）")
    var establishedYear: Int?

    @StructuredField("高さ（メートル）")
    var heightMeters: Double?

    @StructuredField("年間来場者数")
    var annualVisitors: Int?

    @StructuredField("世界遺産登録年")
    var worldHeritageYear: Int?

    @StructuredField("特徴的な数値データ")
    var keyFigures: [KeyFigureOutput]?

    @StructuredField("説明（100文字以内）", .maxLength(100))
    var summary: String
}

/// 数値情報
@Structured("数値データ")
struct KeyFigureOutput: Equatable {
    @StructuredField("項目名")
    var label: String

    @StructuredField("値")
    var value: String

    @StructuredField("単位")
    var unit: String?
}

// MARK: - Person Output

/// 人物情報（比較用）
@Structured("人物情報")
struct PersonOutput: Equatable {
    @StructuredField("氏名")
    var name: String

    @StructuredField("年齢")
    var age: Int?

    @StructuredField("職業・役職")
    var occupation: String?

    @StructuredField("所属会社・組織")
    var company: String?

    @StructuredField("学歴")
    var education: String?

    @StructuredField("メールアドレス")
    var email: String?

    @StructuredField("特記事項")
    var notes: [String]?
}

// MARK: - Product Output

/// 商品情報（比較用）
@Structured("商品・メニュー情報")
struct ProductOutput: Equatable {
    @StructuredField("商品名")
    var name: String

    @StructuredField("価格（円）")
    var price: Int?

    @StructuredField("割引前価格（円）")
    var originalPrice: Int?

    @StructuredField("カテゴリ")
    var category: String?

    @StructuredField("数量制限")
    var quantityLimit: String?

    @StructuredField("備考")
    var notes: String?

    @StructuredField("関連商品リスト")
    var relatedItems: [ProductItemOutput]?
}

/// 商品アイテム
@Structured("商品アイテム")
struct ProductItemOutput: Equatable {
    @StructuredField("商品名")
    var name: String

    @StructuredField("価格（円）")
    var price: Int?

    @StructuredField("備考")
    var notes: String?
}

// MARK: - Meeting Output

/// 会議情報（比較用）
@Structured("会議情報")
struct MeetingOutput: Equatable {
    @StructuredField("会議名")
    var title: String?

    @StructuredField("開始時刻")
    var startTime: String?

    @StructuredField("終了時刻（推論）")
    var endTime: String?

    @StructuredField("所要時間（分）")
    var durationMinutes: Int?

    @StructuredField("議題リスト")
    var agenda: [String]

    @StructuredField("議題ごとの時間（分）")
    var timePerAgenda: Int?

    @StructuredField("備考")
    var notes: String?
}

// MARK: - Organization Output

/// 組織情報（比較用）
@Structured("組織情報")
struct OrganizationOutput: Equatable {
    @StructuredField("組織名")
    var name: String

    @StructuredField("設立年")
    var establishedYear: Int?

    @StructuredField("現在の年（推論）")
    var currentYear: Int?

    @StructuredField("代表者名")
    var ceo: String?

    @StructuredField("従業員数")
    var employeeCount: Int?

    @StructuredField("売上高")
    var revenue: String?

    @StructuredField("子会社・部署リスト")
    var subsidiaries: [SubsidiaryOutput]?
}

/// 子会社・部署
@Structured("子会社・部署情報")
struct SubsidiaryOutput: Equatable {
    @StructuredField("名称")
    var name: String

    @StructuredField("従業員数")
    var employeeCount: Int?

    @StructuredField("売上高")
    var revenue: String?

    @StructuredField("下位部門")
    var departments: [String]?
}

// MARK: - Recipe Output

/// レシピ情報（比較用）
@Structured("レシピ情報")
struct RecipeOutput: Equatable {
    @StructuredField("料理名")
    var name: String

    @StructuredField("調理時間（分）")
    var cookingTimeMinutes: Int?

    @StructuredField("難易度")
    var difficulty: String?

    @StructuredField("材料リスト")
    var ingredients: [IngredientOutput]?

    @StructuredField("手順")
    var steps: [String]?
}

/// 材料
@Structured("材料")
struct IngredientOutput: Equatable {
    @StructuredField("材料名")
    var name: String

    @StructuredField("分量")
    var amount: String?
}

// MARK: - Event Output

/// イベント情報（比較用）
@Structured("イベント情報")
struct EventOutput: Equatable {
    @StructuredField("イベント名")
    var name: String

    @StructuredField("開催日")
    var date: String?

    @StructuredField("開催場所")
    var venue: String?

    @StructuredField("参加費")
    var fee: String?

    @StructuredField("定員")
    var capacity: Int?

    @StructuredField("主催者")
    var organizer: String?
}

// MARK: - Generic Comparison Result

/// 比較結果（型消去版）
struct ComparisonResultData: Identifiable, Sendable {
    let id = UUID()
    let provider: AppSettings.Provider
    let model: String
    let testCaseId: String
    let duration: TimeInterval
    let usage: TokenUsage?
    let error: String?

    // 型消去された出力データ（JSON文字列として保存）
    let outputJSON: String?

    var isSuccess: Bool { outputJSON != nil && error == nil }

    init<T: Encodable>(
        provider: AppSettings.Provider,
        model: String,
        testCase: ComparisonTestCase,
        output: T?,
        usage: TokenUsage?,
        duration: TimeInterval,
        error: String?
    ) {
        self.provider = provider
        self.model = model
        self.testCaseId = testCase.id
        self.usage = usage
        self.duration = duration
        self.error = error

        // JSONに変換して保存
        if let output = output {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(output),
               let json = String(data: data, encoding: .utf8) {
                self.outputJSON = json
            } else {
                self.outputJSON = nil
            }
        } else {
            self.outputJSON = nil
        }
    }

    /// エラー用イニシャライザ
    init(
        provider: AppSettings.Provider,
        model: String,
        testCase: ComparisonTestCase,
        duration: TimeInterval,
        error: String
    ) {
        self.provider = provider
        self.model = model
        self.testCaseId = testCase.id
        self.usage = nil
        self.duration = duration
        self.error = error
        self.outputJSON = nil
    }

    /// カスタム入力用イニシャライザ（成功時）
    init<T: Encodable>(
        provider: AppSettings.Provider,
        model: String,
        testCaseId: String,
        output: T?,
        usage: TokenUsage?,
        duration: TimeInterval,
        error: String?
    ) {
        self.provider = provider
        self.model = model
        self.testCaseId = testCaseId
        self.usage = usage
        self.duration = duration
        self.error = error

        // JSONに変換して保存
        if let output = output {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(output),
               let json = String(data: data, encoding: .utf8) {
                self.outputJSON = json
            } else {
                self.outputJSON = nil
            }
        } else {
            self.outputJSON = nil
        }
    }

    /// カスタム入力用エラーイニシャライザ
    init(
        provider: AppSettings.Provider,
        model: String,
        testCaseId: String,
        duration: TimeInterval,
        error: String
    ) {
        self.provider = provider
        self.model = model
        self.testCaseId = testCaseId
        self.usage = nil
        self.duration = duration
        self.error = error
        self.outputJSON = nil
    }
}
