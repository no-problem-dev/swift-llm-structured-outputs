import Foundation

/// Webページ取得サービス
///
/// 指定されたURLのWebページを取得し、HTMLからテキストを抽出します。
actor WebFetchService {

    // MARK: - Types

    /// 取得結果
    struct FetchResult: Sendable {
        let url: String
        let title: String?
        let content: String
        let contentLength: Int
    }

    /// エラー型
    enum ServiceError: LocalizedError {
        case invalidURL
        case requestFailed(statusCode: Int)
        case noContent
        case networkError(Error)
        case contentTooLarge(Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "無効な URL です"
            case .requestFailed(let statusCode):
                return "リクエストが失敗しました（ステータスコード: \(statusCode)）"
            case .noContent:
                return "コンテンツが取得できませんでした"
            case .networkError(let error):
                return "ネットワークエラー: \(error.localizedDescription)"
            case .contentTooLarge(let size):
                return "コンテンツが大きすぎます（\(size) bytes）"
            }
        }
    }

    // MARK: - Properties

    private let session: URLSession
    private let maxContentSize: Int

    // MARK: - Initialization

    init(session: URLSession = .shared, maxContentSize: Int = 1_000_000) {
        self.session = session
        self.maxContentSize = maxContentSize
    }

    // MARK: - Public Methods

    /// Webページを取得してテキストを抽出
    func fetch(url urlString: String, maxLength: Int = 10000) async throws -> FetchResult {
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ServiceError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.requestFailed(statusCode: -1)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ServiceError.requestFailed(statusCode: httpResponse.statusCode)
        }

        guard data.count <= maxContentSize else {
            throw ServiceError.contentTooLarge(data.count)
        }

        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            throw ServiceError.noContent
        }

        let title = extractTitle(from: html)
        let content = extractText(from: html, maxLength: maxLength)

        return FetchResult(
            url: urlString,
            title: title,
            content: content,
            contentLength: content.count
        )
    }

    /// Webページをフォーマットされた文字列として取得
    func fetchFormatted(url urlString: String, maxLength: Int = 10000) async throws -> String {
        let result = try await fetch(url: urlString, maxLength: maxLength)

        var output = "=== Webページ取得結果 ===\n"
        output += "URL: \(result.url)\n"
        if let title = result.title {
            output += "タイトル: \(title)\n"
        }
        output += "コンテンツ長: \(result.contentLength)文字\n"
        output += "---\n"
        output += result.content

        return output
    }

    // MARK: - Private Methods

    private func extractTitle(from html: String) -> String? {
        let titlePattern = #"<title[^>]*>([^<]+)</title>"#
        guard let regex = try? NSRegularExpression(pattern: titlePattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let titleRange = Range(match.range(at: 1), in: html) else {
            return nil
        }

        return String(html[titleRange])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    private func extractText(from html: String, maxLength: Int) -> String {
        var text = html

        // script, style, head などを除去
        let removePatterns = [
            #"<script[^>]*>[\s\S]*?</script>"#,
            #"<style[^>]*>[\s\S]*?</style>"#,
            #"<head[^>]*>[\s\S]*?</head>"#,
            #"<nav[^>]*>[\s\S]*?</nav>"#,
            #"<footer[^>]*>[\s\S]*?</footer>"#,
            #"<!--[\s\S]*?-->"#
        ]

        for pattern in removePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                text = regex.stringByReplacingMatches(
                    in: text,
                    range: NSRange(text.startIndex..., in: text),
                    withTemplate: ""
                )
            }
        }

        // ブロックタグを改行に
        let blockTags = ["</p>", "</div>", "</li>", "</h1>", "</h2>", "</h3>", "<br>", "<br/>"]
        for tag in blockTags {
            text = text.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }

        // 残りのタグを除去
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            text = regex.stringByReplacingMatches(
                in: text,
                range: NSRange(text.startIndex..., in: text),
                withTemplate: ""
            )
        }

        // HTMLエンティティをデコード
        text = text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")

        // 空白を正規化
        if let regex = try? NSRegularExpression(pattern: "[ \\t]+", options: []) {
            text = regex.stringByReplacingMatches(
                in: text,
                range: NSRange(text.startIndex..., in: text),
                withTemplate: " "
            )
        }
        if let regex = try? NSRegularExpression(pattern: "\\n{3,}", options: []) {
            text = regex.stringByReplacingMatches(
                in: text,
                range: NSRange(text.startIndex..., in: text),
                withTemplate: "\n\n"
            )
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.count > maxLength {
            let index = text.index(text.startIndex, offsetBy: maxLength)
            text = String(text[..<index]) + "...\n[以下省略]"
        }

        return text
    }
}
