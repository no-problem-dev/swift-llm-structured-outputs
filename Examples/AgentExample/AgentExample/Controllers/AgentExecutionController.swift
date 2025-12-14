//
//  AgentExecutionController.swift
//  AgentExample
//
//  エージェント実行制御
//

import Foundation
import LLMStructuredOutputs

/// エージェント実行制御
///
/// エージェントの実行ライフサイクル（開始、キャンセル、完了）を管理します。
/// ViewからUIロジックを分離し、単一責任の原則に従います。
@Observable @MainActor
final class AgentExecutionController {

    // MARK: - Dependencies

    private let settings: AgentSettings
    private let toolConfig: ToolConfiguration

    // MARK: - State

    /// 実行状態
    private(set) var state: AgentExecutionState = .idle

    /// 実行中のステップ履歴
    private(set) var steps: [AgentStepInfo] = []

    /// 実行中かどうか
    var isRunning: Bool {
        runningTask != nil
    }

    /// 実行中のタスク
    private var runningTask: Task<Void, Never>?

    // MARK: - Initialization

    init(settings: AgentSettings = .shared, toolConfig: ToolConfiguration = .shared) {
        self.settings = settings
        self.toolConfig = toolConfig
    }

    // MARK: - Public Methods

    /// エージェントを実行開始
    func start(prompt: String) {
        // 既に実行中なら何もしない
        guard runningTask == nil else { return }

        // 状態をリセット
        state = .loading
        steps = []

        // ツールセットを構築
        let tools = ResearchToolSet.configuredTools

        // 実行タスクを開始
        runningTask = Task {
            await executeAgent(prompt: prompt, tools: tools)
        }
    }

    /// エージェントをキャンセル
    func cancel() {
        runningTask?.cancel()
        runningTask = nil

        // キャンセル状態を設定
        if state.isLoading {
            state = .cancelled
            steps.append(AgentStepInfo(
                type: .thinking,
                content: "ユーザーによりキャンセルされました",
                isError: true
            ))
        }
    }

    /// 状態をリセット
    func reset() {
        cancel()
        state = .idle
        steps = []
    }

    /// 実行可能かどうか
    func canExecute(prompt: String) -> Bool {
        !prompt.isEmpty &&
        settings.isCurrentProviderAvailable &&
        !isRunning &&
        toolConfig.hasUsableTools
    }

    // MARK: - Private Methods

    private func executeAgent(prompt: String, tools: ToolSet) async {
        do {
            switch settings.selectedProvider {
            case .anthropic:
                guard let client = settings.createAnthropicClient() else {
                    state = .error("Anthropic クライアントの作成に失敗しました")
                    runningTask = nil
                    return
                }
                try await runAnthropicAgent(client: client, prompt: prompt, tools: tools)

            case .openai:
                guard let client = settings.createOpenAIClient() else {
                    state = .error("OpenAI クライアントの作成に失敗しました")
                    runningTask = nil
                    return
                }
                try await runOpenAIAgent(client: client, prompt: prompt, tools: tools)

            case .gemini:
                guard let client = settings.createGeminiClient() else {
                    state = .error("Gemini クライアントの作成に失敗しました")
                    runningTask = nil
                    return
                }
                try await runGeminiAgent(client: client, prompt: prompt, tools: tools)
            }
        } catch is CancellationError {
            // キャンセルは正常終了として扱う
            if state.isLoading {
                state = .cancelled
            }
        } catch {
            state = .error(error.localizedDescription)
        }

        runningTask = nil
    }

    private func runAnthropicAgent(client: AnthropicClient, prompt: String, tools: ToolSet) async throws {
        let systemPrompt = ResearchAgentPrompt.build()
        let config = settings.createAgentConfiguration()

        let agentSequence: AgentStepSequence<AnthropicClient, ResearchReport> = client.runAgent(
            prompt: prompt,
            model: settings.claudeModelOption.model,
            tools: tools,
            systemPrompt: systemPrompt,
            configuration: config
        )

        var finalResult: ResearchReport?

        for try await step in agentSequence {
            try Task.checkCancellation()

            let stepInfo = processStep(step)
            steps.append(stepInfo)

            if case .finalResponse(let report) = step {
                finalResult = report
            }
        }

        if let result = finalResult {
            state = .success(result)
        } else if !Task.isCancelled {
            state = .error("最終レスポンスが取得できませんでした")
        }
    }

    private func runOpenAIAgent(client: OpenAIClient, prompt: String, tools: ToolSet) async throws {
        let systemPrompt = ResearchAgentPrompt.build()
        let config = settings.createAgentConfiguration()

        let agentSequence: AgentStepSequence<OpenAIClient, ResearchReport> = client.runAgent(
            prompt: prompt,
            model: settings.gptModelOption.model,
            tools: tools,
            systemPrompt: systemPrompt,
            configuration: config
        )

        var finalResult: ResearchReport?

        for try await step in agentSequence {
            try Task.checkCancellation()

            let stepInfo = processStep(step)
            steps.append(stepInfo)

            if case .finalResponse(let report) = step {
                finalResult = report
            }
        }

        if let result = finalResult {
            state = .success(result)
        } else if !Task.isCancelled {
            state = .error("最終レスポンスが取得できませんでした")
        }
    }

    private func runGeminiAgent(client: GeminiClient, prompt: String, tools: ToolSet) async throws {
        let systemPrompt = ResearchAgentPrompt.build()
        let config = settings.createAgentConfiguration()

        let agentSequence: AgentStepSequence<GeminiClient, ResearchReport> = client.runAgent(
            prompt: prompt,
            model: settings.geminiModelOption.model,
            tools: tools,
            systemPrompt: systemPrompt,
            configuration: config
        )

        var finalResult: ResearchReport?

        for try await step in agentSequence {
            try Task.checkCancellation()

            let stepInfo = processStep(step)
            steps.append(stepInfo)

            if case .finalResponse(let report) = step {
                finalResult = report
            }
        }

        if let result = finalResult {
            state = .success(result)
        } else if !Task.isCancelled {
            state = .error("最終レスポンスが取得できませんでした")
        }
    }

    private func processStep(_ step: AgentStep<ResearchReport>) -> AgentStepInfo {
        switch step {
        case .thinking(let response):
            let text = response.content.compactMap { $0.text }.joined()
            return AgentStepInfo(
                type: .thinking,
                content: text.isEmpty ? "（考え中...）" : text
            )

        case .toolCall(let info):
            return AgentStepInfo(
                type: .toolCall,
                content: info.name,
                detail: formatToolInput(info.input)
            )

        case .toolResult(let info):
            return AgentStepInfo(
                type: .toolResult,
                content: info.content,
                isError: info.isError
            )

        case .finalResponse(let report):
            return AgentStepInfo(
                type: .finalResponse,
                content: report.title
            )
        }
    }

    private func formatToolInput(_ data: Data) -> String? {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }
}

// MARK: - AgentExecutionState Extension

extension AgentExecutionState {
    /// キャンセルされたかどうか
    static var cancelled: AgentExecutionState {
        .error("キャンセルされました")
    }

    var isCancelled: Bool {
        if case .error(let message) = self {
            return message == "キャンセルされました"
        }
        return false
    }
}
