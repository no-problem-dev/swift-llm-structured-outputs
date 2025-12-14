//
//  AgentExecutionController.swift
//  AgentExample
//
//  エージェント実行制御
//

import Foundation
import LLMStructuredOutputs

/// エージェント実行制御
@Observable @MainActor
final class AgentExecutionController {

    // MARK: - Dependencies

    private let settings: AgentSettings
    private let toolConfig: ToolConfiguration

    // MARK: - State

    private(set) var state: AgentExecutionState = .idle
    private(set) var steps: [AgentStepInfo] = []

    var isRunning: Bool {
        runningTask != nil
    }

    private var runningTask: Task<Void, Never>?

    // MARK: - Initialization

    init(settings: AgentSettings = .shared, toolConfig: ToolConfiguration = .shared) {
        self.settings = settings
        self.toolConfig = toolConfig
    }

    // MARK: - Public Methods

    /// エージェントを実行開始
    func start(prompt: String, category: ScenarioCategory) {
        guard runningTask == nil else { return }

        state = .loading
        steps = []

        let tools = ResearchToolSet.configuredTools

        runningTask = Task {
            await executeAgent(prompt: prompt, category: category, tools: tools)
        }
    }

    /// エージェントをキャンセル
    func cancel() {
        runningTask?.cancel()
        runningTask = nil

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

    private func executeAgent(prompt: String, category: ScenarioCategory, tools: ToolSet) async {
        do {
            switch settings.selectedProvider {
            case .anthropic:
                guard let client = settings.createAnthropicClient() else {
                    state = .error("Anthropic クライアントの作成に失敗しました")
                    runningTask = nil
                    return
                }
                try await runAgent(client: client, model: settings.claudeModelOption.model, prompt: prompt, category: category, tools: tools)

            case .openai:
                guard let client = settings.createOpenAIClient() else {
                    state = .error("OpenAI クライアントの作成に失敗しました")
                    runningTask = nil
                    return
                }
                try await runAgent(client: client, model: settings.gptModelOption.model, prompt: prompt, category: category, tools: tools)

            case .gemini:
                guard let client = settings.createGeminiClient() else {
                    state = .error("Gemini クライアントの作成に失敗しました")
                    runningTask = nil
                    return
                }
                try await runAgent(client: client, model: settings.geminiModelOption.model, prompt: prompt, category: category, tools: tools)
            }
        } catch is CancellationError {
            if state.isLoading {
                state = .cancelled
            }
        } catch {
            state = .error(error.localizedDescription)
        }

        runningTask = nil
    }

    private func runAgent<Client: AgentCapableClient>(
        client: Client,
        model: Client.Model,
        prompt: String,
        category: ScenarioCategory,
        tools: ToolSet
    ) async throws where Client.Model: Sendable {
        let config = settings.createAgentConfiguration()

        switch category {
        case .research:
            let systemPrompt = AgentPrompt.forResearch()
            try await runTypedAgent(
                client: client,
                model: model,
                prompt: prompt,
                tools: tools,
                systemPrompt: systemPrompt,
                config: config
            ) { (report: ResearchReport) in
                .research(report)
            }

        case .calculation:
            let systemPrompt = AgentPrompt.forCalculation()
            try await runTypedAgent(
                client: client,
                model: model,
                prompt: prompt,
                tools: tools,
                systemPrompt: systemPrompt,
                config: config
            ) { (report: CalculationReport) in
                .calculation(report)
            }

        case .temporal:
            let systemPrompt = AgentPrompt.forTemporal()
            try await runTypedAgent(
                client: client,
                model: model,
                prompt: prompt,
                tools: tools,
                systemPrompt: systemPrompt,
                config: config
            ) { (report: TemporalReport) in
                .temporal(report)
            }

        case .multiTool:
            let systemPrompt = AgentPrompt.forMultiTool()
            try await runTypedAgent(
                client: client,
                model: model,
                prompt: prompt,
                tools: tools,
                systemPrompt: systemPrompt,
                config: config
            ) { (report: MultiToolReport) in
                .multiTool(report)
            }

        case .reasoning:
            let systemPrompt = AgentPrompt.forReasoning()
            try await runTypedAgent(
                client: client,
                model: model,
                prompt: prompt,
                tools: tools,
                systemPrompt: systemPrompt,
                config: config
            ) { (report: ReasoningReport) in
                .reasoning(report)
            }
        }
    }

    private func runTypedAgent<Client: AgentCapableClient, Output: StructuredProtocol>(
        client: Client,
        model: Client.Model,
        prompt: String,
        tools: ToolSet,
        systemPrompt: Prompt,
        config: AgentConfiguration,
        transform: @escaping (Output) -> AgentResult
    ) async throws where Client.Model: Sendable {
        let agentSequence: AgentStepSequence<Client, Output> = client.runAgent(
            prompt: prompt,
            model: model,
            tools: tools,
            systemPrompt: systemPrompt,
            configuration: config
        )

        var finalResult: Output?

        for try await step in agentSequence {
            try Task.checkCancellation()

            let stepInfo = processStep(step)
            steps.append(stepInfo)

            if case .finalResponse(let report) = step {
                finalResult = report
            }
        }

        if let result = finalResult {
            state = .success(transform(result))
        } else if !Task.isCancelled {
            state = .error("最終レスポンスが取得できませんでした")
        }
    }

    private func processStep<Output>(_ step: AgentStep<Output>) -> AgentStepInfo {
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

        case .finalResponse:
            return AgentStepInfo(
                type: .finalResponse,
                content: "レポート生成完了"
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
