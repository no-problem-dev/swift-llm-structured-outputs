//
//  JobSkills.swift
//  LLMStructuredOutputsExample
//
//  求人情報からのスキル抽出モデル（Prompt DSLのデモ用）
//

import Foundation
import LLMStructuredOutputs

// MARK: - Enums

/// スキルレベル
@StructuredEnum("スキルの習熟度レベル")
enum SkillLevel: String {
    @StructuredCase("初級：基礎的な知識があり、指導のもとで作業できる")
    case beginner

    @StructuredCase("中級：実務経験があり、独力で作業できる")
    case intermediate

    @StructuredCase("上級：深い知識と豊富な経験があり、他者を指導できる")
    case advanced

    @StructuredCase("エキスパート：業界トップレベルの専門性を持つ")
    case expert
}

/// スキルカテゴリ
@StructuredEnum("スキルのカテゴリ")
enum SkillCategory: String {
    @StructuredCase("プログラミング言語")
    case programmingLanguage = "programming_language"

    @StructuredCase("フレームワーク・ライブラリ")
    case framework

    @StructuredCase("データベース")
    case database

    @StructuredCase("インフラ・クラウド")
    case infrastructure

    @StructuredCase("ツール・その他")
    case tools

    @StructuredCase("ソフトスキル（コミュニケーション等）")
    case softSkill = "soft_skill"
}

// MARK: - Skill Model

/// 個別スキル
@Structured("求められるスキル")
struct Skill {
    @StructuredField("スキル名")
    var name: String

    @StructuredField("スキルのカテゴリ")
    var category: SkillCategory

    @StructuredField("求められるレベル")
    var requiredLevel: SkillLevel

    @StructuredField("必須スキルかどうか")
    var isRequired: Bool

    @StructuredField("経験年数の目安", .minimum(0), .maximum(20))
    var yearsOfExperience: Int?
}

// MARK: - Job Skills Model

/// 求人から抽出したスキル要件
@Structured("求人情報から抽出したスキル要件")
struct JobSkills {
    @StructuredField("求人のタイトル・ポジション名")
    var jobTitle: String

    @StructuredField("会社名")
    var companyName: String?

    @StructuredField("求められるスキルのリスト", .minItems(1), .maxItems(15))
    var skills: [Skill]

    @StructuredField("必要な実務経験年数", .minimum(0), .maximum(30))
    var totalExperienceYears: Int?

    @StructuredField("雇用形態", .enum(["正社員", "契約社員", "業務委託", "パート・アルバイト", "インターン"]))
    var employmentType: String?

    @StructuredField("リモートワーク可否", .enum(["フルリモート", "ハイブリッド", "出社必須", "不明"]))
    var remoteWork: String?

    @StructuredField("この求人の特徴や魅力（箇条書き）", .maxItems(5))
    var highlights: [String]
}

// MARK: - Sample Data

extension JobSkills {
    /// サンプルの求人情報テキスト
    static let sampleInputs: [String] = [
        """
        【急募】シニアiOSエンジニア募集！

        株式会社モバイルテック

        ■ 仕事内容
        自社プロダクトのiOSアプリ開発をリードしていただきます。
        チーム（3-5名）のテックリードとして、設計・実装・コードレビューを担当。

        ■ 必須スキル
        ・Swift での iOS アプリ開発経験 5年以上
        ・SwiftUI を使った実務経験
        ・Git/GitHub でのチーム開発経験
        ・アーキテクチャ設計（MVVM, Clean Architecture等）の経験

        ■ 歓迎スキル
        ・Combine, async/await などモダンな非同期処理の経験
        ・CI/CD（Fastlane, Bitrise等）の構築経験
        ・チームリード・メンタリング経験

        ■ 待遇
        正社員 / フルリモートOK
        年収 700-1000万円
        """,

        """
        【未経験歓迎】Webエンジニア見習い募集

        スタートアップ企業でWebアプリ開発を学びながら働きませんか？

        必要なスキル：
        - HTMLとCSSの基礎知識
        - JavaScriptの基本文法を理解していること
        - プログラミングを学ぶ意欲

        あると嬉しい：
        - React または Vue.js の学習経験
        - Gitの基本操作

        雇用形態：インターン（週3日〜）
        勤務地：渋谷オフィス（出社必須）

        成長意欲のある方、お待ちしています！
        """,

        """
        データエンジニア（業務委託）

        大手EC企業のデータ基盤構築プロジェクトに参画いただきます。

        【必須要件】
        * Python（pandas, numpy）実務3年以上
        * SQLによるデータ分析経験
        * AWSまたはGCPの実務経験
        * Apache Spark / Airflow いずれかの経験

        【あれば尚可】
        * Terraform等によるIaC経験
        * 機械学習パイプライン構築経験
        * 英語でのコミュニケーション能力

        リモート：ハイブリッド（週1出社）
        期間：6ヶ月〜（更新あり）
        単価：80-100万円/月
        """
    ]

    /// サンプル入力の説明
    static let sampleDescriptions: [String] = [
        "シニアiOSエンジニアの求人",
        "未経験向けWebエンジニアの求人",
        "データエンジニアの業務委託案件"
    ]
}
