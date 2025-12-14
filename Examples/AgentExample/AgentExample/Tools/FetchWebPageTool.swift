//
//  FetchWebPageTool.swift
//  AgentExample
//
//  Webページ取得ツール
//

import Foundation
import LLMStructuredOutputs

/// Webページ取得ツール
///
/// 指定されたURLのWebページを取得し、テキストコンテンツを抽出して返します。
@Tool("指定されたURLのWebページを取得し、テキストコンテンツを抽出します。検索結果のURLや特定のWebサイトから詳細情報を取得する際に使用します。", name: "fetch_web_page")
struct FetchWebPageTool {
    @ToolArgument("取得するWebページのURL（https://example.com/page のような形式）")
    var url: String

    @ToolArgument("抽出するテキストの最大文字数（1000〜20000、デフォルト8000）")
    var maxLength: Int?

    func call() async throws -> String {
        let service = WebFetchService()
        let length = min(max(maxLength ?? 8000, 1000), 20000)

        do {
            return try await service.fetchFormatted(url: url, maxLength: length)
        } catch {
            return "ページ取得エラー: \(error.localizedDescription)"
        }
    }
}
