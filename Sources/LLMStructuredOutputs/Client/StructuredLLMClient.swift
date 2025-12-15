import Foundation

// MARK: - StructuredLLMClient Protocol

/// 構造化出力をサポートする LLM クライアントの共通インターフェース
///
/// このプロトコルは、モデル型をジェネリクスで制約することで、
/// 各プロバイダーに対して適切なモデルのみを使用できることを
/// コンパイル時に保証します。
///
/// ## 使用例
///
/// ```swift
/// // Anthropic クライアント
/// let anthropic = AnthropicClient(apiKey: "sk-ant-...")
/// let result: UserInfo = try await anthropic.generate(
///     prompt: "山田太郎さんは35歳です。",
///     model: .sonnet  // ClaudeModel のみ許可
/// )
///
/// // OpenAI クライアント
/// let openai = OpenAIClient(apiKey: "sk-...")
/// let result: UserInfo = try await openai.generate(
///     prompt: "山田太郎さんは35歳です。",
///     model: .gpt4o  // GPTModel のみ許可
/// )
/// ```
public protocol StructuredLLMClient<Model>: Sendable {
    /// このクライアントで使用可能なモデル型
    associatedtype Model: Sendable

    /// 構造化出力を生成
    ///
    /// 指定された型に準拠した構造化データを LLM から取得します。
    /// 戻り値の型から自動的にスキーマが推論されます。
    ///
    /// - Parameters:
    ///   - prompt: ユーザープロンプト
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（0.0-1.0、オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 指定された型にデコードされたレスポンス
    /// - Throws: `LLMError` - API エラー、デコードエラーなど
    func generate<T: StructuredProtocol>(
        prompt: String,
        model: Model,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> T

    /// 会話履歴を含む構造化出力を生成
    ///
    /// - Parameters:
    ///   - messages: メッセージ履歴
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 指定された型にデコードされたレスポンス
    func generate<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> T

    // MARK: - Chat Methods (会話継続用)

    /// 会話を継続し、構造化出力と会話履歴情報を取得
    ///
    /// このメソッドは `generate` と異なり、構造化出力に加えて
    /// 会話を継続するために必要なメタ情報を `ChatResponse` として返します。
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// var history: [LLMMessage] = []
    /// history.append(.user("日本の首都は？"))
    ///
    /// let response: ChatResponse<CityInfo> = try await client.chat(
    ///     messages: history,
    ///     model: .sonnet
    /// )
    ///
    /// // 履歴に追加して会話を継続
    /// history.append(response.assistantMessage)
    /// history.append(.user("その都市の人口は？"))
    /// ```
    ///
    /// - Parameters:
    ///   - messages: メッセージ履歴
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 構造化出力と会話継続情報を含む `ChatResponse`
    func chat<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> ChatResponse<T>
}

// MARK: - Default Implementations

extension StructuredLLMClient {
    /// 構造化出力を生成（デフォルト引数付き）
    ///
    /// - Parameters:
    ///   - prompt: ユーザープロンプト
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト（オプション、デフォルト: nil）
    ///   - temperature: 温度パラメータ（オプション、デフォルト: nil）
    ///   - maxTokens: 最大トークン数（オプション、デフォルト: nil）
    /// - Returns: 指定された型にデコードされたレスポンス
    public func generate<T: StructuredProtocol>(
        prompt: String,
        model: Model,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> T {
        try await generate(
            prompt: prompt,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    /// 会話履歴を含む構造化出力を生成（デフォルト引数付き）
    public func generate<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> T {
        try await generate(
            messages: messages,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    // MARK: - Chat Default Implementations

    /// 会話を継続（デフォルト引数付き）
    public func chat<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> ChatResponse<T> {
        try await chat(
            messages: messages,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    /// 単一プロンプトから会話を開始
    ///
    /// 会話履歴なしで新しい会話を開始するための便利メソッド。
    ///
    /// - Parameters:
    ///   - prompt: ユーザープロンプト
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 構造化出力と会話継続情報を含む `ChatResponse`
    public func chat<T: StructuredProtocol>(
        prompt: String,
        model: Model,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> ChatResponse<T> {
        try await chat(
            messages: [.user(prompt)],
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }
}

// MARK: - AgentCapable Protocol

/// エージェントループをサポートするクライアントのプロトコル
///
/// このプロトコルは内部使用を想定しており、エージェントループの実装に必要な
/// 低レベルのメソッドを提供します。
public protocol AgentCapableClient: StructuredLLMClient {
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

// MARK: - AgentCapableClient Default Implementations

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
    ///     GetWeather.self
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
    ///     prompt: "東京の天気を教えて",
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
    /// ```
    ///
    /// - Parameters:
    ///   - prompt: ユーザープロンプト
    ///   - model: 使用するモデル
    ///   - tools: 使用可能なツールセット
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - configuration: エージェント設定（オプション、デフォルト: 最大10ステップ）
    /// - Returns: 各ステップを返す AsyncSequence
    public func runAgent<Output: StructuredProtocol>(
        prompt: String,
        model: Model,
        tools: ToolSet,
        systemPrompt: Prompt? = nil,
        configuration: AgentConfiguration = .default
    ) -> some AgentStepStream<Output> {
        runAgent(
            messages: [.user(prompt)],
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
            context: context
        )
    }
}
