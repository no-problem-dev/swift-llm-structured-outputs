import Foundation
import LLMStructuredOutputs

/// Web検索ツール
///
/// Brave Search APIを使用してWeb検索を実行します。
@Tool("Search the web for information. Returns a list of relevant web pages with titles, URLs, and descriptions.")
struct WebSearchTool {
    var apiKey: String? = nil

    @ToolArgument("Search query (keywords or phrase)")
    var query: String

    @ToolArgument("Number of results to return (1-10, default: 5)")
    var count: Int?

    init(apiKey: String?) {
        self.apiKey = apiKey
        self.query = ""
        self.count = nil
        self.arguments = Arguments()
    }

    func call() async throws -> String {
        let service = BraveSearchService()
        let resultCount = min(max(count ?? 5, 1), 10)

        do {
            return try await service.searchFormatted(query: query, count: resultCount, apiKey: apiKey)
        } catch {
            return "検索エラー: \(error.localizedDescription)"
        }
    }
}
