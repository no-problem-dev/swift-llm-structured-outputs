//
//  FetchWebPageTool.swift
//  ConversationAgentExample
//
//  Webページ取得ツール
//

import Foundation
import LLMStructuredOutputs

/// Webページ取得ツール
///
/// 指定されたURLのWebページを取得し、テキストを抽出します。
@Tool("指定されたURLのWebページを取得し、内容をテキストとして抽出します。検索結果のURLの詳細を読み取る際に使用してください。")
struct FetchWebPageTool {
    @ToolArgument("取得するWebページのURL")
    var url: String

    @ToolArgument("抽出するテキストの最大長（デフォルト5000文字）")
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
