//
//  BraveSearchService.swift
//  ConversationAgentExample
//
//  Brave Search API クライアント
//

import Foundation

/// Brave Search API サービス
///
/// Web検索機能を提供します。月2000件まで無料で利用可能です。
/// API Key: https://api.search.brave.com/
actor BraveSearchService {

    // MARK: - Types

    /// 検索結果
    struct SearchResult: Codable, Sendable {
        let title: String
        let url: String
        let description: String
    }

    /// API レスポンス
    private struct APIResponse: Codable {
        let web: WebResults?

        struct WebResults: Codable {
            let results: [WebResult]
        }

        struct WebResult: Codable {
            let title: String
            let url: String
            let description: String?
        }
    }

    /// エラー型
    enum ServiceError: LocalizedError {
        case noAPIKey
        case invalidURL
        case requestFailed(statusCode: Int)
        case decodingFailed(Error)
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "Brave Search API キーが設定されていません"
            case .invalidURL:
                return "無効な URL です"
            case .requestFailed(let statusCode):
                return "リクエストが失敗しました（ステータスコード: \(statusCode)）"
            case .decodingFailed(let error):
                return "レスポンスのデコードに失敗しました: \(error.localizedDescription)"
            case .networkError(let error):
                return "ネットワークエラー: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Properties

    private let session: URLSession
    private let baseURL = "https://api.search.brave.com/res/v1/web/search"

    // MARK: - Initialization

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public Methods

    /// Web検索を実行
    func search(query: String, count: Int = 5) async throws -> [SearchResult] {
        guard let apiKey = APIKeyManager.braveSearchKey else {
            throw ServiceError.noAPIKey
        }

        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: String(min(count, 20)))
        ]

        guard let url = components?.url else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "X-Subscription-Token")

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

        let apiResponse: APIResponse
        do {
            apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
        } catch {
            throw ServiceError.decodingFailed(error)
        }

        guard let webResults = apiResponse.web?.results else {
            return []
        }

        return webResults.map { result in
            SearchResult(
                title: result.title,
                url: result.url,
                description: result.description ?? ""
            )
        }
    }

    /// 検索結果をフォーマットされた文字列として取得
    func searchFormatted(query: String, count: Int = 5) async throws -> String {
        let results = try await search(query: query, count: count)

        if results.isEmpty {
            return "「\(query)」に関する検索結果は見つかりませんでした。"
        }

        var output = "「\(query)」の検索結果（\(results.count)件）:\n\n"

        for (index, result) in results.enumerated() {
            output += "[\(index + 1)] \(result.title)\n"
            output += "URL: \(result.url)\n"
            output += "概要: \(result.description)\n\n"
        }

        return output
    }
}
