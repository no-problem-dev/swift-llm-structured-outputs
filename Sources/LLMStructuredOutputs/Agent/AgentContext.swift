import Foundation

// MARK: - AgentContext

/// エージェントループの内部状態を管理する Actor
///
/// メッセージ履歴、ステップ数、ツール情報などを安全に管理します。
public actor AgentContext {
    /// 現在のメッセージ履歴
    private var messages: [LLMMessage]

    /// システムプロンプト
    private let systemPrompt: Prompt?

    /// 使用可能なツール
    private let tools: ToolSet

    /// 設定
    private let configuration: AgentConfiguration

    /// 設定への同期アクセス（Actor 外から初期化時に使用）
    ///
    /// - Note: この値は初期化後に変更されないため、同期アクセスが安全
    internal nonisolated let configurationSync: AgentConfiguration

    /// 現在のステップ数
    private var currentStep: Int = 0

    /// ループが完了したか
    private var isCompleted: Bool = false

    /// 最後のレスポンス
    private var lastResponse: LLMResponse?

    // MARK: - Initialization

    /// AgentContext を初期化
    ///
    /// - Parameters:
    ///   - initialPrompt: 初期ユーザープロンプト
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - tools: 使用可能なツール
    ///   - configuration: エージェント設定
    public init(
        initialPrompt: String,
        systemPrompt: Prompt? = nil,
        tools: ToolSet,
        configuration: AgentConfiguration = .default
    ) {
        self.messages = [LLMMessage.user(initialPrompt)]
        self.systemPrompt = systemPrompt
        self.tools = tools
        self.configuration = configuration
        self.configurationSync = configuration
    }

    /// メッセージ履歴から AgentContext を初期化
    ///
    /// - Parameters:
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - tools: 使用可能なツール
    ///   - initialMessages: 初期メッセージ履歴
    ///   - configuration: エージェント設定
    public init(
        systemPrompt: Prompt? = nil,
        tools: ToolSet,
        initialMessages: [LLMMessage],
        configuration: AgentConfiguration = .default
    ) {
        self.messages = initialMessages
        self.systemPrompt = systemPrompt
        self.tools = tools
        self.configuration = configuration
        self.configurationSync = configuration
    }

    // MARK: - State Access

    /// 現在のメッセージ履歴を取得
    public func getMessages() -> [LLMMessage] {
        messages
    }

    /// システムプロンプトを取得
    public func getSystemPrompt() -> Prompt? {
        systemPrompt
    }

    /// ツールセットを取得
    public func getTools() -> ToolSet {
        tools
    }

    /// 現在のステップ数を取得
    public func getCurrentStep() -> Int {
        currentStep
    }

    /// ループが完了したかを取得
    public func getIsCompleted() -> Bool {
        isCompleted
    }

    /// 最後のレスポンスを取得
    public func getLastResponse() -> LLMResponse? {
        lastResponse
    }

    /// 設定を取得
    public func getConfiguration() -> AgentConfiguration {
        configuration
    }

    // MARK: - State Mutation

    /// ステップを進める
    ///
    /// - Throws: `AgentError.maxStepsExceeded` if step limit is reached
    public func incrementStep() throws {
        currentStep += 1
        if currentStep > configuration.maxSteps {
            throw AgentError.maxStepsExceeded(steps: configuration.maxSteps)
        }
    }

    /// アシスタントメッセージを追加（LLMからの応答）
    ///
    /// - Parameter response: LLM レスポンス
    public func addAssistantResponse(_ response: LLMResponse) {
        lastResponse = response

        // レスポンスをメッセージに変換して追加
        var contents: [LLMMessage.MessageContent] = []

        for block in response.content {
            switch block {
            case .text(let text):
                if !text.isEmpty {
                    contents.append(.text(text))
                }
            case .toolUse(let id, let name, let input):
                contents.append(.toolUse(id: id, name: name, input: input))
            }
        }

        if !contents.isEmpty {
            messages.append(LLMMessage(role: .assistant, contents: contents))
        }
    }

    /// ツール結果を追加
    ///
    /// - Parameter results: ツール実行結果の配列
    public func addToolResults(_ results: [ToolResultInfo]) {
        guard !results.isEmpty else { return }

        let contents = results.map { result in
            LLMMessage.MessageContent.toolResult(
                toolCallId: result.toolCallId,
                name: result.name,
                content: result.content,
                isError: result.isError
            )
        }
        messages.append(LLMMessage(role: .user, contents: contents))
    }

    /// ループを完了としてマーク
    public func markCompleted() {
        isCompleted = true
    }

    /// ループが継続可能かチェック
    ///
    /// - Returns: 継続可能なら true
    public func canContinue() -> Bool {
        !isCompleted && currentStep < configuration.maxSteps
    }

    // MARK: - Tool Helpers

    /// ツール名からツール型を検索
    ///
    /// - Parameter name: ツール名
    /// - Returns: 見つかったツール型、なければ nil
    public func findToolType(named name: String) -> (any LLMToolRegistrable.Type)? {
        tools.toolType(named: name)
    }

    /// ツールを実行
    ///
    /// - Parameters:
    ///   - name: ツール名
    ///   - input: ツール引数（JSON データ）
    /// - Returns: ツール実行結果
    /// - Throws: ツールが見つからない、または実行エラー
    public func executeTool(named name: String, with input: Data) async throws -> ToolResult {
        try await tools.execute(toolNamed: name, with: input)
    }

    /// レスポンスからツール呼び出し情報を抽出
    ///
    /// - Parameter response: LLM レスポンス
    /// - Returns: ツール呼び出し情報の配列
    public func extractToolCalls(from response: LLMResponse) -> [ToolCallInfo] {
        response.content.compactMap { block in
            guard case .toolUse(let id, let name, let input) = block else {
                return nil
            }
            return ToolCallInfo(id: id, name: name, input: input)
        }
    }

    /// レスポンスがツール呼び出しを含むかチェック
    ///
    /// - Parameter response: LLM レスポンス
    /// - Returns: ツール呼び出しを含むなら true
    public func hasToolCalls(in response: LLMResponse) -> Bool {
        response.stopReason == .toolUse ||
        response.content.contains { block in
            if case .toolUse = block { return true }
            return false
        }
    }

    /// レスポンスからテキストコンテンツを抽出
    ///
    /// - Parameter response: LLM レスポンス
    /// - Returns: 連結されたテキスト
    public func extractText(from response: LLMResponse) -> String {
        response.content.compactMap { block in
            if case .text(let text) = block { return text }
            return nil
        }.joined()
    }
}

