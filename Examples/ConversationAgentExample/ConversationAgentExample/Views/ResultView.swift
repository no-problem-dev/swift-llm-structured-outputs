//
//  ResultView.swift
//  ConversationAgentExample
//
//  結果表示ビュー
//

import SwiftUI
import MarkdownUI

/// 結果表示ビュー
///
/// プレビューを表示し、タップで全文をMarkdown表示するシートを開きます。
struct ResultView: View {
    let result: String

    @State private var showFullResult = false

    /// プレビュー用の先頭部分（最初の見出しと要約部分）
    private var preview: String {
        let lines = result.components(separatedBy: "\n")
        let previewLines = lines.prefix(8)
        let preview = previewLines.joined(separator: "\n")
        if lines.count > 8 {
            return preview + "\n..."
        }
        return preview
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(preview)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(6)
                .multilineTextAlignment(.leading)

            Button {
                showFullResult = true
            } label: {
                HStack {
                    Label("全文を表示", systemImage: "doc.text.magnifyingglass")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showFullResult) {
            ResultDetailSheet(result: result)
        }
    }
}

// MARK: - Result Detail Sheet

private struct ResultDetailSheet: View {
    let result: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Markdown(result)
                    .markdownTheme(.gitHub)
                    .padding()
            }
            .navigationTitle("リサーチ結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    ShareLink(item: result) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

#Preview {
    ResultView(result: """
    # 📚 AIエージェントの最新動向

    ## 要約

    AIエージェントは2024年に大きな進歩を遂げ、様々な分野で実用化が進んでいます。
    特に自律的なタスク実行能力の向上が顕著です。

    ## 重要な発見

    1. マルチモーダル対応が標準化
    2. ツール使用能力の大幅な向上
    3. 長期記憶の実装が進展

    ## 情報源

    - [https://example.com/ai-agents-2024](https://example.com/ai-agents-2024)
    - [https://example.com/autonomous-agents](https://example.com/autonomous-agents)

    ## さらに調査すべき点

    - セキュリティ面での課題
    - 実運用での信頼性
    """)
    .padding()
}
