import Foundation

// MARK: - GenerationResult

/// 構造化出力の生成結果（メタデータ付き）
///
/// LLM から返された構造化出力と、トークン使用量などのメタデータを含みます。
/// コスト計算や使用量トラッキングに使用できます。
///
/// ## 使用例
///
/// ```swift
/// let client = GeminiClient(apiKey: "...")
///
/// @Structured("ユーザー情報")
/// struct UserInfo {
///     @StructuredField("ユーザー名") var name: String
///     @StructuredField("年齢") var age: Int
/// }
///
/// let result: GenerationResult<UserInfo> = try await client.generateWithUsage(
///     input: "山田太郎さんは35歳です。",
///     model: .flash3
/// )
///
/// print(result.result.name)           // "山田太郎"
/// print(result.usage.inputTokens)     // 入力トークン数
/// print(result.usage.outputTokens)    // 出力トークン数
/// print(result.usage.totalTokens)     // 合計トークン数
/// ```
public struct GenerationResult<T: StructuredProtocol>: Sendable {
    /// デコード済み構造化出力
    ///
    /// リクエストで指定した `StructuredProtocol` 準拠の型にデコードされた結果。
    public let result: T

    /// トークン使用量
    ///
    /// このリクエストで消費された入力/出力トークン数。
    /// コスト計算に使用できます。
    public let usage: TokenUsage

    /// 使用されたモデルID
    ///
    /// 実際に使用されたモデルの識別子。
    public let model: String

    /// 生のJSONテキスト
    ///
    /// モデルから返された構造化出力の生のJSON文字列。
    /// デバッグやログ記録に使用できます。
    public let rawText: String

    /// 停止理由
    ///
    /// モデルが生成を停止した理由。
    /// 通常は `.endTurn`（正常終了）または `.maxTokens`（トークン上限到達）。
    public let stopReason: LLMResponse.StopReason?

    // MARK: - Initializer

    /// GenerationResult を初期化
    ///
    /// - Parameters:
    ///   - result: デコード済み構造化出力
    ///   - usage: トークン使用量
    ///   - model: 使用されたモデルID
    ///   - rawText: 生のJSONテキスト
    ///   - stopReason: 停止理由
    public init(
        result: T,
        usage: TokenUsage,
        model: String,
        rawText: String,
        stopReason: LLMResponse.StopReason?
    ) {
        self.result = result
        self.usage = usage
        self.model = model
        self.rawText = rawText
        self.stopReason = stopReason
    }
}

// MARK: - Convenience Extensions

extension GenerationResult {
    /// 結果を別の型にマップ
    ///
    /// - Parameter transform: 変換関数
    /// - Returns: 変換後の GenerationResult
    public func map<U: StructuredProtocol>(_ transform: (T) throws -> U) rethrows -> GenerationResult<U> {
        GenerationResult<U>(
            result: try transform(result),
            usage: usage,
            model: model,
            rawText: rawText,
            stopReason: stopReason
        )
    }
}

// MARK: - CustomDebugStringConvertible

extension GenerationResult: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        GenerationResult(
            model: \(model),
            usage: TokenUsage(input: \(usage.inputTokens), output: \(usage.outputTokens), total: \(usage.totalTokens)),
            stopReason: \(stopReason.map { String(describing: $0) } ?? "nil"),
            rawText: \(rawText.prefix(100))\(rawText.count > 100 ? "..." : "")
        )
        """
    }
}
