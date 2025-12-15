import Foundation

// MARK: - RetryEvent

/// リトライイベント
///
/// LLMリクエストのリトライが発生した際に通知されるイベント情報です。
/// `RetryEventHandler` を通じて受け取ることができます。
public struct RetryEvent: Sendable {
    /// リトライ試行回数（1から開始）
    public let attempt: Int

    /// 最大リトライ回数
    public let maxRetries: Int

    /// 発生したエラー
    public let error: LLMError

    /// 次のリトライまでの待機時間（秒）
    public let delaySeconds: TimeInterval

    /// リトライの理由を表す文字列
    public var reason: String {
        switch error {
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .serverError(let code, _):
            return "Server error (\(code))"
        case .timeout:
            return "Request timeout"
        case .networkError:
            return "Network error"
        default:
            return "Retryable error"
        }
    }

    /// 残りリトライ回数
    public var remainingRetries: Int {
        max(0, maxRetries - attempt)
    }
}

// MARK: - RetryEventHandler

/// リトライイベントハンドラー
///
/// LLMリクエストのリトライが発生した際に呼び出されるコールバック型です。
///
/// ## 使用例
///
/// ```swift
/// let handler: RetryEventHandler = { event in
///     print("🔄 Retry \(event.attempt)/\(event.maxRetries): \(event.reason)")
///     print("   Waiting \(String(format: "%.1f", event.delaySeconds))s...")
/// }
///
/// let client = AnthropicClient(
///     apiKey: "...",
///     retryEventHandler: handler
/// )
/// ```
public typealias RetryEventHandler = @Sendable (RetryEvent) -> Void

// MARK: - RetryConfiguration

/// リトライ設定
///
/// LLMクライアントのリトライ動作をカスタマイズするための設定です。
///
/// ## 使用例
///
/// ```swift
/// // デフォルト設定（リトライ有効）
/// let client = AnthropicClient(apiKey: "...")
///
/// // リトライ無効
/// let clientNoRetry = AnthropicClient(
///     apiKey: "...",
///     retryConfiguration: .disabled
/// )
///
/// // カスタム設定
/// let clientCustom = AnthropicClient(
///     apiKey: "...",
///     retryConfiguration: .custom(maxRetries: 10, baseDelay: 2.0)
/// )
/// ```
public struct RetryConfiguration: Sendable {
    /// リトライを有効にするかどうか
    public let isEnabled: Bool

    /// 最大リトライ回数
    public let maxRetries: Int

    /// 基本待機時間（秒）
    public let baseDelay: TimeInterval

    /// 最大待機時間（秒）
    public let maxDelay: TimeInterval

    // MARK: - Presets

    /// デフォルト設定（リトライ有効）
    ///
    /// - リトライ有効
    /// - 最大リトライ回数: 5回
    /// - 基本待機時間: 1秒
    /// - 最大待機時間: 60秒
    public static let `default` = RetryConfiguration(
        isEnabled: true,
        maxRetries: 5,
        baseDelay: 1.0,
        maxDelay: 60.0
    )

    /// リトライ無効
    public static let disabled = RetryConfiguration(
        isEnabled: false,
        maxRetries: 0,
        baseDelay: 0,
        maxDelay: 0
    )

    /// 積極的なリトライ設定（エージェント向け）
    ///
    /// - リトライ有効
    /// - 最大リトライ回数: 10回
    /// - 基本待機時間: 0.5秒
    /// - 最大待機時間: 120秒
    public static let aggressive = RetryConfiguration(
        isEnabled: true,
        maxRetries: 10,
        baseDelay: 0.5,
        maxDelay: 120.0
    )

    /// 控えめなリトライ設定
    ///
    /// - リトライ有効
    /// - 最大リトライ回数: 3回
    /// - 基本待機時間: 2秒
    /// - 最大待機時間: 30秒
    public static let conservative = RetryConfiguration(
        isEnabled: true,
        maxRetries: 3,
        baseDelay: 2.0,
        maxDelay: 30.0
    )

    // MARK: - Custom Configuration

    /// カスタム設定を作成
    ///
    /// - Parameters:
    ///   - maxRetries: 最大リトライ回数
    ///   - baseDelay: 基本待機時間（秒）
    ///   - maxDelay: 最大待機時間（秒）
    /// - Returns: カスタム設定
    public static func custom(
        maxRetries: Int,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 60.0
    ) -> RetryConfiguration {
        RetryConfiguration(
            isEnabled: maxRetries > 0,
            maxRetries: maxRetries,
            baseDelay: baseDelay,
            maxDelay: maxDelay
        )
    }

    // MARK: - Internal Conversion

    /// 内部リトライポリシーに変換
    internal var policy: any RetryPolicy {
        guard isEnabled else {
            return NoRetryPolicy.shared
        }

        return ExponentialBackoffPolicy(
            maxRetries: maxRetries,
            baseDelay: baseDelay,
            maxDelay: maxDelay
        )
    }
}
