//
//  ImageAnalysisResult.swift
//  LLMStructuredOutputsExample
//
//  画像分析結果の構造化モデル
//

import Foundation
import LLMStructuredOutputs

// MARK: - 画像分析結果

/// 画像分析の構造化結果
///
/// LLMによる画像解析結果を構造化して受け取ります。
@Structured("画像の詳細な分析結果")
struct ImageAnalysisResult {
    @StructuredField("画像の簡潔な説明（1-2文）")
    var summary: String

    @StructuredField("画像に写っている主要なオブジェクト")
    var objects: [String]

    @StructuredField("画像の主要な色彩")
    var colors: [String]

    @StructuredField("画像の雰囲気・トーン（例：明るい、暗い、温かい、クール）")
    var mood: String

    @StructuredField("シーンの種類（例：室内、屋外、自然、都市）")
    var sceneType: String

    @StructuredField("画像にテキストが含まれる場合、その内容")
    var textContent: String?

    @StructuredField("追加の観察・コメント")
    var additionalNotes: String?
}

// MARK: - 使いやすい表示用拡張

extension ImageAnalysisResult {
    /// オブジェクトリストを表示用文字列に変換
    var objectsDescription: String {
        objects.isEmpty ? "なし" : objects.joined(separator: "、")
    }

    /// 色彩リストを表示用文字列に変換
    var colorsDescription: String {
        colors.isEmpty ? "なし" : colors.joined(separator: "、")
    }
}

// MARK: - サンプル入力

extension ImageAnalysisResult {
    /// サンプル画像URL（パブリックドメイン画像）
    static let sampleImageURLs: [String] = [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/280px-PNG_transparency_demonstration_1.png",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/Camponotus_flavomarginatus_ant.jpg/320px-Camponotus_flavomarginatus_ant.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b6/Image_created_with_a_mobile_phone.png/320px-Image_created_with_a_mobile_phone.png"
    ]

    /// サンプル画像の説明
    static let sampleDescriptions: [String] = [
        "PNG透過デモ画像（サイコロ）",
        "アリのマクロ写真",
        "風景写真（携帯で撮影）"
    ]
}
