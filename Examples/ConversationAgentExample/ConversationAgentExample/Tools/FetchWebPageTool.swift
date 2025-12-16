import Foundation
import LLMStructuredOutputs

/// Webページ取得ツール
///
/// 指定されたURLのWebページを取得し、テキストを抽出します。
@Tool("Fetch a web page and extract its text content. Use this to read detailed information from URLs found in search results.")
struct FetchWebPageTool {
    @ToolArgument("URL of the web page to fetch")
    var url: String

    @ToolArgument("Maximum length of extracted text (default: 5000 characters)")
    var maxLength: Int?

    func call() async throws -> String {
        let service = WebFetchService()
        let length = maxLength ?? 5000

        do {
            return try await service.fetchFormatted(url: url, maxLength: length)
        } catch {
            return "ページ取得エラー: \(error.localizedDescription)"
        }
    }
}
