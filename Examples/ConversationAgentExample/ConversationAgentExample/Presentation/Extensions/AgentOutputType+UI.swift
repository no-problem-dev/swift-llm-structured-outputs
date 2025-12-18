import SwiftUI

extension AgentOutputType {

    var displayName: String {
        switch self {
        case .research: "リサーチ"
        case .articleSummary: "記事要約"
        case .codeReview: "コードレビュー"
        }
    }

    var icon: String {
        switch self {
        case .research: "magnifyingglass.circle.fill"
        case .articleSummary: "doc.text.fill"
        case .codeReview: "chevron.left.forwardslash.chevron.right"
        }
    }

    var tintColor: Color {
        switch self {
        case .research: .blue
        case .articleSummary: .green
        case .codeReview: .orange
        }
    }

    var subtitle: String {
        switch self {
        case .research: "Web検索で詳細調査"
        case .articleSummary: "URLから記事を要約"
        case .codeReview: "コードの品質評価"
        }
    }

    var placeholder: String {
        switch self {
        case .research: "調べたいトピックを入力してください"
        case .articleSummary: "記事のURLを入力してください"
        case .codeReview: "レビューしたいコードを貼り付けてください"
        }
    }
}
