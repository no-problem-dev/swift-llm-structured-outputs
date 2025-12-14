//
//  ProductReview.swift
//  LLMStructuredOutputsExample
//
//  商品レビューの構造化出力モデル（制約のデモ用）
//

import Foundation
import LLMStructuredOutputs

/// 商品レビューの解析結果
///
/// フィールド制約を活用して、レビューを構造化します。
///
/// ## 使用している制約
/// - `.minimum(1)`, `.maximum(5)`: 評価値の範囲
/// - `.minLength(10)`, `.maxLength(200)`: 要約の文字数制限
/// - `.minItems(1)`, `.maxItems(5)`: タグの数制限
@Structured("商品レビューの解析結果")
struct ProductReview {
    @StructuredField("商品名")
    var productName: String

    @StructuredField("総合評価（1-5の星評価）", .minimum(1), .maximum(5))
    var rating: Int

    @StructuredField("レビューの要約（10-200文字）", .minLength(10), .maxLength(200))
    var summary: String

    @StructuredField("良い点のリスト（1-5個）", .minItems(1), .maxItems(5))
    var pros: [String]

    @StructuredField("悪い点のリスト（0-5個）", .maxItems(5))
    var cons: [String]

    @StructuredField("レビュアーの感情", .enum(["非常に満足", "満足", "普通", "不満", "非常に不満"]))
    var sentiment: String

    @StructuredField("購入を推奨するか")
    var recommended: Bool
}

// MARK: - Sample Data

extension ProductReview {
    /// サンプルのレビューテキスト
    static let sampleInputs: [String] = [
        """
        ワイヤレスイヤホン「SoundPro X1」を購入して2ヶ月使いました。
        音質は価格以上で、特に低音がしっかり出ています。
        ノイズキャンセリングも優秀で、電車内でも快適に音楽を楽しめます。
        バッテリーも8時間以上持つので十分です。
        ただ、付属のイヤーピースが少し大きめで、私の耳には合いませんでした。
        また、アプリの操作性がイマイチで、イコライザーの設定がわかりにくいです。
        総合的には満足しており、この価格帯では最高の選択肢だと思います！
        """,

        """
        期待はずれでした。
        このスマートウォッチ「FitLife 3」、見た目はカッコいいですが中身がダメ。
        心拍数の測定が不正確で、運動中にエラーが頻発。
        バッテリーは2日も持ちません（公称は5日）。
        睡眠トラッキングはまあまあ正確ですが、それだけのために買う価値はない。
        アプリも反応が遅くてストレス。
        1万円以下の商品に品質を求めすぎかもしれませんが、返品を検討中です。
        """,

        """
        コーヒーメーカー「BrewMaster Pro」のレビューです。
        普通に使えます。特に感動もないですが、不満もありません。
        毎朝のコーヒーを淹れるには十分な機能です。
        掃除はちょっと面倒ですね。
        デザインは無難。キッチンに馴染みます。
        コスパを考えると妥当な製品だと思います。
        """
    ]

    /// サンプル入力の説明
    static let sampleDescriptions: [String] = [
        "ポジティブなレビュー（イヤホン）",
        "ネガティブなレビュー（スマートウォッチ）",
        "中立的なレビュー（コーヒーメーカー）"
    ]
}
