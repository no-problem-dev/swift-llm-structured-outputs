import Foundation
import LLMClient
import LLMTool

// MARK: - WebToolKit

/// Web操作ツールを提供するToolKit
///
/// URLからコンテンツを取得するツールを提供します。
///
/// ## 使用例
///
/// ```swift
/// let tools = ToolSet {
///     WebToolKit()
/// }
///
/// // または特定のドメインのみ許可
/// let restrictedTools = ToolSet {
///     WebToolKit(allowedDomains: ["api.example.com", "data.example.com"])
/// }
/// ```
///
/// ## 提供されるツール
///
/// - `fetch_url`: URLからコンテンツを取得（生のテキスト）
/// - `fetch_json`: URLからJSONを取得してパース
/// - `fetch_headers`: URLからHTTPヘッダーのみを取得
/// - `fetch_page`: Webページからテキストを抽出（HTML解析、ページネーション対応）
public final class WebToolKit: ToolKit, @unchecked Sendable {
    // MARK: - Properties

    public let name: String = "web"

    /// 許可されたドメイン（nilの場合は全て許可）
    private let allowedDomains: Set<String>?

    /// URLSession
    private let session: URLSession

    /// タイムアウト秒数
    private let timeout: TimeInterval

    /// 最大コンテンツサイズ（バイト）
    private let maxContentSize: Int

    // MARK: - Initialization

    /// WebToolKitを作成
    ///
    /// - Parameters:
    ///   - allowedDomains: 許可するドメインの配列（nilの場合は全て許可）
    ///   - timeout: リクエストのタイムアウト秒数（デフォルト: 30）
    ///   - maxContentSize: 最大取得サイズ（デフォルト: 5MB）
    public init(
        allowedDomains: [String]? = nil,
        timeout: TimeInterval = 30,
        maxContentSize: Int = 5 * 1024 * 1024
    ) {
        self.allowedDomains = allowedDomains.map { Set($0.map { $0.lowercased() }) }
        self.timeout = timeout
        self.maxContentSize = maxContentSize

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        self.session = URLSession(configuration: config)
    }

    // MARK: - ToolKit Protocol

    public var tools: [any Tool] {
        [
            fetchURLTool,
            fetchJSONTool,
            fetchHeadersTool,
            fetchPageTool
        ]
    }

    // MARK: - Domain Validation

    /// ドメインが許可されているかチェック
    private func validateURL(_ urlString: String) throws -> URL {
        guard let url = URL(string: urlString) else {
            throw WebToolKitError.invalidURL(urlString)
        }

        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw WebToolKitError.unsupportedScheme(url.scheme ?? "unknown")
        }

        if let allowedDomains = allowedDomains,
           let host = url.host?.lowercased(),
           !allowedDomains.contains(host) {
            throw WebToolKitError.domainNotAllowed(host, allowed: Array(allowedDomains))
        }

        return url
    }

    // MARK: - Tool Definitions

    /// fetch_url ツール
    private var fetchURLTool: BuiltInTool {
        BuiltInTool(
            name: "fetch_url",
            description: "Fetch content from a URL. Returns the raw text content.",
            inputSchema: .object(
                properties: [
                    "url": .string(description: "The URL to fetch content from"),
                    "method": .string(description: "HTTP method (GET, POST, PUT, DELETE). Default: GET"),
                    "headers": .object(
                        description: "Custom HTTP headers to send",
                        properties: [:],
                        required: [],
                        additionalProperties: true
                    ),
                    "body": .string(description: "Request body (for POST/PUT)")
                ],
                required: ["url"]
            ),
            annotations: ToolAnnotations(
                title: "Fetch URL",
                readOnlyHint: true,
                openWorldHint: true
            )
        ) { [self] data in
            let input = try JSONDecoder().decode(FetchURLInput.self, from: data)
            let url = try validateURL(input.url)

            var request = URLRequest(url: url)
            request.httpMethod = input.method ?? "GET"

            if let headers = input.headers {
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }

            if let body = input.body {
                request.httpBody = body.data(using: .utf8)
            }

            let (responseData, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw WebToolKitError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw WebToolKitError.httpError(statusCode: httpResponse.statusCode)
            }

            guard responseData.count <= maxContentSize else {
                throw WebToolKitError.contentTooLarge(size: responseData.count, maxSize: maxContentSize)
            }

            guard let content = String(data: responseData, encoding: .utf8) else {
                throw WebToolKitError.encodingError
            }

            let result = FetchResult(
                url: url.absoluteString,
                statusCode: httpResponse.statusCode,
                contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"),
                contentLength: responseData.count,
                content: content
            )

            let output = try JSONEncoder().encode(result)
            return .json(output)
        }
    }

    /// fetch_json ツール
    private var fetchJSONTool: BuiltInTool {
        BuiltInTool(
            name: "fetch_json",
            description: "Fetch JSON from a URL and parse it. Returns the parsed JSON data.",
            inputSchema: .object(
                properties: [
                    "url": .string(description: "The URL to fetch JSON from"),
                    "method": .string(description: "HTTP method (GET, POST, PUT, DELETE). Default: GET"),
                    "headers": .object(
                        description: "Custom HTTP headers to send",
                        properties: [:],
                        required: [],
                        additionalProperties: true
                    ),
                    "body": .string(description: "Request body (for POST/PUT)")
                ],
                required: ["url"]
            ),
            annotations: ToolAnnotations(
                title: "Fetch JSON",
                readOnlyHint: true,
                openWorldHint: true
            )
        ) { [self] data in
            let input = try JSONDecoder().decode(FetchURLInput.self, from: data)
            let url = try validateURL(input.url)

            var request = URLRequest(url: url)
            request.httpMethod = input.method ?? "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            if let headers = input.headers {
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }

            if let body = input.body {
                request.httpBody = body.data(using: .utf8)
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            }

            let (responseData, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw WebToolKitError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw WebToolKitError.httpError(statusCode: httpResponse.statusCode)
            }

            guard responseData.count <= maxContentSize else {
                throw WebToolKitError.contentTooLarge(size: responseData.count, maxSize: maxContentSize)
            }

            // JSONとしてパース
            let jsonObject = try JSONSerialization.jsonObject(with: responseData)

            let result = FetchJSONResult(
                url: url.absoluteString,
                statusCode: httpResponse.statusCode,
                data: jsonObject
            )

            // カスタムエンコード（dataフィールドはAny型なので）
            let resultDict: [String: Any] = [
                "url": result.url,
                "statusCode": result.statusCode,
                "data": result.data
            ]

            let output = try JSONSerialization.data(withJSONObject: resultDict)
            return .json(output)
        }
    }

    /// fetch_headers ツール
    private var fetchHeadersTool: BuiltInTool {
        BuiltInTool(
            name: "fetch_headers",
            description: "Fetch only HTTP headers from a URL using HEAD request. Useful for checking resource existence or metadata.",
            inputSchema: .object(
                properties: [
                    "url": .string(description: "The URL to fetch headers from")
                ],
                required: ["url"]
            ),
            annotations: ToolAnnotations(
                title: "Fetch Headers",
                readOnlyHint: true,
                openWorldHint: true
            )
        ) { [self] data in
            let input = try JSONDecoder().decode(FetchHeadersInput.self, from: data)
            let url = try validateURL(input.url)

            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"

            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw WebToolKitError.invalidResponse
            }

            var headers: [String: String] = [:]
            for (key, value) in httpResponse.allHeaderFields {
                if let keyString = key as? String, let valueString = value as? String {
                    headers[keyString] = valueString
                }
            }

            let result = FetchHeadersResult(
                url: url.absoluteString,
                statusCode: httpResponse.statusCode,
                headers: headers
            )

            let output = try JSONEncoder().encode(result)
            return .json(output)
        }
    }

    /// fetch_page ツール（Webページからテキストを抽出）
    private var fetchPageTool: BuiltInTool {
        BuiltInTool(
            name: "fetch_page",
            description: "Fetch a web page and extract readable text content. Removes scripts, styles, navigation, and other non-essential elements. Use start_index for pagination when content is truncated.",
            inputSchema: .object(
                properties: [
                    "url": .string(description: "The URL of the web page to fetch"),
                    "max_length": .integer(description: "Maximum characters to return (default: 5000)"),
                    "start_index": .integer(description: "Start position for pagination. Use when previous response indicated more content available (default: 0)")
                ],
                required: ["url"]
            ),
            annotations: ToolAnnotations(
                title: "Fetch Web Page",
                readOnlyHint: true,
                openWorldHint: true
            )
        ) { [self] data in
            let input = try JSONDecoder().decode(FetchPageInput.self, from: data)
            let url = try validateURL(input.url)
            let maxLength = input.maxLength ?? 5000
            let startIndex = input.startIndex ?? 0

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
                forHTTPHeaderField: "User-Agent"
            )
            request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            request.setValue("ja,en;q=0.9", forHTTPHeaderField: "Accept-Language")

            let (responseData, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw WebToolKitError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw WebToolKitError.httpError(statusCode: httpResponse.statusCode)
            }

            guard responseData.count <= maxContentSize else {
                throw WebToolKitError.contentTooLarge(size: responseData.count, maxSize: maxContentSize)
            }

            guard let html = String(data: responseData, encoding: .utf8)
                    ?? String(data: responseData, encoding: .ascii) else {
                throw WebToolKitError.encodingError
            }

            // タイトルとテキストを抽出
            let title = HTMLContentExtractor.extractTitle(from: html)
            let fullText = HTMLContentExtractor.extractText(from: html)

            // ページネーション処理
            let totalLength = fullText.count
            let safeStartIndex = min(startIndex, max(0, totalLength - 1))

            let endIndex = min(safeStartIndex + maxLength, totalLength)
            let hasMore = endIndex < totalLength

            let content: String
            if safeStartIndex < totalLength {
                let start = fullText.index(fullText.startIndex, offsetBy: safeStartIndex)
                let end = fullText.index(fullText.startIndex, offsetBy: endIndex)
                content = String(fullText[start..<end])
            } else {
                content = ""
            }

            let result = FetchPageResult(
                url: url.absoluteString,
                title: title,
                content: content,
                contentLength: totalLength,
                startIndex: safeStartIndex,
                hasMore: hasMore
            )

            let output = try JSONEncoder().encode(result)
            return .json(output)
        }
    }
}

// MARK: - Input Types

private struct FetchURLInput: Codable {
    var url: String
    var method: String?
    var headers: [String: String]?
    var body: String?
}

private struct FetchHeadersInput: Codable {
    var url: String
}

private struct FetchPageInput: Codable {
    var url: String
    var maxLength: Int?
    var startIndex: Int?

    enum CodingKeys: String, CodingKey {
        case url
        case maxLength = "max_length"
        case startIndex = "start_index"
    }
}

// MARK: - Result Types

private struct FetchResult: Codable {
    var url: String
    var statusCode: Int
    var contentType: String?
    var contentLength: Int
    var content: String
}

private struct FetchJSONResult {
    var url: String
    var statusCode: Int
    var data: Any
}

private struct FetchHeadersResult: Codable {
    var url: String
    var statusCode: Int
    var headers: [String: String]
}

private struct FetchPageResult: Codable {
    var url: String
    var title: String?
    var content: String
    var contentLength: Int
    var startIndex: Int
    var hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case url
        case title
        case content
        case contentLength = "content_length"
        case startIndex = "start_index"
        case hasMore = "has_more"
    }
}

// MARK: - HTML Content Extraction

/// HTMLからテキストを抽出するためのヘルパー
private enum HTMLContentExtractor {

    /// HTMLからタイトルを抽出
    static func extractTitle(from html: String) -> String? {
        let pattern = #"<title[^>]*>([^<]+)</title>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let titleRange = Range(match.range(at: 1), in: html) else {
            return nil
        }

        return String(html[titleRange])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .decodingHTMLEntities()
    }

    /// HTMLからメインコンテンツのテキストを抽出
    static func extractText(from html: String) -> String {
        var text = html

        // 不要なタグを除去（script, style, head, nav, footer, コメント）
        let removePatterns = [
            #"<script[^>]*>[\s\S]*?</script>"#,
            #"<style[^>]*>[\s\S]*?</style>"#,
            #"<head[^>]*>[\s\S]*?</head>"#,
            #"<nav[^>]*>[\s\S]*?</nav>"#,
            #"<footer[^>]*>[\s\S]*?</footer>"#,
            #"<aside[^>]*>[\s\S]*?</aside>"#,
            #"<header[^>]*>[\s\S]*?</header>"#,
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

        // ブロックタグを改行に変換
        let blockTags = ["</p>", "</div>", "</li>", "</h1>", "</h2>", "</h3>", "</h4>", "</h5>", "</h6>", "</tr>", "<br>", "<br/>", "<br />"]
        for tag in blockTags {
            text = text.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }

        // 残りのHTMLタグを除去
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            text = regex.stringByReplacingMatches(
                in: text,
                range: NSRange(text.startIndex..., in: text),
                withTemplate: ""
            )
        }

        // HTMLエンティティをデコード
        text = text.decodingHTMLEntities()

        // 各行をトリムして空行を除去
        let lines = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        // 空行を最大1つにまとめる
        var result: [String] = []
        var previousWasEmpty = false

        for line in lines {
            if line.isEmpty {
                if !previousWasEmpty && !result.isEmpty {
                    result.append("")  // 空行は1つだけ許可
                }
                previousWasEmpty = true
            } else {
                result.append(line)
                previousWasEmpty = false
            }
        }

        return result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    /// HTMLエンティティをデコード
    func decodingHTMLEntities() -> String {
        var result = self
        let entities: [(String, String)] = [
            ("&nbsp;", " "),
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#39;", "'"),
            ("&ndash;", "–"),
            ("&mdash;", "—"),
            ("&hellip;", "…"),
            ("&copy;", "©"),
            ("&reg;", "®"),
            ("&trade;", "™")
        ]

        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        // 数値エンティティ &#123; 形式
        if let regex = try? NSRegularExpression(pattern: "&#(\\d+);", options: []) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let range = Range(match.range, in: result),
                   let codeRange = Range(match.range(at: 1), in: result),
                   let code = Int(result[codeRange]),
                   let scalar = Unicode.Scalar(code) {
                    result.replaceSubrange(range, with: String(Character(scalar)))
                }
            }
        }

        return result
    }
}

// MARK: - Errors

/// WebToolKitのエラー
public enum WebToolKitError: Error, LocalizedError {
    case invalidURL(String)
    case unsupportedScheme(String)
    case domainNotAllowed(String, allowed: [String])
    case invalidResponse
    case httpError(statusCode: Int)
    case contentTooLarge(size: Int, maxSize: Int)
    case encodingError
    case jsonParseError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .unsupportedScheme(let scheme):
            return "Unsupported URL scheme: \(scheme). Only http and https are supported."
        case .domainNotAllowed(let domain, let allowed):
            return "Domain '\(domain)' is not allowed. Allowed domains: \(allowed.joined(separator: ", "))"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .contentTooLarge(let size, let maxSize):
            return "Content too large: \(size) bytes (max: \(maxSize) bytes)"
        case .encodingError:
            return "Could not decode response as UTF-8"
        case .jsonParseError(let message):
            return "JSON parse error: \(message)"
        }
    }
}
