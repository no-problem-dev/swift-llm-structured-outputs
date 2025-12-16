import Foundation

// MARK: - ResearchReport

extension ResearchReport {

    /// フォーマット済みの出力文字列
    var formatted: String {
        var lines: [String] = []

        lines.append("# \(topic)")
        lines.append("")
        lines.append("## 概要")
        lines.append(summary)
        lines.append("")

        lines.append("## 主要な発見")
        for (index, finding) in keyFindings.enumerated() {
            lines.append("\(index + 1). \(finding)")
        }
        lines.append("")

        if !sources.isEmpty {
            lines.append("## 参照元")
            for source in sources {
                lines.append("- \(source)")
            }
            lines.append("")
        }

        if !furtherQuestions.isEmpty {
            lines.append("## 今後の調査課題")
            for question in furtherQuestions {
                lines.append("- \(question)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - SummaryReport

extension SummaryReport {

    /// フォーマット済みの出力文字列
    var formatted: String {
        var lines: [String] = []

        lines.append("# \(title)")
        lines.append("")
        lines.append(summary)
        lines.append("")

        if !bulletPoints.isEmpty {
            lines.append("## ポイント")
            for point in bulletPoints {
                lines.append("• \(point)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - ComparisonReport

extension ComparisonReport {

    /// フォーマット済みの出力文字列
    var formatted: String {
        var lines: [String] = []

        lines.append("# \(subject)の比較")
        lines.append("")

        for item in items {
            lines.append("## \(item.name)")
            lines.append("")

            if !item.pros.isEmpty {
                lines.append("### 長所")
                for pro in item.pros {
                    lines.append("✓ \(pro)")
                }
                lines.append("")
            }

            if !item.cons.isEmpty {
                lines.append("### 短所")
                for con in item.cons {
                    lines.append("✗ \(con)")
                }
                lines.append("")
            }
        }

        lines.append("## 結論・推奨")
        lines.append(recommendation)

        return lines.joined(separator: "\n")
    }
}
