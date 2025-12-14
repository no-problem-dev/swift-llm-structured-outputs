//
//  BusinessCardInfo.swift
//  LLMStructuredOutputsExample
//
//  名刺情報の構造化出力モデル
//

import Foundation
import LLMStructuredOutputs

/// 名刺から抽出する情報
///
/// 名刺のテキストから連絡先情報を構造化して抽出します。
///
/// ## 使用例
/// ```swift
/// let client = AnthropicClient(apiKey: "...")
/// let info: BusinessCardInfo = try await client.generate(
///     prompt: "株式会社テック 営業部 山田太郎 yamada@tech.co.jp 03-1234-5678",
///     model: .sonnet
/// )
/// ```
@Structured("名刺から抽出した連絡先情報")
struct BusinessCardInfo {
    @StructuredField("氏名（フルネーム）")
    var name: String

    @StructuredField("会社名")
    var company: String?

    @StructuredField("部署名")
    var department: String?

    @StructuredField("役職")
    var position: String?

    @StructuredField("メールアドレス", .format(.email))
    var email: String?

    @StructuredField("電話番号")
    var phone: String?

    @StructuredField("住所")
    var address: String?

    @StructuredField("WebサイトURL", .format(.uri))
    var website: String?
}

// MARK: - Sample Data

extension BusinessCardInfo {
    /// サンプルの名刺テキスト
    static let sampleInputs: [String] = [
        """
        株式会社テックイノベーション
        営業本部 第一営業部
        部長 山田 太郎

        〒100-0001 東京都千代田区丸の内1-1-1
        TEL: 03-1234-5678
        Email: yamada.taro@tech-innovation.co.jp
        https://www.tech-innovation.co.jp
        """,

        """
        佐藤 花子
        フリーランス Webデザイナー

        hanako.design@gmail.com
        090-9876-5432
        Portfolio: https://hanako-design.com
        """,

        """
        グローバルコンサルティング合同会社
        シニアコンサルタント
        田中 一郎 (Ichiro Tanaka)

        ichiro.tanaka@global-consulting.jp
        03-9999-0000
        大阪オフィス: 06-8888-0000
        """
    ]

    /// サンプル入力の説明
    static let sampleDescriptions: [String] = [
        "一般的な企業の名刺",
        "フリーランスの名刺",
        "外資系企業の名刺"
    ]
}
