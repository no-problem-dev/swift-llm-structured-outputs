//
//  ToolCallingDemo.swift
//  LLMStructuredOutputsExample
//
//  ツールコール（関数呼び出し）デモ
//

import SwiftUI
import LLMStructuredOutputs

/// ツールコールデモ
///
/// `@Tool` マクロを使ったツール定義と `generateWithTools()` による
/// ツール呼び出しを体験できます。
struct ToolCallingDemo: View {
    private var settings = AppSettings.shared

    @State private var selectedScenarioIndex = 0
    @State private var inputText = ToolScenario.scenarios[0].prompt
    @State private var selectedToolChoice: ToolChoiceOption = .auto
    @State private var state: ToolCallState = .idle
    @State private var tokenUsage: TokenUsage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - 説明
                DescriptionSection()

                Divider()

                // MARK: - シナリオ選択
                VStack(alignment: .leading, spacing: 12) {
                    ScenarioPicker(
                        scenarios: ToolScenario.scenarios,
                        selectedIndex: $selectedScenarioIndex
                    )
                    .onChange(of: selectedScenarioIndex) { _, newValue in
                        inputText = ToolScenario.scenarios[newValue].prompt
                    }

                    InputTextEditor(
                        title: "プロンプト",
                        text: $inputText,
                        minHeight: 80
                    )
                }

                // MARK: - ツール選択オプション
                ToolChoicePicker(selection: $selectedToolChoice)

                // MARK: - 登録ツール一覧
                RegisteredToolsSection()

                // MARK: - 実行
                if settings.isCurrentProviderAvailable {
                    ExecuteButton(
                        isLoading: state.isLoading,
                        isEnabled: !inputText.isEmpty
                    ) {
                        executeToolCall()
                    }
                } else {
                    APIKeyRequiredView(provider: settings.selectedProvider)
                }

                // MARK: - 結果
                ToolCallResultView(state: state, usage: tokenUsage)

                // MARK: - コード例
                CodeExampleSection()
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("ツールコール")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions

    private func executeToolCall() {
        state = .loading
        tokenUsage = nil

        let tools = DemoToolSet.tools

        Task {
            do {
                let response: ToolCallResponse
                let toolChoice = selectedToolChoice.toToolChoice()

                switch settings.selectedProvider {
                case .anthropic:
                    guard let client = settings.createAnthropicClient() else { return }
                    response = try await client.planToolCalls(
                        prompt: inputText,
                        model: settings.claudeModelOption.model,
                        tools: tools,
                        toolChoice: toolChoice,
                        systemPrompt: "ユーザーの要求に応じて適切なツールを使用してください。",
                        temperature: settings.temperature,
                        maxTokens: settings.maxTokens
                    )

                case .openai:
                    guard let client = settings.createOpenAIClient() else { return }
                    response = try await client.planToolCalls(
                        prompt: inputText,
                        model: settings.gptModelOption.model,
                        tools: tools,
                        toolChoice: toolChoice,
                        systemPrompt: "ユーザーの要求に応じて適切なツールを使用してください。",
                        temperature: settings.temperature,
                        maxTokens: settings.maxTokens
                    )

                case .gemini:
                    guard let client = settings.createGeminiClient() else { return }
                    response = try await client.planToolCalls(
                        prompt: inputText,
                        model: settings.geminiModelOption.model,
                        tools: tools,
                        toolChoice: toolChoice,
                        systemPrompt: "ユーザーの要求に応じて適切なツールを使用してください。",
                        temperature: settings.temperature,
                        maxTokens: settings.maxTokens
                    )
                }

                // ツール呼び出し結果を処理
                var executedResults: [ToolExecutionResult] = []
                for call in response.toolCalls {
                    do {
                        let result = try await tools.execute(toolNamed: call.name, with: call.arguments)
                        executedResults.append(ToolExecutionResult(
                            toolName: call.name,
                            arguments: (try? call.argumentsDictionary()) ?? [:],
                            result: result.stringValue,
                            error: result.isError ? result.stringValue : nil
                        ))
                    } catch {
                        executedResults.append(ToolExecutionResult(
                            toolName: call.name,
                            arguments: (try? call.argumentsDictionary()) ?? [:],
                            result: nil,
                            error: error.localizedDescription
                        ))
                    }
                }

                state = .success(ToolCallResult(
                    response: response,
                    executedResults: executedResults
                ))
                tokenUsage = response.usage

            } catch {
                state = .error(error)
            }
        }
    }
}

// MARK: - Tool Definitions

@Tool("指定された都市の現在の天気を取得します")
struct GetWeatherTool {
    @ToolArgument("天気を取得する都市名（例: 東京、大阪）")
    var location: String

    @ToolArgument("温度の単位（celsius または fahrenheit）")
    var unit: String?

    func call() async throws -> String {
        // デモ用のモックレスポンス
        let temp = Int.random(in: 15...30)
        let conditions = ["晴れ", "曇り", "小雨", "快晴"].randomElement()!
        let unitSymbol = unit == "fahrenheit" ? "F" : "C"
        return "\(location)の天気: \(conditions)、\(temp)°\(unitSymbol)"
    }
}

@Tool("数式を計算して結果を返します")
struct CalculatorTool {
    @ToolArgument("計算する数式（例: 2 + 3 * 4）")
    var expression: String

    func call() async throws -> String {
        // デモ用の簡易計算
        let nsExpression = NSExpression(format: expression)
        if let result = nsExpression.expressionValue(with: nil, context: nil) as? NSNumber {
            return "\(expression) = \(result)"
        }
        return "計算できませんでした: \(expression)"
    }
}

@Tool("現在の日時を取得します", name: "get_current_time")
struct CurrentTimeTool {
    @ToolArgument("タイムゾーン（例: Asia/Tokyo、America/New_York）")
    var timezone: String?

    func call() async throws -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let tz = timezone, let timeZone = TimeZone(identifier: tz) {
            formatter.timeZone = timeZone
        }
        return "現在時刻（\(timezone ?? "システム")）: \(formatter.string(from: Date()))"
    }
}

// MARK: - Demo Tool Set

enum DemoToolSet {
    static var tools: ToolSet {
        ToolSet {
            GetWeatherTool()
            CalculatorTool()
            CurrentTimeTool()
        }
    }

    static let descriptions: [(name: String, description: String, icon: String)] = [
        ("get_weather_tool", "都市の天気を取得", "cloud.sun.fill"),
        ("calculator_tool", "数式を計算", "function"),
        ("get_current_time", "現在時刻を取得", "clock.fill")
    ]
}

// MARK: - Tool Choice Option

enum ToolChoiceOption: String, CaseIterable, Identifiable {
    case auto = "auto"
    case required = "required"
    case none = "none"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "自動選択"
        case .required: return "必須"
        case .none: return "使用しない"
        }
    }

    var description: String {
        switch self {
        case .auto: return "LLMが必要に応じてツールを選択"
        case .required: return "必ずいずれかのツールを呼び出す"
        case .none: return "ツールを呼び出さない"
        }
    }

    func toToolChoice() -> ToolChoice? {
        switch self {
        case .auto: return .auto
        case .required: return .required
        case .none: return ToolChoice.none
        }
    }
}

// MARK: - Tool Scenario

struct ToolScenario {
    let name: String
    let prompt: String
    let expectedTools: [String]

    static let scenarios: [ToolScenario] = [
        ToolScenario(
            name: "天気を確認",
            prompt: "東京の今の天気を教えてください",
            expectedTools: ["get_weather_tool"]
        ),
        ToolScenario(
            name: "計算を依頼",
            prompt: "125 * 8 + 350 を計算してください",
            expectedTools: ["calculator_tool"]
        ),
        ToolScenario(
            name: "時刻を確認",
            prompt: "ニューヨークの現在時刻は？",
            expectedTools: ["get_current_time"]
        ),
        ToolScenario(
            name: "複数ツール",
            prompt: "大阪の天気と、現在の東京時間を教えて",
            expectedTools: ["get_weather_tool", "get_current_time"]
        )
    ]
}

// MARK: - Tool Call State

enum ToolCallState {
    case idle
    case loading
    case success(ToolCallResult)
    case error(Error)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

struct ToolCallResult {
    let response: ToolCallResponse
    let executedResults: [ToolExecutionResult]
}

struct ToolExecutionResult {
    let toolName: String
    let arguments: [String: Any]
    let result: String?
    let error: String?
}

// MARK: - Description Section

private struct DescriptionSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("このデモについて", systemImage: "info.circle.fill")
                .font(.headline)

            Text("""
            `@Tool` マクロでツール（関数）を定義し、LLMに呼び出させることができます。

            このデモでは以下のツールが利用可能です：
            - 天気取得: 指定都市の天気情報
            - 計算機: 数式の計算
            - 時刻取得: タイムゾーン指定可能な現在時刻
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Scenario Picker

private struct ScenarioPicker: View {
    let scenarios: [ToolScenario]
    @Binding var selectedIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("シナリオ")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(scenarios.enumerated()), id: \.offset) { index, scenario in
                        Button {
                            selectedIndex = index
                        } label: {
                            Text(scenario.name)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    selectedIndex == index
                                        ? Color.accentColor
                                        : Color(.systemGray5)
                                )
                                .foregroundStyle(selectedIndex == index ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Tool Choice Picker

private struct ToolChoicePicker: View {
    @Binding var selection: ToolChoiceOption

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ツール選択オプション")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Picker("ツール選択", selection: $selection) {
                ForEach(ToolChoiceOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Text(selection.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Registered Tools Section

private struct RegisteredToolsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("登録ツール")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(DemoToolSet.descriptions, id: \.name) { tool in
                    VStack(spacing: 4) {
                        Image(systemName: tool.icon)
                            .font(.title3)
                            .foregroundStyle(.blue)
                        Text(tool.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

// MARK: - Tool Call Result View

private struct ToolCallResultView: View {
    let state: ToolCallState
    let usage: TokenUsage?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("実行結果", systemImage: "doc.text")
                    .font(.headline)

                Spacer()

                if state.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            Group {
                switch state {
                case .idle:
                    ContentUnavailableView(
                        "実行前",
                        systemImage: "play.circle",
                        description: Text("「実行」ボタンを押してツール呼び出しを試してください")
                    )

                case .loading:
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("ツール呼び出し中...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)

                case .success(let result):
                    VStack(alignment: .leading, spacing: 16) {
                        // ツール呼び出し情報
                        if result.response.hasToolCalls {
                            ToolCallsInfoView(calls: result.response.toolCalls)
                        } else {
                            Text("ツールは呼び出されませんでした")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // 実行結果
                        if !result.executedResults.isEmpty {
                            ExecutionResultsView(results: result.executedResults)
                        }

                        // テキスト応答
                        if let text = result.response.text, !text.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("LLMからのテキスト応答")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)

                                Text(text)
                                    .font(.caption)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }

                        // トークン使用量
                        if let usage = usage {
                            TokenUsageView(usage: usage)
                        }
                    }

                case .error(let error):
                    ErrorView(error: error)
                }
            }
        }
        .animation(.default, value: state.isLoading)
    }
}

// MARK: - Tool Calls Info View

private struct ToolCallsInfoView: View {
    let calls: [ToolCall]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("呼び出されたツール")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(Array(calls.enumerated()), id: \.offset) { index, call in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "function")
                            .foregroundStyle(.blue)
                        Text(call.name)
                            .font(.subheadline.bold())
                    }

                    if let args = try? call.argumentsDictionary(), !args.isEmpty {
                        Text("引数: \(formatArguments(args))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func formatArguments(_ args: [String: Any]) -> String {
        args.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }
}

// MARK: - Execution Results View

private struct ExecutionResultsView: View {
    let results: [ToolExecutionResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ツール実行結果")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(Array(results.enumerated()), id: \.offset) { _, execResult in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: execResult.error == nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(execResult.error == nil ? .green : .red)
                        Text(execResult.toolName)
                            .font(.subheadline.bold())
                    }

                    if let result = execResult.result {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }

                    if let error = execResult.error {
                        Text("エラー: \(error)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Code Example Section

private struct CodeExampleSection: View {
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup("コード例", isExpanded: $isExpanded) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(codeExample)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
    }

    private var codeExample: String {
        """
        import LLMStructuredOutputs

        // ツールを定義
        @Tool("指定された都市の天気を取得する")
        struct GetWeather {
            @ToolArgument("都市名")
            var location: String

            @ToolArgument("温度単位")
            var unit: String?

            func call() async throws -> String {
                // 天気APIを呼び出し
                return "東京: 晴れ、22°C"
            }
        }

        // ツールセットを作成
        let tools = ToolSet {
            GetWeather()
        }

        // LLM にどのツールを呼ぶべきか計画させる
        let client = AnthropicClient(apiKey: "...")
        let plan = try await client.planToolCalls(
            prompt: "東京の天気を教えて",
            model: .sonnet,
            tools: tools,
            toolChoice: .auto
        )

        // 計画されたツール呼び出しを実行
        for call in plan.toolCalls {
            let result = try await tools.execute(
                toolNamed: call.name,
                with: call.arguments
            )
            print(result)  // "東京: 晴れ、22°C"
        }
        """
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ToolCallingDemo()
    }
}
