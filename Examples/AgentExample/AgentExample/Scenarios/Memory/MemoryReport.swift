//
//  MemoryReport.swift
//  AgentExample
//
//  メモリシナリオの出力型定義
//

import Foundation
import LLMStructuredOutputs

// MARK: - Memory Report

/// メモリ管理レポート
@Structured("メモリ操作の結果をまとめた構造化レポート")
struct MemoryReport: Equatable {
    @StructuredField("レポートのタイトル")
    var title: String

    @StructuredField("実行した操作の説明")
    var description: String

    @StructuredField("保存・取得したデータの一覧")
    var items: [String]

    @StructuredField("操作結果のまとめ")
    var summary: String
}
