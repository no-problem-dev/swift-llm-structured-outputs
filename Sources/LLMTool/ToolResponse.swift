import Foundation

// MARK: - ToolResponse

/// ツール呼び出しへの応答
///
/// ツール実行結果を LLM に返すためのコンテナです。
/// 対応する `ToolCall` の ID で紐付けられます。
///
/// ## 使用例
///
/// ```swift
/// // ツール実行後に応答を作成
/// let call: ToolCall = ...
/// let result = try await executeTool(call)
///
/// let response = ToolResponse(
///     callId: call.id,
///     name: call.name,
///     output: result,
///     isError: false
/// )
///
/// // エラーの場合
/// let errorResponse = ToolResponse(
///     callId: call.id,
///     name: call.name,
///     output: "API rate limit exceeded",
///     isError: true
/// )
/// ```
public struct ToolResponse: Sendable, Equatable {
    /// 対応する ToolCall の ID
    public let callId: String

    /// ツール名
    public let name: String

    /// 出力内容
    public let output: String

    /// エラーかどうか
    public let isError: Bool

    // MARK: - Initializer

    /// ToolResponse を初期化
    ///
    /// - Parameters:
    ///   - callId: 対応する ToolCall の ID
    ///   - name: ツール名
    ///   - output: 出力内容
    ///   - isError: エラーかどうか（デフォルト: false）
    public init(callId: String, name: String, output: String, isError: Bool = false) {
        self.callId = callId
        self.name = name
        self.output = output
        self.isError = isError
    }
}
