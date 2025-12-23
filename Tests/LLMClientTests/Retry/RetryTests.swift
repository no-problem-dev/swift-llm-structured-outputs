import XCTest
@testable import LLMClient
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// リトライロジックのテスト
final class RetryTests: XCTestCase {

    // MARK: - RateLimitInfo Tests

    func testRateLimitInfoSuggestedWaitTime() {
        // retryAfter が設定されている場合
        let infoWithRetryAfter = RateLimitInfo(
            retryAfter: 30.0,
            remainingRequests: 0,
            requestsResetIn: 60.0,
            remainingTokens: nil,
            tokensResetIn: nil
        )
        XCTAssertEqual(infoWithRetryAfter.suggestedWaitTime, 30.0)

        // retryAfter がない場合、requestsResetIn を使用
        let infoWithResetIn = RateLimitInfo(
            retryAfter: nil,
            remainingRequests: 0,
            requestsResetIn: 45.0,
            remainingTokens: nil,
            tokensResetIn: nil
        )
        XCTAssertEqual(infoWithResetIn.suggestedWaitTime, 45.0)

        // 両方ない場合は nil
        let emptyInfo = RateLimitInfo(
            retryAfter: nil,
            remainingRequests: nil,
            requestsResetIn: nil,
            remainingTokens: nil,
            tokensResetIn: nil
        )
        XCTAssertNil(emptyInfo.suggestedWaitTime)
    }

    // MARK: - OpenAI Rate Limit Extractor Tests

    func testOpenAIRateLimitExtractor() {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        let headers: [String: String] = [
            "x-ratelimit-remaining-requests": "100",
            "x-ratelimit-remaining-tokens": "50000",
            "x-ratelimit-reset-requests": "120ms",
            "x-ratelimit-reset-tokens": "500ms"
        ]
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: headers
        )!

        let info = OpenAIRateLimitExtractor.extractRateLimitInfo(from: response)

        XCTAssertEqual(info.remainingRequests, 100)
        XCTAssertEqual(info.remainingTokens, 50000)
        XCTAssertNotNil(info.requestsResetIn)
        XCTAssertEqual(info.requestsResetIn!, 0.12, accuracy: 0.01)
        XCTAssertNotNil(info.tokensResetIn)
        XCTAssertEqual(info.tokensResetIn!, 0.5, accuracy: 0.01)
    }

    func testOpenAITimeParsingVariants() {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        // Test seconds format
        let headersSeconds: [String: String] = [
            "X-Ratelimit-Reset-Requests": "5s"
        ]
        let responseSeconds = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headersSeconds)!
        let infoSeconds = OpenAIRateLimitExtractor.extractRateLimitInfo(from: responseSeconds)
        XCTAssertNotNil(infoSeconds.requestsResetIn, "Expected requestsResetIn to be non-nil for '5s'")
        if let resetIn = infoSeconds.requestsResetIn {
            XCTAssertEqual(resetIn, 5.0, accuracy: 0.01)
        }

        // Test minutes format
        let headersMinutes: [String: String] = [
            "X-Ratelimit-Reset-Requests": "2m"
        ]
        let responseMinutes = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headersMinutes)!
        let infoMinutes = OpenAIRateLimitExtractor.extractRateLimitInfo(from: responseMinutes)
        XCTAssertNotNil(infoMinutes.requestsResetIn, "Expected requestsResetIn to be non-nil for '2m'")
        if let resetIn = infoMinutes.requestsResetIn {
            XCTAssertEqual(resetIn, 120.0, accuracy: 0.01)
        }

        // Test milliseconds format
        let headersMs: [String: String] = [
            "X-Ratelimit-Reset-Requests": "500ms"
        ]
        let responseMs = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headersMs)!
        let infoMs = OpenAIRateLimitExtractor.extractRateLimitInfo(from: responseMs)
        XCTAssertNotNil(infoMs.requestsResetIn, "Expected requestsResetIn to be non-nil for '500ms'")
        if let resetIn = infoMs.requestsResetIn {
            XCTAssertEqual(resetIn, 0.5, accuracy: 0.01)
        }

        // Test hours format
        let headersHours: [String: String] = [
            "X-Ratelimit-Reset-Requests": "1h"
        ]
        let responseHours = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headersHours)!
        let infoHours = OpenAIRateLimitExtractor.extractRateLimitInfo(from: responseHours)
        XCTAssertNotNil(infoHours.requestsResetIn, "Expected requestsResetIn to be non-nil for '1h'")
        if let resetIn = infoHours.requestsResetIn {
            XCTAssertEqual(resetIn, 3600.0, accuracy: 0.01)
        }

        // Test numeric format (without unit)
        let headersNumeric: [String: String] = [
            "X-Ratelimit-Reset-Requests": "30"
        ]
        let responseNumeric = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headersNumeric)!
        let infoNumeric = OpenAIRateLimitExtractor.extractRateLimitInfo(from: responseNumeric)
        XCTAssertNotNil(infoNumeric.requestsResetIn, "Expected requestsResetIn to be non-nil for '30'")
        if let resetIn = infoNumeric.requestsResetIn {
            XCTAssertEqual(resetIn, 30.0, accuracy: 0.01)
        }
    }

    // MARK: - Anthropic Rate Limit Extractor Tests

    func testAnthropicRateLimitExtractor() {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        let headers: [String: String] = [
            "retry-after": "30",
            "anthropic-ratelimit-requests-remaining": "50",
            "anthropic-ratelimit-tokens-remaining": "25000"
        ]
        let response = HTTPURLResponse(
            url: url,
            statusCode: 429,
            httpVersion: nil,
            headerFields: headers
        )!

        let info = AnthropicRateLimitExtractor.extractRateLimitInfo(from: response)

        XCTAssertEqual(info.retryAfter, 30.0)
        XCTAssertEqual(info.remainingRequests, 50)
        XCTAssertEqual(info.remainingTokens, 25000)
    }

    func testAnthropicRFC3339Parsing() {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!

        // RFC 3339 形式のタイムスタンプをテスト
        let futureDate = Date().addingTimeInterval(60) // 1分後
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateString = formatter.string(from: futureDate)

        let headers: [String: String] = [
            "anthropic-ratelimit-requests-reset": dateString
        ]
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)!

        let info = AnthropicRateLimitExtractor.extractRateLimitInfo(from: response)

        // requestsResetIn は約60秒であるべき（少し誤差を許容）
        XCTAssertNotNil(info.requestsResetIn)
        if let resetIn = info.requestsResetIn {
            XCTAssertGreaterThan(resetIn, 50.0)
            XCTAssertLessThan(resetIn, 70.0)
        }
    }

    // MARK: - RetryPolicy Tests

    func testExponentialBackoffDelay() {
        let policy = ExponentialBackoffPolicy(
            maxRetries: 5,
            baseDelay: 1.0,
            maxDelay: 60.0
        )

        // Attempt 1: baseDelay * 2^0 = 1.0 (+ jitter)
        let delay1 = policy.delay(for: 1, error: .rateLimitExceeded, rateLimitInfo: nil)
        XCTAssertGreaterThanOrEqual(delay1, 1.0)
        XCTAssertLessThanOrEqual(delay1, 2.0) // jitter adds up to 100%

        // Attempt 2: baseDelay * 2^1 = 2.0 (+ jitter)
        let delay2 = policy.delay(for: 2, error: .rateLimitExceeded, rateLimitInfo: nil)
        XCTAssertGreaterThanOrEqual(delay2, 2.0)
        XCTAssertLessThanOrEqual(delay2, 4.0)

        // Attempt 3: baseDelay * 2^2 = 4.0 (+ jitter)
        let delay3 = policy.delay(for: 3, error: .rateLimitExceeded, rateLimitInfo: nil)
        XCTAssertGreaterThanOrEqual(delay3, 4.0)
        XCTAssertLessThanOrEqual(delay3, 8.0)
    }

    func testExponentialBackoffMaxDelay() {
        let policy = ExponentialBackoffPolicy(
            maxRetries: 10,
            baseDelay: 1.0,
            maxDelay: 10.0
        )

        // Attempt 5: baseDelay * 2^4 = 16.0 -> capped to 10.0
        let delay5 = policy.delay(for: 5, error: .rateLimitExceeded, rateLimitInfo: nil)
        XCTAssertGreaterThanOrEqual(delay5, 10.0)
        XCTAssertLessThanOrEqual(delay5, 20.0) // max + jitter
    }

    func testExponentialBackoffUsesRateLimitInfo() {
        let policy = ExponentialBackoffPolicy(
            maxRetries: 5,
            baseDelay: 1.0,
            maxDelay: 60.0
        )

        let rateLimitInfo = RateLimitInfo(
            retryAfter: 30.0,
            remainingRequests: 0,
            requestsResetIn: nil,
            remainingTokens: nil,
            tokensResetIn: nil
        )

        // RateLimitInfo の suggestedWaitTime を使用
        let delay = policy.delay(for: 1, error: .rateLimitExceeded, rateLimitInfo: rateLimitInfo)
        XCTAssertGreaterThanOrEqual(delay, 30.0)
    }

    func testRetryPolicyShouldRetry() {
        let policy = ExponentialBackoffPolicy(
            maxRetries: 3,
            baseDelay: 1.0,
            maxDelay: 60.0
        )

        // リトライ可能なエラー
        XCTAssertTrue(policy.shouldRetry(error: .rateLimitExceeded, attempt: 1))
        XCTAssertTrue(policy.shouldRetry(error: .serverError(500, "Internal Server Error"), attempt: 1))
        XCTAssertTrue(policy.shouldRetry(error: .serverError(502, "Bad Gateway"), attempt: 1))
        XCTAssertTrue(policy.shouldRetry(error: .serverError(503, "Service Unavailable"), attempt: 1))
        XCTAssertTrue(policy.shouldRetry(error: .timeout, attempt: 1))

        // リトライ不可能なエラー
        XCTAssertFalse(policy.shouldRetry(error: .unauthorized, attempt: 1))
        XCTAssertFalse(policy.shouldRetry(error: .invalidRequest("Bad request"), attempt: 1))
        XCTAssertFalse(policy.shouldRetry(error: .modelNotFound("not found"), attempt: 1))
        XCTAssertFalse(policy.shouldRetry(error: .emptyResponse, attempt: 1))

        // maxRetries を超えた場合
        XCTAssertTrue(policy.shouldRetry(error: .rateLimitExceeded, attempt: 3))
        XCTAssertFalse(policy.shouldRetry(error: .rateLimitExceeded, attempt: 4))
    }

    func testNoRetryPolicy() {
        let policy = NoRetryPolicy.shared

        XCTAssertEqual(policy.maxRetries, 0)
        XCTAssertFalse(policy.shouldRetry(error: .rateLimitExceeded, attempt: 1))
        XCTAssertEqual(policy.delay(for: 1, error: .rateLimitExceeded, rateLimitInfo: nil), 0)
    }

    // MARK: - RetryConfiguration Tests

    func testRetryConfigurationPresets() {
        // Default
        XCTAssertTrue(RetryConfiguration.default.isEnabled)
        XCTAssertEqual(RetryConfiguration.default.maxRetries, 5)
        XCTAssertEqual(RetryConfiguration.default.baseDelay, 1.0)
        XCTAssertEqual(RetryConfiguration.default.maxDelay, 60.0)

        // Disabled
        XCTAssertFalse(RetryConfiguration.disabled.isEnabled)
        XCTAssertEqual(RetryConfiguration.disabled.maxRetries, 0)

        // Aggressive
        XCTAssertTrue(RetryConfiguration.aggressive.isEnabled)
        XCTAssertEqual(RetryConfiguration.aggressive.maxRetries, 10)
        XCTAssertEqual(RetryConfiguration.aggressive.baseDelay, 0.5)
        XCTAssertEqual(RetryConfiguration.aggressive.maxDelay, 120.0)

        // Conservative
        XCTAssertTrue(RetryConfiguration.conservative.isEnabled)
        XCTAssertEqual(RetryConfiguration.conservative.maxRetries, 3)
        XCTAssertEqual(RetryConfiguration.conservative.baseDelay, 2.0)
        XCTAssertEqual(RetryConfiguration.conservative.maxDelay, 30.0)
    }

    func testRetryConfigurationCustom() {
        let custom = RetryConfiguration.custom(maxRetries: 7, baseDelay: 1.5, maxDelay: 45.0)
        XCTAssertTrue(custom.isEnabled)
        XCTAssertEqual(custom.maxRetries, 7)
        XCTAssertEqual(custom.baseDelay, 1.5)
        XCTAssertEqual(custom.maxDelay, 45.0)

        let customZero = RetryConfiguration.custom(maxRetries: 0)
        XCTAssertFalse(customZero.isEnabled)
    }

    // MARK: - RetryEvent Tests

    func testRetryEventProperties() {
        let event = RetryEvent(
            attempt: 2,
            maxRetries: 5,
            error: .rateLimitExceeded,
            delaySeconds: 4.0
        )

        XCTAssertEqual(event.attempt, 2)
        XCTAssertEqual(event.maxRetries, 5)
        XCTAssertEqual(event.delaySeconds, 4.0)
        XCTAssertEqual(event.remainingRetries, 3)
        XCTAssertEqual(event.reason, "Rate limit exceeded")
    }

    func testRetryEventReasons() {
        let rateLimitEvent = RetryEvent(attempt: 1, maxRetries: 3, error: .rateLimitExceeded, delaySeconds: 1.0)
        XCTAssertEqual(rateLimitEvent.reason, "Rate limit exceeded")

        let serverErrorEvent = RetryEvent(attempt: 1, maxRetries: 3, error: .serverError(500, "error"), delaySeconds: 1.0)
        XCTAssertEqual(serverErrorEvent.reason, "Server error (500)")

        let timeoutEvent = RetryEvent(attempt: 1, maxRetries: 3, error: .timeout, delaySeconds: 1.0)
        XCTAssertEqual(timeoutEvent.reason, "Request timeout")

        let networkErrorEvent = RetryEvent(
            attempt: 1,
            maxRetries: 3,
            error: .networkError(NSError(domain: "test", code: -1)),
            delaySeconds: 1.0
        )
        XCTAssertEqual(networkErrorEvent.reason, "Network error")
    }

    // MARK: - LLMError isRetryable Tests

    func testLLMErrorIsRetryable() {
        // Retryable errors
        XCTAssertTrue(LLMError.rateLimitExceeded.isRetryable)
        XCTAssertTrue(LLMError.serverError(500, "error").isRetryable)
        XCTAssertTrue(LLMError.serverError(502, "error").isRetryable)
        XCTAssertTrue(LLMError.serverError(503, "error").isRetryable)
        XCTAssertTrue(LLMError.timeout.isRetryable)
        XCTAssertTrue(LLMError.networkError(NSError(domain: "test", code: -1)).isRetryable)

        // Non-retryable errors
        XCTAssertFalse(LLMError.unauthorized.isRetryable)
        XCTAssertFalse(LLMError.invalidRequest("bad").isRetryable)
        XCTAssertFalse(LLMError.modelNotFound("model").isRetryable)
        XCTAssertFalse(LLMError.modelNotSupported(model: "m", provider: "p").isRetryable)
        XCTAssertFalse(LLMError.emptyResponse.isRetryable)
        XCTAssertFalse(LLMError.invalidEncoding.isRetryable)
        XCTAssertFalse(LLMError.decodingFailed(NSError(domain: "test", code: -1)).isRetryable)
        XCTAssertFalse(LLMError.contentBlocked(reason: nil).isRetryable)
    }

    // MARK: - Client Initialization with Retry Tests

    func testClientInitWithDefaultRetry() {
        let anthropicClient = AnthropicClient(apiKey: "test-key")
        XCTAssertNotNil(anthropicClient)

        let openAIClient = OpenAIClient(apiKey: "test-key")
        XCTAssertNotNil(openAIClient)

        let geminiClient = GeminiClient(apiKey: "test-key")
        XCTAssertNotNil(geminiClient)
    }

    func testClientInitWithDisabledRetry() {
        let anthropicClient = AnthropicClient(
            apiKey: "test-key",
            retryConfiguration: .disabled
        )
        XCTAssertNotNil(anthropicClient)

        let openAIClient = OpenAIClient(
            apiKey: "test-key",
            retryConfiguration: .disabled
        )
        XCTAssertNotNil(openAIClient)

        let geminiClient = GeminiClient(
            apiKey: "test-key",
            retryConfiguration: .disabled
        )
        XCTAssertNotNil(geminiClient)
    }

    func testClientInitWithCustomRetry() {
        let handler: RetryEventHandler = { event in
            // Note: We can't easily test the handler without mocking network calls
            // Just verify the event has valid properties
            _ = event.attempt
            _ = event.maxRetries
            _ = event.delaySeconds
        }

        let client = AnthropicClient(
            apiKey: "test-key",
            retryConfiguration: .custom(maxRetries: 10, baseDelay: 0.5),
            retryEventHandler: handler
        )
        XCTAssertNotNil(client)
    }

    func testClientInitWithAggressiveRetry() {
        let client = OpenAIClient(
            apiKey: "test-key",
            retryConfiguration: .aggressive
        )
        XCTAssertNotNil(client)
    }

    func testClientInitWithConservativeRetry() {
        let client = GeminiClient(
            apiKey: "test-key",
            retryConfiguration: .conservative
        )
        XCTAssertNotNil(client)
    }

    // MARK: - RateLimitAwareError Tests

    func testRateLimitAwareError() {
        let rateLimitInfo = RateLimitInfo(
            retryAfter: 30.0,
            remainingRequests: 0,
            requestsResetIn: 60.0,
            remainingTokens: nil,
            tokensResetIn: nil
        )

        let error = RateLimitAwareError(
            underlyingError: .rateLimitExceeded,
            rateLimitInfo: rateLimitInfo,
            statusCode: 429
        )

        XCTAssertEqual(error.statusCode, 429)
        XCTAssertEqual(error.rateLimitInfo.retryAfter, 30.0)
        if case .rateLimitExceeded = error.underlyingError {
            // Expected
        } else {
            XCTFail("Expected rateLimitExceeded error")
        }
    }
}
