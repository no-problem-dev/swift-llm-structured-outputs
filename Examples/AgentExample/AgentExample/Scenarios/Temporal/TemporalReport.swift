//
//  TemporalReport.swift
//  AgentExample
//
//  時間シナリオの出力型定義
//

import Foundation
import LLMStructuredOutputs

// MARK: - Time Info

/// 時刻情報
@Structured("特定の場所の時刻情報")
struct TimeInfo: Equatable {
    @StructuredField("都市名または場所名")
    var location: String

    @StructuredField("現在の日時（例: 2024年1月15日 14:30）")
    var dateTime: String

    @StructuredField("タイムゾーン名（例: JST, EST, GMT）")
    var timezone: String

    @StructuredField("UTCとの時差（例: +9:00）")
    var offsetFromUTC: String?
}

// MARK: - Temporal Report

/// 時間レポート
@Structured("時間・日時に関する情報をまとめた構造化レポート")
struct TemporalReport: Equatable {
    @StructuredField("レポートのタイトル")
    var title: String

    @StructuredField("調査または計算の目的")
    var purpose: String

    @StructuredField("各場所の時刻情報一覧")
    var timeInfos: [TimeInfo]

    @StructuredField("時差や時刻に関する分析・まとめ")
    var summary: String

    @StructuredField("推奨事項やアドバイス")
    var recommendation: String?
}
