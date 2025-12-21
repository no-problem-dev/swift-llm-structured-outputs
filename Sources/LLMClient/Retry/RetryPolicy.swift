import Foundation

// MARK: - RetryPolicy Protocol

/// リトライポリシープロトコル
///
/// LLMプロバイダーへのリクエストが失敗した際のリトライ戦略を定義します。
package protocol RetryPolicy: Sendable {
    /// 最大リトライ回数
    ///
    /// 初回リクエストを含まない、追加のリトライ回数を指定します。
    /// 例: `maxRetries = 3` の場合、最大4回のリクエスト（初回 + 3回リトライ）が行われます。
    var maxRetries: Int { get }

    /// エラーがリトライ可能かどうかを判定
    ///
    /// - Parameters:
    ///   - error: 発生したエラー
    ///   - attempt: 現在の試行回数（1から開始）
    /// - Returns: リトライすべき場合は `true`
    func shouldRetry(error: LLMError, attempt: Int) -> Bool

    /// 次のリトライまでの待機時間を計算
    ///
    /// - Parameters:
    ///   - attempt: 現在の試行回数（1から開始）
    ///   - error: 発生したエラー
    ///   - rateLimitInfo: レート制限情報（利用可能な場合）
    /// - Returns: 待機時間（秒）
    func delay(for attempt: Int, error: LLMError, rateLimitInfo: RateLimitInfo?) -> TimeInterval
}

// MARK: - ExponentialBackoffPolicy

/// 指数バックオフ + ジッター リトライポリシー
///
/// レート制限やサーバーエラーに対して、指数関数的に増加する待機時間でリトライを行います。
/// ジッター（ランダムな揺らぎ）を追加することで、同時リトライによるサーバー負荷集中を防ぎます。
///
/// ## 待機時間の計算
///
/// 基本的な待機時間は以下の式で計算されます：
/// ```
/// delay = min(baseDelay * 2^(attempt-1), maxDelay)
/// ```
///
/// これにジッターが追加されます：
/// ```
/// finalDelay = delay + (delay * jitterFactor * random(0...1))
/// ```
///
/// ## リトライ可能なエラー
///
/// - `rateLimitExceeded` (429): レート制限超過
/// - `serverError` (500-599): サーバーエラー
/// - `timeout`: タイムアウト
/// - `networkError`: 一時的なネットワークエラー
package struct ExponentialBackoffPolicy: RetryPolicy {
    /// 最大リトライ回数
    package let maxRetries: Int

    /// 基本待機時間（秒）
    package let baseDelay: TimeInterval

    /// 最大待機時間（秒）
    package let maxDelay: TimeInterval

    /// ジッター係数（0.0-1.0）
    ///
    /// 待機時間に追加されるランダムな揺らぎの最大割合。
    /// 例: `0.1` の場合、待機時間の最大10%がランダムに追加されます。
    package let jitterFactor: Double

    /// デフォルトのリトライポリシー
    ///
    /// - 最大リトライ回数: 5回
    /// - 基本待機時間: 1秒
    /// - 最大待機時間: 60秒
    /// - ジッター係数: 0.1（10%）
    static let `default` = ExponentialBackoffPolicy()

    /// 積極的なリトライポリシー（エージェント向け）
    ///
    /// - 最大リトライ回数: 10回
    /// - 基本待機時間: 0.5秒
    /// - 最大待機時間: 120秒
    /// - ジッター係数: 0.2（20%）
    static let aggressive = ExponentialBackoffPolicy(
        maxRetries: 10,
        baseDelay: 0.5,
        maxDelay: 120.0,
        jitterFactor: 0.2
    )

    /// 控えめなリトライポリシー
    ///
    /// - 最大リトライ回数: 3回
    /// - 基本待機時間: 2秒
    /// - 最大待機時間: 30秒
    /// - ジッター係数: 0.1（10%）
    static let conservative = ExponentialBackoffPolicy(
        maxRetries: 3,
        baseDelay: 2.0,
        maxDelay: 30.0,
        jitterFactor: 0.1
    )

    init(
        maxRetries: Int = 5,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 60.0,
        jitterFactor: Double = 0.1
    ) {
        self.maxRetries = max(0, maxRetries)
        self.baseDelay = max(0, baseDelay)
        self.maxDelay = max(baseDelay, maxDelay)
        self.jitterFactor = min(1.0, max(0, jitterFactor))
    }

    package func shouldRetry(error: LLMError, attempt: Int) -> Bool {
        // 最大リトライ回数を超えていないか確認
        guard attempt <= maxRetries else { return false }

        // エラーの種類に基づいてリトライ可否を判定
        return error.isRetryable
    }

    package func delay(for attempt: Int, error: LLMError, rateLimitInfo: RateLimitInfo?) -> TimeInterval {
        // retry-after ヘッダーがあれば優先
        if let suggestedWait = rateLimitInfo?.suggestedWaitTime, suggestedWait > 0 {
            // ジッターを追加して返す
            return addJitter(to: suggestedWait)
        }

        // 指数バックオフ: baseDelay * 2^(attempt-1)
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt - 1))
        let cappedDelay = min(exponentialDelay, maxDelay)

        return addJitter(to: cappedDelay)
    }

    /// 待機時間にジッターを追加
    private func addJitter(to delay: TimeInterval) -> TimeInterval {
        let jitter = delay * jitterFactor * Double.random(in: 0...1)
        return delay + jitter
    }
}

// MARK: - NoRetryPolicy

/// リトライしないポリシー
///
/// リトライを行わず、エラーを即座にスローします。
package struct NoRetryPolicy: RetryPolicy {
    package let maxRetries: Int = 0

    package static let shared = NoRetryPolicy()

    private init() {}

    package func shouldRetry(error: LLMError, attempt: Int) -> Bool {
        return false
    }

    package func delay(for attempt: Int, error: LLMError, rateLimitInfo: RateLimitInfo?) -> TimeInterval {
        return 0
    }
}

// MARK: - LLMError Extension

extension LLMError {
    /// リトライ可能なエラーかどうか
    ///
    /// 以下のエラーはリトライ可能と判定されます：
    /// - `rateLimitExceeded`: レート制限超過（429）
    /// - `serverError`: サーバーエラー（500-599）
    /// - `timeout`: タイムアウト
    /// - `networkError`: ネットワークエラー（一時的な障害の可能性）
    ///
    /// 以下のエラーはリトライ不可と判定されます：
    /// - `unauthorized`: 認証エラー（APIキーの問題）
    /// - `invalidRequest`: 不正なリクエスト（修正が必要）
    /// - `modelNotFound`: モデルが存在しない
    /// - `decodingFailed`: レスポンスのデコード失敗
    /// - `contentBlocked`: コンテンツが安全性フィルターにブロックされた
    package var isRetryable: Bool {
        switch self {
        case .rateLimitExceeded:
            return true
        case .serverError(let code, _):
            return (500...599).contains(code)
        case .timeout:
            return true
        case .networkError:
            return true
        case .unauthorized, .invalidRequest, .modelNotFound,
             .emptyResponse, .invalidEncoding, .decodingFailed,
             .modelNotSupported, .structuredOutputNotSupported,
             .contentBlocked, .maxTokensReached, .mediaNotSupported,
             .unknown:
            return false
        }
    }
}
