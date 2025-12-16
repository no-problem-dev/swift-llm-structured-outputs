import Foundation
import LLMToolkits

// MARK: - Output Types
//
// このアプリでは LLMToolkits の共通出力型を使用します：
//
// - AnalysisResult: リサーチシナリオ用
//   - summary: 分析の要約
//   - keyFindings: 主要な発見
//   - recommendations: 推奨アクション
//   - risks: 潜在的リスク
//   - confidence: 信頼度スコア
//
// - Summary: 記事要約シナリオ用
//   - briefSummary: 簡潔な要約
//   - mainPoints: 主要ポイント
//   - keyTakeaways: 重要な結論
//   - targetAudience: 対象読者
//
// - CodeReview: コードレビューシナリオ用
//   - overallAssessment: 総評
//   - issues: 発見された問題点
//   - suggestions: 改善提案
//   - strengths: 良い点
//   - qualityScore: 品質スコア (1-10)

// LLMToolkits の型を再エクスポート
public typealias ResearchOutput = AnalysisResult
public typealias ArticleSummaryOutput = Summary
public typealias CodeReviewOutput = CodeReview
