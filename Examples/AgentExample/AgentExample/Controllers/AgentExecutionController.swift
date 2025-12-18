//
//  AgentExecutionController.swift
//  AgentExample
//
//  エージェント実行制御
//  AgentScenarioType プロトコルによるジェネリック実行
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

    /// シナリオを指定してエージェントを実行開始（ジェネリック版）
    ///
    /// - Parameters:
    ///   - scenario: 実行するシナリオの型
    ///   - prompt: ユーザーのプロンプト
    ///   - transform: 出力を AgentResult に変換するクロージャ
    func start<S: AgentScenarioType>(
        scenario: S.Type,
        prompt: String,
        transform: @escaping (S.Output) -> AgentResult
    ) {
        guard runningTask == nil else { return }

        state = .loading
        steps = []

        let tools = ResearchToolSet.configuredTools

        runningTask = Task {
            await executeScenario(scenario: scenario, prompt: prompt, tools: tools, transform: transform)
        }
    }

    /// シナリオIDを指定してエージェントを実行開始
    ///
    /// - Parameters:
    ///   - scenarioID: シナリオのID
    ///   - prompt: ユーザーのプロンプト
    func start(scenarioID: String, prompt: String) {
        switch scenarioID {
        case ResearchScenario.id:
            start(scenario: ResearchScenario.self, prompt: prompt) { .research($0) }
        case CalculationScenario.id:
            start(scenario: CalculationScenario.self, prompt: prompt) { .calculation($0) }
        case TemporalScenario.id:
            start(scenario: TemporalScenario.self, prompt: prompt) { .temporal($0) }
        case MultiToolScenario.id:
            start(scenario: MultiToolScenario.self, prompt: prompt) { .multiTool($0) }
        case ReasoningScenario.id:
            start(scenario: ReasoningScenario.self, prompt: prompt) { .reasoning($0) }
        case MemoryScenario.id:
            start(scenario: MemoryScenario.self, prompt: prompt) { .memory($0) }
        default:
            state = .error("不明なシナリオID: \(scenarioID)")
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

    // MARK: - Private Methods - Scenario Execution

    private func executeScenario<S: AgentScenarioType>(
        scenario: S.Type,
        prompt: String,
        tools: ToolSet,
        transform: @escaping (S.Output) -> AgentResult
    ) async {
        do {
            switch settings.selectedProvider {
            case .anthropic:
                guard let client = settings.createAnthropicClient() else {
                    state = .error("Anthropic クライアントの作成に失敗しました")
                    runningTask = nil
                    return
                }
                try await runScenario(
                    scenario: scenario,
                    client: client,
                    model: settings.claudeModelOption.model,
                    prompt: prompt,
                    tools: tools,
                    transform: transform
                )

            case .openai:
                guard let client = settings.createOpenAIClient() else {
                    state = .error("OpenAI クライアントの作成に失敗しました")
                    runningTask = nil
                    return
                }
                try await runScenario(
                    scenario: scenario,
                    client: client,
                    model: settings.gptModelOption.model,
                    prompt: prompt,
                    tools: tools,
                    transform: transform
                )

            case .gemini:
                guard let client = settings.createGeminiClient() else {
                    state = .error("Gemini クライアントの作成に失敗しました")
                    runningTask = nil
                    return
                }
                try await runScenario(
                    scenario: scenario,
                    client: client,
                    model: settings.geminiModelOption.model,
                    prompt: prompt,
                    tools: tools,
                    transform: transform
                )
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

    private func runScenario<S: AgentScenarioType, Client: AgentCapableClient>(
        scenario: S.Type,
        client: Client,
        model: Client.Model,
        prompt: String,
        tools: ToolSet,
        transform: @escaping (S.Output) -> AgentResult
    ) async throws where Client.Model: Sendable {
        let config = settings.createAgentConfiguration()
        let systemPrompt = S.systemPrompt()

        let agentStream: some AgentStepStream<S.Output> = client.runAgent(
            prompt: prompt,
            model: model,
            tools: tools,
            systemPrompt: systemPrompt,
            configuration: config
        )

        var finalResult: S.Output?

        for try await step in agentStream {
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

    // MARK: - Private Methods - Step Processing

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
                detail: formatToolInput(info.arguments)
            )

        case .toolResult(let info):
            return AgentStepInfo(
                type: .toolResult,
                content: info.output,
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
