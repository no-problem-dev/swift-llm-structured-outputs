//
//  WebSearchTool.swift
//  AgentExample
//
//  Web検索ツール
//

import Foundation
import LLMStructuredOutputs

/// Web検索ツール
///
/// Brave Search API を使用してWeb検索を実行し、検索結果を返します。
@Tool("Webを検索して情報を取得します。最新のニュース、技術情報、一般的な質問などに使用できます。")
struct WebSearchTool {
    @ToolArgument("検索クエリ（検索したいキーワードや質問）")
    var query: String

    @ToolArgument("取得する検索結果の数（1〜10、デフォルト5）")
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
