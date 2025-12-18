//
//  AgentResultView.swift
//  AgentExample
//
//  エージェント結果表示（カテゴリ別）
//

import SwiftUI

/// エージェント結果表示
struct AgentResultView: View {
    let result: AgentResult

    var body: some View {
        switch result {
        case .research(let report):
            ResearchReportView(report: report)
        case .calculation(let report):
            CalculationReportView(report: report)
        case .temporal(let report):
            TemporalReportView(report: report)
        case .multiTool(let report):
            MultiToolReportView(report: report)
        case .reasoning(let report):
            ReasoningReportView(report: report)
        case .memory(let report):
            MemoryReportView(report: report)
        }
    }
}

// MARK: - Research Report View

private struct ResearchReportView: View {
    let report: ResearchReport
    @State private var showingJSON = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("リサーチレポート", systemImage: "magnifyingglass")
                    .font(.headline)
                Spacer()
                ConfidenceBadge(level: report.confidenceLevel)
            }

            ReportCard {
                Text(report.title)
                    .font(.title2.bold())

                Divider()

                SectionView(title: "要約", icon: "text.alignleft") {
                    Text(report.summary)
                }

                Divider()

                SectionView(title: "主要な発見", icon: "lightbulb.fill") {
                    BulletList(items: report.keyFindings)
                }

                if let recommendations = report.recommendations, !recommendations.isEmpty {
                    Divider()
                    SectionView(title: "推奨事項", icon: "checkmark.seal.fill") {
                        Text(recommendations)
                    }
                }

                Divider()

                SectionView(title: "情報源", icon: "link") {
                    SourceList(sources: report.sources)
                }
            }

            JSONDisclosure(showingJSON: $showingJSON, content: report)
        }
    }
}

// MARK: - Calculation Report View

private struct CalculationReportView: View {
    let report: CalculationReport
    @State private var showingJSON = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("計算レポート", systemImage: "function")
                .font(.headline)

            ReportCard {
                Text(report.title)
                    .font(.title2.bold())

                Divider()

                SectionView(title: "説明", icon: "text.alignleft") {
                    Text(report.description)
                }

                Divider()

                SectionView(title: "計算ステップ", icon: "list.number") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(report.steps.enumerated()), id: \.offset) { index, step in
                            CalculationStepRow(index: index + 1, step: step)
                        }
                    }
                }

                Divider()

                SectionView(title: "最終結果", icon: "checkmark.circle.fill") {
                    Text(report.finalResult)
                        .font(.headline)
                        .foregroundStyle(.green)
                }

                if let notes = report.notes, !notes.isEmpty {
                    Divider()
                    SectionView(title: "補足", icon: "info.circle") {
                        Text(notes)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            JSONDisclosure(showingJSON: $showingJSON, content: report)
        }
    }
}

private struct CalculationStepRow: View {
    let index: Int
    let step: CalculationStep

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text("\(index).")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(step.expression)
                        .font(.subheadline.monospaced())
                    Text("= \(step.result)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.tint)
                    if let note = step.note {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Temporal Report View

private struct TemporalReportView: View {
    let report: TemporalReport
    @State private var showingJSON = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("時間レポート", systemImage: "clock")
                .font(.headline)

            ReportCard {
                Text(report.title)
                    .font(.title2.bold())

                Divider()

                SectionView(title: "目的", icon: "target") {
                    Text(report.purpose)
                }

                Divider()

                SectionView(title: "時刻情報", icon: "globe") {
                    VStack(spacing: 12) {
                        ForEach(Array(report.timeInfos.enumerated()), id: \.offset) { _, info in
                            TimeInfoRow(info: info)
                        }
                    }
                }

                Divider()

                SectionView(title: "まとめ", icon: "text.alignleft") {
                    Text(report.summary)
                }

                if let recommendation = report.recommendation, !recommendation.isEmpty {
                    Divider()
                    SectionView(title: "推奨", icon: "hand.thumbsup.fill") {
                        Text(recommendation)
                    }
                }
            }

            JSONDisclosure(showingJSON: $showingJSON, content: report)
        }
    }
}

private struct TimeInfoRow: View {
    let info: TimeInfo

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(info.location)
                    .font(.subheadline.bold())
                Text(info.timezone)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(info.dateTime)
                    .font(.subheadline.monospaced())
                if let offset = info.offsetFromUTC {
                    Text("UTC\(offset)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - MultiTool Report View

private struct MultiToolReportView: View {
    let report: MultiToolReport
    @State private var showingJSON = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("総合分析レポート", systemImage: "square.stack.3d.up")
                .font(.headline)

            ReportCard {
                Text(report.title)
                    .font(.title2.bold())

                Divider()

                SectionView(title: "目的", icon: "target") {
                    Text(report.objective)
                }

                Divider()

                SectionView(title: "収集した情報", icon: "doc.text.magnifyingglass") {
                    BulletList(items: report.findings)
                }

                if let comparisons = report.comparisons, !comparisons.isEmpty {
                    Divider()
                    SectionView(title: "比較分析", icon: "arrow.left.arrow.right") {
                        VStack(spacing: 8) {
                            ForEach(Array(comparisons.enumerated()), id: \.offset) { _, item in
                                ComparisonRow(item: item)
                            }
                        }
                    }
                }

                if let calculations = report.calculations, !calculations.isEmpty {
                    Divider()
                    SectionView(title: "計算結果", icon: "function") {
                        BulletList(items: calculations)
                    }
                }

                Divider()

                SectionView(title: "結論", icon: "checkmark.circle.fill") {
                    Text(report.conclusion)
                        .font(.subheadline.bold())
                }

                if let recommendation = report.recommendation, !recommendation.isEmpty {
                    Divider()
                    SectionView(title: "推奨", icon: "hand.thumbsup.fill") {
                        Text(recommendation)
                    }
                }

                if let sources = report.sources, !sources.isEmpty {
                    Divider()
                    SectionView(title: "情報源", icon: "link") {
                        SourceList(sources: sources)
                    }
                }
            }

            JSONDisclosure(showingJSON: $showingJSON, content: report)
        }
    }
}

private struct ComparisonRow: View {
    let item: ComparisonItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.aspect)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack {
                Text(item.valueA)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text("vs")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(item.valueB)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            if let evaluation = item.evaluation {
                Text(evaluation)
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Reasoning Report View

private struct ReasoningReportView: View {
    let report: ReasoningReport
    @State private var showingJSON = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("推論レポート", systemImage: "brain")
                .font(.headline)

            ReportCard {
                Text(report.title)
                    .font(.title2.bold())

                Divider()

                SectionView(title: "問題", icon: "questionmark.circle") {
                    Text(report.problemStatement)
                }

                Divider()

                SectionView(title: "分析", icon: "chart.bar.doc.horizontal") {
                    Text(report.analysis)
                }

                Divider()

                SectionView(title: "推論ステップ", icon: "arrow.right.circle") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(report.reasoningSteps, id: \.stepNumber) { step in
                            ReasoningStepRow(step: step)
                        }
                    }
                }

                Divider()

                SectionView(title: "結論", icon: "checkmark.circle.fill") {
                    Text(report.conclusion)
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                }

                if let verification = report.verification, !verification.isEmpty {
                    Divider()
                    SectionView(title: "検証", icon: "checkmark.seal") {
                        Text(verification)
                            .foregroundStyle(.blue)
                    }
                }

                if let notes = report.additionalNotes, !notes.isEmpty {
                    Divider()
                    SectionView(title: "追加考察", icon: "lightbulb") {
                        Text(notes)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            JSONDisclosure(showingJSON: $showingJSON, content: report)
        }
    }
}

private struct ReasoningStepRow: View {
    let step: ReasoningStep

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text("\(step.stepNumber).")
                    .font(.caption.bold())
                    .foregroundStyle(.tint)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(step.reasoning)
                        .font(.subheadline)
                    if let result = step.intermediateResult {
                        Text("→ \(result)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Memory Report View

private struct MemoryReportView: View {
    let report: MemoryReport
    @State private var showingJSON = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("メモリレポート", systemImage: "memorychip")
                .font(.headline)

            ReportCard {
                Text(report.title)
                    .font(.title2.bold())

                Divider()

                SectionView(title: "操作内容", icon: "text.alignleft") {
                    Text(report.description)
                }

                if !report.items.isEmpty {
                    Divider()
                    SectionView(title: "データ一覧", icon: "list.bullet") {
                        BulletList(items: report.items)
                    }
                }

                Divider()

                SectionView(title: "結果", icon: "checkmark.circle.fill") {
                    Text(report.summary)
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                }
            }

            JSONDisclosure(showingJSON: $showingJSON, content: report)
        }
    }
}

// MARK: - Common Components

private struct ReportCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

private struct SectionView<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            content
                .font(.subheadline)
        }
    }
}

private struct BulletList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(.tint)
                    Text(item)
                }
            }
        }
    }
}

private struct SourceList: View {
    let sources: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(sources.enumerated()), id: \.offset) { index, source in
                if let url = URL(string: source) {
                    Link(destination: url) {
                        HStack {
                            Text("[\(index + 1)]")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Text(source)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                } else {
                    HStack {
                        Text("[\(index + 1)]")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        Text(source)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        }
    }
}

private struct ConfidenceBadge: View {
    let level: ConfidenceLevel

    var body: some View {
        Text("信頼度: \(level.displayName)")
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private var color: Color {
        switch level {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }
}

private struct JSONDisclosure<T: Encodable>: View {
    @Binding var showingJSON: Bool
    let content: T

    var body: some View {
        DisclosureGroup("JSON形式で表示", isExpanded: $showingJSON) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(formatJSON())
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
    }

    private func formatJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(content),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "JSONへの変換に失敗しました"
        }

        return jsonString
    }
}

// MARK: - Preview

#Preview("Research") {
    ScrollView {
        AgentResultView(result: .research(ResearchReport(
            title: "Swift Concurrency 完全ガイド",
            summary: "Swift ConcurrencyはSwift 5.5で導入された非同期プログラミングのためのフレームワークです。",
            keyFindings: ["async/awaitで読みやすく", "Actorで安全な並行処理"],
            sources: ["https://developer.apple.com/swift"],
            recommendations: "段階的な移行を推奨",
            confidenceLevel: .high
        )))
        .padding()
    }
}

#Preview("Calculation") {
    ScrollView {
        AgentResultView(result: .calculation(CalculationReport(
            title: "割り勘計算",
            description: "飲み会の割り勘を計算",
            steps: [
                CalculationStep(expression: "27350 ÷ 7", result: "3907.14", note: "1人あたり"),
                CalculationStep(expression: "3900 × 7", result: "27300", note: "端数なし合計")
            ],
            finalResult: "1人3,900円、幹事は3,950円",
            notes: nil
        )))
        .padding()
    }
}
