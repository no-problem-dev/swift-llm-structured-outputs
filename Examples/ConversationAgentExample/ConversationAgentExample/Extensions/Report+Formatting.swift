import Foundation
import LLMToolkits

// MARK: - AnalysisResult (Research)

extension AnalysisResult {

    /// フォーマット済みの出力文字列
    var formatted: String {
        var lines: [String] = []

        lines.append("# リサーチ結果")
        lines.append("")

        lines.append("## 概要")
        lines.append(summary)
        lines.append("")

        lines.append("## 主要な発見")
        for (index, finding) in keyFindings.enumerated() {
            lines.append("\(index + 1). \(finding)")
        }
        lines.append("")

        lines.append("## 推奨アクション")
        for (index, recommendation) in recommendations.enumerated() {
            lines.append("\(index + 1). \(recommendation)")
        }
        lines.append("")

        if let risks = risks, !risks.isEmpty {
            lines.append("## 潜在的リスク")
            for risk in risks {
                lines.append("- \(risk)")
            }
            lines.append("")
        }

        lines.append("---")
        lines.append("信頼度: \(Int(confidence * 100))%")

        return lines.joined(separator: "\n")
    }
}

// MARK: - Summary (Article Summary)

extension Summary {

    /// フォーマット済みの出力文字列
    var formatted: String {
        var lines: [String] = []

        lines.append("# 記事要約")
        lines.append("")

        lines.append("## 概要")
        lines.append(briefSummary)
        lines.append("")

        lines.append("## 主要ポイント")
        for (index, point) in mainPoints.enumerated() {
            lines.append("\(index + 1). \(point)")
        }
        lines.append("")

        if let takeaways = keyTakeaways, !takeaways.isEmpty {
            lines.append("## 重要な結論")
            for takeaway in takeaways {
                lines.append("• \(takeaway)")
            }
            lines.append("")
        }

        if let audience = targetAudience {
            lines.append("---")
            lines.append("対象読者: \(audience)")
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - CodeReview

extension CodeReview {

    /// フォーマット済みの出力文字列
    var formatted: String {
        var lines: [String] = []

        lines.append("# コードレビュー結果")
        lines.append("")

        lines.append("## 総評")
        lines.append(overallAssessment)
        lines.append("")

        lines.append("## 品質スコア: \(qualityScore)/10")
        lines.append(qualityIndicator)
        lines.append("")

        if let strengths = strengths, !strengths.isEmpty {
            lines.append("## 良い点")
            for strength in strengths {
                lines.append("✓ \(strength)")
            }
            lines.append("")
        }

        if let issues = issues, !issues.isEmpty {
            lines.append("## 問題点")
            for issue in issues {
                let severityIcon = severityIcon(for: issue.severity)
                lines.append("\(severityIcon) [\(issue.severity.uppercased())] \(issue.description)")
                if let location = issue.location {
                    lines.append("   場所: \(location)")
                }
                if let fix = issue.suggestedFix {
                    lines.append("   修正案: \(fix)")
                }
            }
            lines.append("")
        }

        if let suggestions = suggestions, !suggestions.isEmpty {
            lines.append("## 改善提案")
            for (index, suggestion) in suggestions.enumerated() {
                lines.append("\(index + 1). \(suggestion)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private var qualityIndicator: String {
        switch qualityScore {
        case 9...10: "🌟 優秀"
        case 7...8: "✅ 良好"
        case 5...6: "⚠️ 改善の余地あり"
        case 3...4: "❌ 要改善"
        default: "🚨 重大な問題あり"
        }
    }

    private func severityIcon(for severity: String) -> String {
        switch severity.lowercased() {
        case "critical": "🚨"
        case "major": "❌"
        case "minor": "⚠️"
        case "suggestion": "💡"
        default: "•"
        }
    }
}
