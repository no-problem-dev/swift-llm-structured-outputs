import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - RetryableProviderProtocol

/// リトライ機能付きプロバイダープロトコル（内部実装）
///
/// 基本的なプロバイダー機能に加えて、ヘッダー情報付きのレスポンスを返す機能を持ちます。
internal protocol RetryableProviderProtocol: LLMProvider {
    /// リクエストを送信してレスポンスとHTTPレスポンスを取得
    ///
    /// - Parameter request: LLM リクエスト
    /// - Returns: LLM レスポンスと HTTPURLResponse のタプル
    /// - Throws: `LLMError`
    func sendWithResponse(_ request: LLMRequest) async throws -> (LLMResponse, HTTPURLResponse)
}

// MARK: - RetryableProvider

/// リトライ機能を追加するプロバイダーラッパー（内部実装）
///
/// 既存の `LLMProvider` をラップし、リトライロジックを追加します。
/// リトライポリシーに基づいて、失敗したリクエストを自動的にリトライします。
internal struct RetryableProvider<ExtractorType: RateLimitInfoExtractable>: LLMProvider {
    /// 内部プロバイダー
    private let innerProvider: any RetryableProviderProtocol

    /// リトライポリシー
    private let retryPolicy: any RetryPolicy

    /// リトライイベントハンドラー
    private let eventHandler: RetryEventHandler?

    init(
        provider: any RetryableProviderProtocol,
        extractorType: ExtractorType.Type,
        retryPolicy: any RetryPolicy = ExponentialBackoffPolicy.default,
        eventHandler: RetryEventHandler? = nil
    ) {
        self.innerProvider = provider
        self.retryPolicy = retryPolicy
        self.eventHandler = eventHandler
    }

    func send(_ request: LLMRequest) async throws -> LLMResponse {
        var lastError: LLMError?
        var lastRateLimitInfo: RateLimitInfo?

        // 最大試行回数 = 初回 + リトライ回数
        let maxAttempts = retryPolicy.maxRetries + 1

        for attempt in 1...maxAttempts {
            do {
                // リクエスト送信
                let (response, httpResponse) = try await innerProvider.sendWithResponse(request)

                // 成功時はレート制限情報を抽出（将来の参考用）
                _ = ExtractorType.extractRateLimitInfo(from: httpResponse)

                return response

            } catch let rateLimitError as RateLimitAwareError {
                // RateLimitAwareError からレート制限情報を抽出
                lastRateLimitInfo = rateLimitError.rateLimitInfo
                lastError = rateLimitError.underlyingError

                // リトライ可否を判定
                guard retryPolicy.shouldRetry(error: rateLimitError.underlyingError, attempt: attempt) else {
                    throw rateLimitError.underlyingError
                }

                // 最終試行の場合は throw
                guard attempt < maxAttempts else {
                    throw rateLimitError.underlyingError
                }

                // 待機時間を計算（レート制限情報を使用）
                let delay = retryPolicy.delay(
                    for: attempt,
                    error: rateLimitError.underlyingError,
                    rateLimitInfo: lastRateLimitInfo
                )

                // リトライイベントを通知
                if let handler = eventHandler {
                    let event = RetryEvent(
                        attempt: attempt,
                        maxRetries: retryPolicy.maxRetries,
                        error: rateLimitError.underlyingError,
                        delaySeconds: delay
                    )
                    handler(event)
                }

                // 待機
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            } catch let error as LLMError {
                lastError = error

                // リトライ可否を判定
                guard retryPolicy.shouldRetry(error: error, attempt: attempt) else {
                    throw error
                }

                // 最終試行の場合は throw
                guard attempt < maxAttempts else {
                    throw error
                }

                // 待機時間を計算
                let delay = retryPolicy.delay(
                    for: attempt,
                    error: error,
                    rateLimitInfo: lastRateLimitInfo
                )

                // リトライイベントを通知
                if let handler = eventHandler {
                    let event = RetryEvent(
                        attempt: attempt,
                        maxRetries: retryPolicy.maxRetries,
                        error: error,
                        delaySeconds: delay
                    )
                    handler(event)
                }

                // 待機
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? LLMError.unknown(NSError(domain: "RetryableProvider", code: -1))
    }
}

// MARK: - RateLimitAwareError

/// レート制限情報付きエラー
///
/// HTTPレスポンスヘッダーから抽出したレート制限情報を保持するエラー型です。
/// リトライ処理で待機時間の計算に使用されます。
package struct RateLimitAwareError: Error, Sendable {
    /// 基底の LLMError
    package let underlyingError: LLMError

    /// レート制限情報
    package let rateLimitInfo: RateLimitInfo

    /// HTTPステータスコード
    package let statusCode: Int

    /// イニシャライザ
    package init(underlyingError: LLMError, rateLimitInfo: RateLimitInfo, statusCode: Int) {
        self.underlyingError = underlyingError
        self.rateLimitInfo = rateLimitInfo
        self.statusCode = statusCode
    }
}
