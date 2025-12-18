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
/// - `fetch_url`: URLからコンテンツを取得
/// - `fetch_json`: URLからJSONを取得してパース
/// - `fetch_headers`: URLからHTTPヘッダーのみを取得
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
            fetchHeadersTool
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
