//
//  VideoAnalysisResult.swift
//  LLMStructuredOutputsExample
//
//  動画分析結果の構造化モデル
//

import Foundation
import LLMStructuredOutputs

// MARK: - 動画分析結果

/// 動画分析の構造化結果
///
/// LLMによる動画解析結果を構造化して受け取ります。
/// 現在、動画入力はGeminiのみでサポートされています。
@Structured("動画の詳細な分析結果")
struct VideoAnalysisResult {
    @StructuredField("動画の簡潔な説明（1-2文）")
    var summary: String

    @StructuredField("動画に登場する主要なオブジェクトや人物")
    var subjects: [String]

    @StructuredField("動画内で起こっている主要なアクション・イベント")
    var actions: [String]

    @StructuredField("動画の雰囲気・トーン（例：明るい、暗い、温かい、クール、緊迫感）")
    var mood: String

    @StructuredField("シーンの種類（例：室内、屋外、自然、都市、アニメーション）")
    var sceneType: String

    @StructuredField("動画に音声やBGMがある場合、その説明")
    var audioDescription: String?

    @StructuredField("動画にテキストや字幕が含まれる場合、その内容")
    var textContent: String?

    @StructuredField("追加の観察・コメント")
    var additionalNotes: String?
}

// MARK: - 使いやすい表示用拡張

extension VideoAnalysisResult {
    /// 対象リストを表示用文字列に変換
    var subjectsDescription: String {
        subjects.isEmpty ? "なし" : subjects.joined(separator: "、")
    }

    /// アクションリストを表示用文字列に変換
    var actionsDescription: String {
        actions.isEmpty ? "なし" : actions.joined(separator: "、")
    }
}

// MARK: - サンプル入力

extension VideoAnalysisResult {
    /// サンプル動画URL（パブリックドメイン動画）
    static let sampleVideoURLs: [String] = [
        "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
        "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
        "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4"
    ]

    /// サンプル動画の説明
    static let sampleDescriptions: [String] = [
        "ForBiggerBlazes（炎）",
        "ForBiggerEscapes（アクション）",
        "ForBiggerFun（コメディ）"
    ]
}
