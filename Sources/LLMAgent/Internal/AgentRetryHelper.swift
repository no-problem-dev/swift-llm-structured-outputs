import Foundation
import LLMClient
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - AgentRetryHelper

/// エージェントリクエストのリトライを管理するヘルパー
///
/// HTTPリクエストの実行とリトライロジックをカプセル化します。
/// 各プロバイダー固有のレート制限情報抽出機能を使用して、
/// 適切な待機時間を計算します。
internal struct AgentRetryHelper<ExtractorType: RateLimitInfoExtractable> {

    /// リトライポリシー
    private let retryPolicy: any RetryPolicy

    /// リトライイベントハンドラー
    private let eventHandler: RetryEventHandler?

    /// イニシャライザ
    ///
    /// - Parameters:
    ///   - retryPolicy: リトライポリシー
    ///   - eventHandler: リトライイベントハンドラー（省略可）
    init(
        retryPolicy: any RetryPolicy,
        eventHandler: RetryEventHandler? = nil
    ) {
        self.retryPolicy = retryPolicy
        self.eventHandler = eventHandler
    }

    /// RetryConfiguration からイニシャライズ
    ///
    /// - Parameters:
    ///   - configuration: リトライ設定
    ///   - eventHandler: リトライイベントハンドラー（省略可）
    init(
        configuration: RetryConfiguration,
        eventHandler: RetryEventHandler? = nil
    ) {
        self.retryPolicy = configuration.policy
        self.eventHandler = eventHandler
    }

    /// リトライ付きでHTTPリクエストを実行
    ///
    /// - Parameters:
    ///   - session: URLSession
    ///   - request: URLRequest
    ///   - parseError: HTTPステータスコードとデータからLLMErrorを生成するクロージャ
    ///   - parseResponse: 成功レスポンスからLLMResponseを生成するクロージャ
    /// - Returns: LLMResponse
    /// - Throws: LLMError
    func execute(
        session: URLSession,
        request: URLRequest,
        parseError: (Data, Int) throws -> LLMError,
        parseResponse: (Data, HTTPURLResponse) throws -> LLMResponse
    ) async throws -> LLMResponse {
        var lastError: LLMError?
        var lastRateLimitInfo: RateLimitInfo?

        let maxAttempts = retryPolicy.maxRetries + 1

        for attempt in 1...maxAttempts {
            do {
                // リクエストを送信
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw LLMError.invalidRequest("Invalid response type")
                }

                // レート制限情報を抽出
                let rateLimitInfo = ExtractorType.extractRateLimitInfo(from: httpResponse)
                lastRateLimitInfo = rateLimitInfo

                // ステータスコードが200以外の場合はエラー処理
                if httpResponse.statusCode != 200 {
                    let error = try parseError(data, httpResponse.statusCode)
                    throw RateLimitAwareError(
                        underlyingError: error,
                        rateLimitInfo: rateLimitInfo,
                        statusCode: httpResponse.statusCode
                    )
                }

                // 成功レスポンスを処理
                return try parseResponse(data, httpResponse)

            } catch let rateLimitError as RateLimitAwareError {
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

                // 待機時間を計算
                let delay = retryPolicy.delay(
                    for: attempt,
                    error: rateLimitError.underlyingError,
                    rateLimitInfo: lastRateLimitInfo
                )

                // リトライイベントを通知
                notifyRetryEvent(attempt: attempt, error: rateLimitError.underlyingError, delay: delay)

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
                notifyRetryEvent(attempt: attempt, error: error, delay: delay)

                // 待機
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            } catch {
                // URLSession のエラーをネットワークエラーとして処理
                let llmError = LLMError.networkError(error)
                lastError = llmError

                // リトライ可否を判定
                guard retryPolicy.shouldRetry(error: llmError, attempt: attempt) else {
                    throw llmError
                }

                // 最終試行の場合は throw
                guard attempt < maxAttempts else {
                    throw llmError
                }

                // 待機時間を計算
                let delay = retryPolicy.delay(
                    for: attempt,
                    error: llmError,
                    rateLimitInfo: lastRateLimitInfo
                )

                // リトライイベントを通知
                notifyRetryEvent(attempt: attempt, error: llmError, delay: delay)

                // 待機
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? LLMError.unknown(NSError(domain: "AgentRetryHelper", code: -1))
    }

    /// リトライイベントを通知
    private func notifyRetryEvent(attempt: Int, error: LLMError, delay: TimeInterval) {
        guard let handler = eventHandler else { return }

        let event = RetryEvent(
            attempt: attempt,
            maxRetries: retryPolicy.maxRetries,
            error: error,
            delaySeconds: delay
        )
        handler(event)
    }
}
