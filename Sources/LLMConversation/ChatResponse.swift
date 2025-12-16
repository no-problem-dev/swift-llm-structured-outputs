import Foundation
import LLMClient

// MARK: - ChatResponse

/// 会話レスポンス（構造化出力 + 会話継続に必要な情報）
///
/// このレスポンス型は、構造化出力のデコード結果に加えて、
/// 会話を継続するために必要なメタ情報を提供します。
///
/// ## 使用例
///
/// ```swift
/// let client = AnthropicClient(apiKey: "...")
/// var history: [LLMMessage] = []
///
/// // 最初の質問
/// history.append(.user("日本の首都はどこですか？"))
/// let response1: ChatResponse<CityInfo> = try await client.chat(
///     messages: history,
///     model: .sonnet
/// )
/// print(response1.result.name)  // "東京"
///
/// // アシスタント応答を履歴に追加
/// history.append(response1.assistantMessage)
///
/// // 続けて質問
/// history.append(.user("その都市の人口は？"))
/// let response2: ChatResponse<PopulationInfo> = try await client.chat(
///     messages: history,
///     model: .sonnet
/// )
/// print(response2.result.population)  // 13960000
/// ```
public struct ChatResponse<T: StructuredProtocol>: Sendable {
    /// デコード済み構造化出力
    ///
    /// リクエストで指定した `StructuredProtocol` 準拠の型にデコードされた結果。
    public let result: T

    /// アシスタントの応答メッセージ
    ///
    /// 会話履歴に追加するためのメッセージ。
    /// `messages` 配列に直接追加して次のリクエストで使用できます。
    public let assistantMessage: LLMMessage

    /// トークン使用量
    ///
    /// このリクエストで消費された入力/出力トークン数。
    /// 複数ターンの会話全体でのコスト管理に使用できます。
    public let usage: TokenUsage

    /// 停止理由
    ///
    /// モデルが生成を停止した理由。
    /// 通常は `.endTurn`（正常終了）または `.maxTokens`（トークン上限到達）。
    public let stopReason: LLMResponse.StopReason?

    /// 使用されたモデルID
    ///
    /// 実際に使用されたモデルの識別子。
    public let model: String

    /// 生のJSONテキスト
    ///
    /// モデルから返された構造化出力の生のJSON文字列。
    /// デバッグやログ記録に使用できます。
    public let rawText: String

    // MARK: - Initializer

    /// ChatResponse を初期化
    ///
    /// - Parameters:
    ///   - result: デコード済み構造化出力
    ///   - assistantMessage: アシスタントの応答メッセージ
    ///   - usage: トークン使用量
    ///   - stopReason: 停止理由
    ///   - model: 使用されたモデルID
    ///   - rawText: 生のJSONテキスト
    public init(
        result: T,
        assistantMessage: LLMMessage,
        usage: TokenUsage,
        stopReason: LLMResponse.StopReason?,
        model: String,
        rawText: String
    ) {
        self.result = result
        self.assistantMessage = assistantMessage
        self.usage = usage
        self.stopReason = stopReason
        self.model = model
        self.rawText = rawText
    }
}
