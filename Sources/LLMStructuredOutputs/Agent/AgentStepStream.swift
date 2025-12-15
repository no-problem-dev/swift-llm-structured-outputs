import Foundation

// MARK: - AgentStepStream

/// エージェントループのステップをストリームとして提供するプロトコル
///
/// LLM クライアントと連携してツール呼び出しを含むエージェントループを実行し、
/// 各ステップを `AsyncSequence` として返します。
///
/// ## 概要
///
/// このプロトコルは、エージェントループの実行結果を非同期シーケンスとして
/// 取得するための最小限のインターフェースを提供します。
/// 外部からは `for try await` でステップを受け取ることができます。
///
/// ## ステップの種類
///
/// シーケンスから返される `AgentStep<Output>` は以下の4種類です：
///
/// - `.thinking(LLMResponse)`: LLM がテキスト応答を生成中
/// - `.toolCall(ToolCallInfo)`: LLM がツール呼び出しを要求
/// - `.toolResult(ToolResultInfo)`: ツール実行結果
/// - `.finalResponse(Output)`: エージェントループ完了、構造化された最終出力
///
/// ## 使用例
///
/// ```swift
/// @Tool("天気を取得する")
/// struct GetWeather {
///     @ToolArgument("場所")
///     var location: String
///
///     func call() async throws -> String {
///         return "晴れ、25°C"
///     }
/// }
///
/// @Structured("天気レポート")
/// struct WeatherReport {
///     @StructuredField("場所")
///     var location: String
///     @StructuredField("天気")
///     var weather: String
/// }
///
/// let tools = ToolSet { GetWeather.self }
///
/// for try await step in client.runAgent(
///     prompt: "東京の天気を教えて",
///     model: .sonnet,
///     tools: tools
/// ) as some AgentStepStream<WeatherReport> {
///     switch step {
///     case .thinking(let response):
///         print("思考中: \(response.textContent ?? "")")
///     case .toolCall(let call):
///         print("ツール呼び出し: \(call.name)")
///     case .toolResult(let result):
///         print("ツール結果: \(result.content)")
///     case .finalResponse(let report):
///         print("最終出力: \(report.location) - \(report.weather)")
///     }
/// }
/// ```
///
/// ## スレッドセーフティ
///
/// このプロトコルは `Sendable` に準拠しており、複数のタスクから安全に参照できます。
/// ただし、イテレーション自体は単一のタスクから行う必要があります。
///
/// - Note: 内部実装の詳細（実行フェーズの監視やキャンセル機能など）は
///         このプロトコルでは公開されません。
public protocol AgentStepStream<Output>: AsyncSequence, Sendable
    where Element == AgentStep<Output>
{
    /// 構造化出力の型
    associatedtype Output: StructuredProtocol
}
