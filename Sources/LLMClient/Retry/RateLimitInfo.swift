import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - RateLimitInfo

/// レート制限情報
///
/// HTTPレスポンスヘッダーから抽出されたレート制限に関する情報を保持します。
/// プロバイダー固有のヘッダー形式を統一的に扱います。
package struct RateLimitInfo: Sendable {
    /// retry-after ヘッダーの値（秒）
    ///
    /// APIが明示的に指定したリトライまでの待機時間。
    /// この値が存在する場合は、計算値よりも優先して使用されます。
    let retryAfter: TimeInterval?

    /// 残りリクエスト数
    ///
    /// 現在のレート制限ウィンドウ内で許可されている残りリクエスト数。
    let remainingRequests: Int?

    /// リクエストリセットまでの時間（秒）
    ///
    /// リクエスト制限がリセットされるまでの時間。
    let requestsResetIn: TimeInterval?

    /// 残りトークン数
    ///
    /// 現在のレート制限ウィンドウ内で許可されている残りトークン数。
    let remainingTokens: Int?

    /// トークンリセットまでの時間（秒）
    ///
    /// トークン制限がリセットされるまでの時間。
    let tokensResetIn: TimeInterval?

    /// 空の情報
    static let empty = RateLimitInfo(
        retryAfter: nil,
        remainingRequests: nil,
        requestsResetIn: nil,
        remainingTokens: nil,
        tokensResetIn: nil
    )

    /// 推奨される待機時間を取得
    ///
    /// 以下の優先順位で待機時間を決定します：
    /// 1. retry-after ヘッダーの値
    /// 2. リクエストリセットまでの時間
    /// 3. トークンリセットまでの時間
    ///
    /// - Returns: 推奨待機時間（秒）、情報がない場合は nil
    var suggestedWaitTime: TimeInterval? {
        retryAfter ?? requestsResetIn ?? tokensResetIn
    }
}

// MARK: - RateLimitInfoExtractable Protocol

/// レート制限情報をHTTPレスポンスから抽出するプロトコル
///
/// 各プロバイダーはこのプロトコルに準拠し、
/// プロバイダー固有のヘッダー形式から `RateLimitInfo` を抽出します。
package protocol RateLimitInfoExtractable {
    /// HTTPレスポンスからレート制限情報を抽出
    ///
    /// - Parameter response: HTTPレスポンス
    /// - Returns: 抽出されたレート制限情報
    static func extractRateLimitInfo(from response: HTTPURLResponse) -> RateLimitInfo
}

// MARK: - OpenAI Rate Limit Header Extraction

/// OpenAI APIのレート制限ヘッダー抽出
///
/// OpenAI APIは以下のヘッダーを返します：
/// - `x-ratelimit-remaining-requests`: 残りリクエスト数
/// - `x-ratelimit-reset-requests`: リクエストリセット時間（例: "120ms", "1s"）
/// - `x-ratelimit-remaining-tokens`: 残りトークン数
/// - `x-ratelimit-reset-tokens`: トークンリセット時間
/// - `retry-after`: リトライ待機秒数（429エラー時）
package enum OpenAIRateLimitExtractor: RateLimitInfoExtractable {
    package static func extractRateLimitInfo(from response: HTTPURLResponse) -> RateLimitInfo {
        // retry-after（秒数）
        let retryAfter: TimeInterval? = response
            .value(forHTTPHeaderField: "retry-after")
            .flatMap { Double($0) }

        // 残りリクエスト数
        let remainingRequests = response
            .value(forHTTPHeaderField: "x-ratelimit-remaining-requests")
            .flatMap { Int($0) }

        // リクエストリセット時間（例: "120ms" → 0.12秒）
        let requestsResetIn = response
            .value(forHTTPHeaderField: "x-ratelimit-reset-requests")
            .flatMap { parseOpenAIResetTime($0) }

        // 残りトークン数
        let remainingTokens = response
            .value(forHTTPHeaderField: "x-ratelimit-remaining-tokens")
            .flatMap { Int($0) }

        // トークンリセット時間
        let tokensResetIn = response
            .value(forHTTPHeaderField: "x-ratelimit-reset-tokens")
            .flatMap { parseOpenAIResetTime($0) }

        return RateLimitInfo(
            retryAfter: retryAfter,
            remainingRequests: remainingRequests,
            requestsResetIn: requestsResetIn,
            remainingTokens: remainingTokens,
            tokensResetIn: tokensResetIn
        )
    }

    /// OpenAI形式のリセット時間をパース
    ///
    /// サポートする形式：
    /// - "120ms" → 0.12秒
    /// - "1s" → 1秒
    /// - "2m" → 120秒
    /// - "1h" → 3600秒
    /// - "30" → 30秒（単位なし）
    private static func parseOpenAIResetTime(_ value: String) -> TimeInterval? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)

        if trimmed.hasSuffix("ms") {
            return Double(trimmed.dropLast(2)).map { $0 / 1000 }
        } else if trimmed.hasSuffix("s") {
            return Double(trimmed.dropLast(1))
        } else if trimmed.hasSuffix("m") {
            return Double(trimmed.dropLast(1)).map { $0 * 60 }
        } else if trimmed.hasSuffix("h") {
            return Double(trimmed.dropLast(1)).map { $0 * 3600 }
        }
        return Double(trimmed)
    }
}

// MARK: - Anthropic Rate Limit Header Extraction

/// Anthropic APIのレート制限ヘッダー抽出
///
/// Anthropic APIは以下のヘッダーを返します：
/// - `anthropic-ratelimit-requests-remaining`: 残りリクエスト数
/// - `anthropic-ratelimit-requests-reset`: リセット時刻（RFC 3339形式）
/// - `anthropic-ratelimit-tokens-remaining`: 残りトークン数
/// - `anthropic-ratelimit-tokens-reset`: トークンリセット時刻
/// - `retry-after`: リトライ待機秒数（429エラー時）
package enum AnthropicRateLimitExtractor: RateLimitInfoExtractable {
    package static func extractRateLimitInfo(from response: HTTPURLResponse) -> RateLimitInfo {
        // retry-after（秒数）
        let retryAfter: TimeInterval? = response
            .value(forHTTPHeaderField: "retry-after")
            .flatMap { Double($0) }

        // 残りリクエスト数
        let remainingRequests = response
            .value(forHTTPHeaderField: "anthropic-ratelimit-requests-remaining")
            .flatMap { Int($0) }

        // リクエストリセット時刻（RFC 3339形式）
        let requestsResetIn = response
            .value(forHTTPHeaderField: "anthropic-ratelimit-requests-reset")
            .flatMap { parseRFC3339ToInterval($0) }

        // 残りトークン数（統合）
        let remainingTokens = response
            .value(forHTTPHeaderField: "anthropic-ratelimit-tokens-remaining")
            .flatMap { Int($0) }

        // トークンリセット時刻
        let tokensResetIn = response
            .value(forHTTPHeaderField: "anthropic-ratelimit-tokens-reset")
            .flatMap { parseRFC3339ToInterval($0) }

        return RateLimitInfo(
            retryAfter: retryAfter,
            remainingRequests: remainingRequests,
            requestsResetIn: requestsResetIn,
            remainingTokens: remainingTokens,
            tokensResetIn: tokensResetIn
        )
    }

    /// RFC 3339形式の時刻を現在からの秒数に変換
    ///
    /// - Parameter value: RFC 3339形式の日時文字列（例: "2024-01-15T10:30:00Z"）
    /// - Returns: 現在時刻からの秒数、パース失敗時は nil
    private static func parseRFC3339ToInterval(_ value: String) -> TimeInterval? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: value) {
            return max(0, date.timeIntervalSinceNow)
        }

        // フラクショナルセカンドなしでリトライ
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) {
            return max(0, date.timeIntervalSinceNow)
        }

        return nil
    }
}

// MARK: - Gemini Rate Limit Header Extraction

/// Gemini APIのレート制限ヘッダー抽出
///
/// Gemini APIは標準的なHTTPヘッダーを使用します：
/// - `retry-after`: リトライ待機秒数（429エラー時）
package enum GeminiRateLimitExtractor: RateLimitInfoExtractable {
    package static func extractRateLimitInfo(from response: HTTPURLResponse) -> RateLimitInfo {
        // retry-after（秒数）
        let retryAfter: TimeInterval? = response
            .value(forHTTPHeaderField: "retry-after")
            .flatMap { Double($0) }

        // Gemini APIは詳細なレート制限ヘッダーを提供しないため、
        // retry-after のみを抽出
        return RateLimitInfo(
            retryAfter: retryAfter,
            remainingRequests: nil,
            requestsResetIn: nil,
            remainingTokens: nil,
            tokensResetIn: nil
        )
    }
}
