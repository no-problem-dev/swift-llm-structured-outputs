//
//  WebSearchTool.swift
//  ConversationAgentExample
//
//  Web検索ツール
//

import Foundation
import LLMStructuredOutputs

/// Web検索ツール
///
/// Brave Search APIを使用してWeb検索を実行します。
@Tool("インターネットでWeb検索を実行します。検索クエリを指定して、関連するWebページの一覧を取得できます。")
struct WebSearchTool {
    @ToolArgument("検索クエリ（キーワードやフレーズ）")
    var query: String

    @ToolArgument("取得する検索結果の数（1-10、デフォルト5）")
    var count: Int?

    func call() async throws -> String {
        let service = BraveSearchService()
        let resultCount = min(max(count ?? 5, 1), 10)

        do {
            return try await service.searchFormatted(query: query, count: resultCount)
        } catch {
            return "検索エラー: \(error.localizedDescription)"
        }
    }
}
