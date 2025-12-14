//
//  FinalReportView.swift
//  AgentExample
//
//  最終レポート表示
//

import SwiftUI

/// 最終レポート表示
///
/// エージェントが生成した ResearchReport を視覚的に表示します。
struct FinalReportView: View {
    let report: ResearchReport

    @State private var showingJSON = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ヘッダー
            HStack {
                Label("リサーチレポート", systemImage: "doc.text.fill")
                    .font(.headline)

                Spacer()

                // 信頼度バッジ
                ConfidenceBadge(level: report.confidenceLevel)
            }

            VStack(alignment: .leading, spacing: 16) {
                // タイトル
                Text(report.title)
                    .font(.title2.bold())

                Divider()

                // 要約
                VStack(alignment: .leading, spacing: 8) {
                    Label("要約", systemImage: "text.alignleft")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    Text(report.summary)
                        .font(.body)
                }

                Divider()

                // 主要な発見
                VStack(alignment: .leading, spacing: 8) {
                    Label("主要な発見", systemImage: "lightbulb.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(report.keyFindings.enumerated()), id: \.offset) { index, finding in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundStyle(Color.accentColor)
                                Text(finding)
                                    .font(.subheadline)
                            }
                        }
                    }
                }

                // 推奨事項（あれば）
                if let recommendations = report.recommendations, !recommendations.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Label("推奨事項", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)

                        Text(recommendations)
                            .font(.subheadline)
                    }
                }

                Divider()

                // 情報源
                VStack(alignment: .leading, spacing: 8) {
                    Label("情報源", systemImage: "link")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(report.sources.enumerated()), id: \.offset) { index, source in
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
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            // JSON表示トグル
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
    }

    private func formatJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(report),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "JSONへの変換に失敗しました"
        }

        return jsonString
    }
}

// MARK: - Confidence Badge

private struct ConfidenceBadge: View {
    let level: ConfidenceLevel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: level.icon)
            Text(level.displayName)
        }
        .font(.caption.bold())
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }

    private var color: Color {
        switch level {
        case .high:
            return .green
        case .medium:
            return .orange
        case .low:
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        FinalReportView(
            report: ResearchReport(
                title: "Swift Concurrency 完全ガイド",
                summary: "Swift ConcurrencyはSwift 5.5で導入された非同期プログラミングのためのフレームワークです。async/await構文により、非同期コードを同期コードのように読みやすく書けるようになりました。",
                keyFindings: [
                    "async/awaitにより非同期コードが大幅に読みやすくなった",
                    "Actorモデルにより安全な並行処理が可能に",
                    "TaskGroupで構造化された並行処理を実現",
                    "MainActorでUIスレッドへの安全なアクセスを保証"
                ],
                sources: [
                    "https://developer.apple.com/swift/concurrency",
                    "https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html"
                ],
                recommendations: "既存のコードベースでは段階的な移行を推奨します。まずはシンプルなAPIコールから始め、徐々にActorパターンを導入していくのが効果的です。",
                confidenceLevel: .high
            )
        )
        .padding()
    }
}
