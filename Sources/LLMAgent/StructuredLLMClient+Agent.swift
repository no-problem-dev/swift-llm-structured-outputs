import Foundation
import LLMClient
import LLMTool

// MARK: - AgentCapableClient Protocol

/// エージェントループをサポートするクライアントのプロトコル
///
/// `ToolCallableClient` を拡張し、エージェントループの実装に必要な
/// メソッドを提供します。各プロバイダーはこのプロトコルに適合することで
/// エージェント機能を利用可能にします。
public protocol AgentCapableClient: ToolCallableClient {
    /// エージェントステップを実行
    ///
    /// メッセージ履歴、ツール、オプションの構造化出力スキーマを含むリクエストを送信します。
    ///
    /// - Parameters:
    ///   - messages: メッセージ履歴
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト
    ///   - tools: 使用可能なツール
    ///   - toolChoice: ツール選択設定
    ///   - responseSchema: 期待する出力スキーマ（最終出力用）
    /// - Returns: LLM レスポンス
    func executeAgentStep(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: Prompt?,
        tools: ToolSet,
        toolChoice: ToolChoice?,
        responseSchema: JSONSchema?
    ) async throws -> LLMResponse
}

// MARK: - StructuredLLMClient + Agent

extension AgentCapableClient {
    /// エージェントループを実行し、各ステップを AsyncSequence として返す
    ///
    /// LLM がツールを選択・実行し、最終的な構造化出力を生成するまでループします。
    /// 各ステップ（思考、ツール呼び出し、ツール結果、最終出力）が順次返されます。
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
    /// let tools = ToolSet {
    ///     GetWeather()
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
    /// let stream: some AgentStepStream<WeatherReport> = client.runAgent(
    ///     input: "東京の天気を教えて",
    ///     model: .sonnet,
    ///     tools: tools
    /// )
    ///
    /// for try await step in stream {
    ///     switch step {
    ///     case .thinking(let response):
    ///         print("思考: \(response.textContent ?? "")")
    ///     case .toolCall(let info):
    ///         print("ツール呼び出し: \(info.name)")
    ///     case .toolResult(let info):
    ///         print("結果: \(info.content)")
    ///     case .finalResponse(let report):
    ///         print("最終出力: \(report.location) - \(report.weather)")
    ///     }
    /// }
    ///
    /// // マルチモーダル入力
    /// let stream = client.runAgent(
    ///     input: LLMInput("この画像を分析してください", images: [imageContent]),
    ///     model: .sonnet,
    ///     tools: imageAnalysisTools
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - input: LLM 入力（テキスト、画像、音声、動画を含む）
    ///   - model: 使用するモデル
    ///   - tools: 使用可能なツールセット
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - configuration: エージェント設定（オプション、デフォルト: 最大10ステップ）
    /// - Returns: 各ステップを返す AsyncSequence
    public func runAgent<Output: StructuredProtocol>(
        input: LLMInput,
        model: Model,
        tools: ToolSet,
        systemPrompt: Prompt? = nil,
        configuration: AgentConfiguration = .default
    ) -> some AgentStepStream<Output> {
        runAgent(
            messages: [input.toLLMMessage()],
            model: model,
            tools: tools,
            systemPrompt: systemPrompt,
            configuration: configuration
        )
    }

    /// 会話履歴を含むエージェントループを実行
    ///
    /// - Parameters:
    ///   - messages: メッセージ履歴
    ///   - model: 使用するモデル
    ///   - tools: 使用可能なツールセット
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - configuration: エージェント設定（オプション）
    /// - Returns: 各ステップを返す AsyncSequence
    public func runAgent<Output: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        tools: ToolSet,
        systemPrompt: Prompt? = nil,
        configuration: AgentConfiguration = .default
    ) -> some AgentStepStream<Output> {
        let context = AgentContext(
            systemPrompt: systemPrompt,
            tools: tools,
            initialMessages: messages,
            configuration: configuration
        )

        return AgentStepSequence<Self, Output>(
            client: self,
            model: model,
            context: context,
            configuration: configuration
        )
    }
}
