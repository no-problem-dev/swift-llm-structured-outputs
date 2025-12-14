//
//  TaskInfo.swift
//  LLMStructuredOutputsExample
//
//  タスク情報の構造化出力モデル（Enumのデモ用）
//

import Foundation
import LLMStructuredOutputs

// MARK: - Enums

/// タスクの優先度
@StructuredEnum("タスクの優先度レベル")
enum TaskPriority: String {
    @StructuredCase("緊急ではなく、時間があるときに対応するタスク")
    case low

    @StructuredCase("通常の優先度で、計画的に進めるタスク")
    case medium

    @StructuredCase("重要度が高く、優先的に対応すべきタスク")
    case high

    @StructuredCase("最優先で、すぐに対応が必要な緊急タスク")
    case critical
}

/// タスクのステータス
@StructuredEnum("タスクの現在のステータス")
enum TaskStatus: String {
    @StructuredCase("まだ着手していないタスク")
    case notStarted = "not_started"

    @StructuredCase("現在作業中のタスク")
    case inProgress = "in_progress"

    @StructuredCase("レビュー待ちまたは確認待ちのタスク")
    case pending

    @StructuredCase("完了したタスク")
    case completed

    @StructuredCase("何らかの理由でブロックされているタスク")
    case blocked
}

/// タスクのカテゴリ
@StructuredEnum("タスクのカテゴリ")
enum TaskCategory: String {
    @StructuredCase("新機能の開発や実装")
    case feature

    @StructuredCase("バグの修正")
    case bugfix

    @StructuredCase("ドキュメントの作成や更新")
    case documentation

    @StructuredCase("コードの改善やリファクタリング")
    case refactoring

    @StructuredCase("テストの追加や修正")
    case testing

    @StructuredCase("インフラやデプロイ関連")
    case infrastructure
}

// MARK: - Task Info Model

/// タスク情報
///
/// テキストからタスクの詳細を構造化して抽出します。
/// Enum を使って優先度、ステータス、カテゴリを分類します。
@Structured("タスクの詳細情報")
struct TaskInfo {
    @StructuredField("タスクのタイトル", .maxLength(100))
    var title: String

    @StructuredField("タスクの詳細説明")
    var description: String

    @StructuredField("タスクの優先度")
    var priority: TaskPriority

    @StructuredField("タスクのステータス")
    var status: TaskStatus

    @StructuredField("タスクのカテゴリ")
    var category: TaskCategory

    @StructuredField("担当者の名前")
    var assignee: String?

    @StructuredField("期限（YYYY-MM-DD形式）", .format(.date))
    var dueDate: String?

    @StructuredField("見積もり工数（時間単位）", .minimum(1), .maximum(100))
    var estimatedHours: Int?

    @StructuredField("関連するタグ", .maxItems(5))
    var tags: [String]
}

// MARK: - Sample Data

extension TaskInfo {
    /// サンプルのタスク説明テキスト
    static let sampleInputs: [String] = [
        """
        【緊急】本番環境でログイン機能が動作しない

        今朝から複数のユーザーからログインできないという報告が来ています。
        調査したところ、昨日のデプロイで認証トークンの検証ロジックに
        バグが混入したようです。佐藤さんが担当で、今日中に修正が必要です。
        タグ: 本番障害、認証、緊急対応
        """,

        """
        ユーザープロフィール画面のUI改善

        現在のプロフィール画面は情報が詰め込まれすぎていて見づらいという
        フィードバックがあります。デザインチームと相談して、
        セクションごとに整理したUIに改善したいです。
        田中さんが担当予定で、来週金曜日（2025-01-24）までに完了希望。
        見積もりは20時間程度。
        タグ: UI/UX、プロフィール、改善要望
        """,

        """
        APIドキュメントの更新

        新しく追加したエンドポイントのドキュメントがまだ書けていません。
        /api/v2/users と /api/v2/orders のドキュメントを
        Swagger形式で追加する必要があります。
        優先度は低めで、時間があるときに対応予定。
        現在、山田が他のタスクで手一杯なので着手できていません。
        """
    ]

    /// サンプル入力の説明
    static let sampleDescriptions: [String] = [
        "緊急バグ修正タスク",
        "機能改善タスク",
        "ドキュメント作成タスク"
    ]
}
