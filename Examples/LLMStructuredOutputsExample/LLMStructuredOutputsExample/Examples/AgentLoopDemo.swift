//
//  AgentLoopDemo.swift
//  LLMStructuredOutputsExample
//
//  エージェントループデモ
//

import SwiftUI
import LLMStructuredOutputs

/// エージェントループデモ
///
/// `runAgent` を使ったツール実行と構造化出力の自動ループを体験できます。
/// LLMが必要なツールを選択・実行し、最終的に構造化された結果を返します。
struct AgentLoopDemo: View {
    private var settings = AppSettings.shared

    @State private var selectedScenarioIndex = 0
    @State private var inputText = AgentScenario.scenarios[0].prompt
    @State private var state: AgentLoopState = .idle
    @State private var steps: [AgentStepInfo] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - 説明
                DescriptionSection()

                Divider()

                // MARK: - シナリオ選択
                VStack(alignment: .leading, spacing: 12) {
                    ScenarioPicker(
                        scenarios: AgentScenario.scenarios,
                        selectedIndex: $selectedScenarioIndex
                    )
                    .onChange(of: selectedScenarioIndex) { _, newValue in
                        inputText = AgentScenario.scenarios[newValue].prompt
                    }

                    InputTextEditor(
                        title: "プロンプト",
                        text: $inputText,
                        minHeight: 80
                    )
                }

                // MARK: - 登録ツール一覧
                RegisteredToolsSection()

                // MARK: - 実行
                if settings.isCurrentProviderAvailable {
                    ExecuteButton(
                        isLoading: state.isLoading,
                        isEnabled: !inputText.isEmpty
                    ) {
                        executeAgentLoop()
                    }
                } else {
                    APIKeyRequiredView(provider: settings.selectedProvider)
                }

                // MARK: - 結果
                AgentLoopResultView(state: state, steps: steps)

                // MARK: - コード例
                CodeExampleSection()
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("エージェントループ")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions

    private func executeAgentLoop() {
        state = .loading
        steps = []

        let tools = AgentDemoToolSet.tools

        Task {
            do {
                switch settings.selectedProvider {
                case .anthropic:
                    guard let client = settings.createAnthropicClient() else { return }
                    try await runAnthropicAgent(client: client, tools: tools)

                case .openai:
                    guard let client = settings.createOpenAIClient() else { return }
                    try await runOpenAIAgent(client: client, tools: tools)

                case .gemini:
                    guard let client = settings.createGeminiClient() else { return }
                    try await runGeminiAgent(client: client, tools: tools)
                }
            } catch {
                state = .error(error)
            }
        }
    }

    private func runAnthropicAgent(client: AnthropicClient, tools: ToolSet) async throws {
        let agentStream: some AgentStepStream<WeatherReport> = client.runAgent(
            prompt: inputText,
            model: settings.claudeModelOption.model,
            tools: tools,
            systemPrompt: "ユーザーの要求に応じてツールを使用し、構造化されたレポートを生成してください。"
        )

        var finalResult: WeatherReport?

        for try await step in agentStream {
            let stepInfo = processStep(step)
            await MainActor.run {
                steps.append(stepInfo)
            }

            if case .finalResponse(let report) = step {
                finalResult = report
            }
        }

        if let result = finalResult {
            state = .success(AnyEncodable(result))
        } else {
            state = .error(AgentError.invalidState("最終レスポンスが取得できませんでした"))
        }
    }

    private func runOpenAIAgent(client: OpenAIClient, tools: ToolSet) async throws {
        let agentStream: some AgentStepStream<WeatherReport> = client.runAgent(
            prompt: inputText,
            model: settings.gptModelOption.model,
            tools: tools,
            systemPrompt: "ユーザーの要求に応じてツールを使用し、構造化されたレポートを生成してください。"
        )

        var finalResult: WeatherReport?

        for try await step in agentStream {
            let stepInfo = processStep(step)
            await MainActor.run {
                steps.append(stepInfo)
            }

            if case .finalResponse(let report) = step {
                finalResult = report
            }
        }

        if let result = finalResult {
            state = .success(AnyEncodable(result))
        } else {
            state = .error(AgentError.invalidState("最終レスポンスが取得できませんでした"))
        }
    }

    private func runGeminiAgent(client: GeminiClient, tools: ToolSet) async throws {
        let agentStream: some AgentStepStream<WeatherReport> = client.runAgent(
            prompt: inputText,
            model: settings.geminiModelOption.model,
            tools: tools,
            systemPrompt: "ユーザーの要求に応じてツールを使用し、構造化されたレポートを生成してください。"
        )

        var finalResult: WeatherReport?

        for try await step in agentStream {
            let stepInfo = processStep(step)
            await MainActor.run {
                steps.append(stepInfo)
            }

            if case .finalResponse(let report) = step {
                finalResult = report
            }
        }

        if let result = finalResult {
            state = .success(AnyEncodable(result))
        } else {
            state = .error(AgentError.invalidState("最終レスポンスが取得できませんでした"))
        }
    }

    private func processStep(_ step: AgentStep<WeatherReport>) -> AgentStepInfo {
        switch step {
        case .thinking(let response):
            let text = response.content.compactMap { $0.text }.joined()
            return AgentStepInfo(type: .thinking, content: text.isEmpty ? "（考え中...）" : String(text.prefix(200)))

        case .toolCall(let info):
            return AgentStepInfo(type: .toolCall, content: info.name, detail: formatToolInput(info.arguments))

        case .toolResult(let info):
            return AgentStepInfo(type: .toolResult, content: info.output, isError: info.isError)

        case .finalResponse(let report):
            return AgentStepInfo(type: .finalResponse, content: "\(report.location): \(report.conditions), \(report.temperature)°\(report.unit)")
        }
    }

    private func formatToolInput(_ data: Data) -> String? {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }
}

// MARK: - Agent Output Models

/// エージェントの最終出力: 天気レポート
@Structured("Weather report with location and conditions")
struct WeatherReport {
    @StructuredField("The location for the weather report")
    var location: String

    @StructuredField("Weather conditions (e.g., Sunny, Cloudy, Rainy)")
    var conditions: String

    @StructuredField("Temperature value")
    var temperature: Int

    @StructuredField("Temperature unit (C or F)")
    var unit: String

    @StructuredField("Brief summary of the weather")
    var summary: String
}

// MARK: - Agent Demo Tool Set

enum AgentDemoToolSet {
    static var tools: ToolSet {
        ToolSet {
            AgentGetWeatherTool.self
            AgentCalculatorTool.self
            AgentCurrentTimeTool.self
        }
    }

    static let descriptions: [(name: String, description: String, icon: String)] = [
        ("get_weather_tool", "都市の天気を取得", "cloud.sun.fill"),
        ("calculator_tool", "数式を計算", "function"),
        ("get_current_time", "現在時刻を取得", "clock.fill")
    ]
}

@Tool("指定された都市の現在の天気を取得します")
struct AgentGetWeatherTool {
    @ToolArgument("天気を取得する都市名（例: 東京、大阪）")
    var location: String

    @ToolArgument("温度の単位（celsius または fahrenheit）")
    var unit: String?

    func call() async throws -> String {
        let temp = Int.random(in: 15...30)
        let conditions = ["晴れ", "曇り", "小雨", "快晴"].randomElement()!
        let unitSymbol = unit == "fahrenheit" ? "F" : "C"
        return "\(location)の天気: \(conditions)、\(temp)°\(unitSymbol)"
    }
}

@Tool("数式を計算して結果を返します")
struct AgentCalculatorTool {
    @ToolArgument("計算する数式（例: 2 + 3 * 4）")
    var expression: String

    func call() async throws -> String {
        let nsExpression = NSExpression(format: expression)
        if let result = nsExpression.expressionValue(with: nil, context: nil) as? NSNumber {
            return "\(expression) = \(result)"
        }
        return "計算できませんでした: \(expression)"
    }
}

@Tool("現在の日時を取得します", name: "get_current_time")
struct AgentCurrentTimeTool {
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

// MARK: - Agent Scenario

struct AgentScenario {
    let name: String
    let prompt: String

    static let scenarios: [AgentScenario] = [
        AgentScenario(
            name: "華氏変換",
            prompt: "東京の天気を調べて、気温を華氏に変換してレポートを作成してください。変換には計算ツールを使ってください。"
        ),
        AgentScenario(
            name: "時刻付きレポート",
            prompt: "現在時刻を確認してから東京の天気を調べて、時刻情報を含めた天気レポートを作成してください。"
        ),
        AgentScenario(
            name: "2都市比較",
            prompt: "東京とニューヨークの天気を両方調べて、気温差を計算し、どちらが暖かいかをまとめたレポートを作成してください。"
        )
    ]
}

// MARK: - Agent Loop State

enum AgentLoopState {
    case idle
    case loading
    case success(AnyEncodable)
    case error(Error)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

/// 型消去用のEncodableラッパー
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        _encode = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

// MARK: - Agent Step Info

struct AgentStepInfo: Identifiable {
    let id = UUID()
    let type: StepType
    let content: String
    var detail: String?
    var isError: Bool = false

    enum StepType {
        case thinking
        case toolCall
        case toolResult
        case finalResponse

        var icon: String {
            switch self {
            case .thinking: return "brain.head.profile"
            case .toolCall: return "wrench.and.screwdriver"
            case .toolResult: return "doc.text"
            case .finalResponse: return "checkmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .thinking: return .purple
            case .toolCall: return .blue
            case .toolResult: return .green
            case .finalResponse: return .orange
            }
        }

        var label: String {
            switch self {
            case .thinking: return "思考"
            case .toolCall: return "ツール呼び出し"
            case .toolResult: return "ツール結果"
            case .finalResponse: return "最終レスポンス"
            }
        }
    }
}

// MARK: - Description Section

private struct DescriptionSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("このデモについて", systemImage: "info.circle.fill")
                .font(.headline)

            Text("""
            `runAgent` を使うと、LLMが自動的に必要なツールを選択・実行し、
            最終的に構造化された出力を生成するまでループします。

            このデモでは以下の流れを体験できます：
            1. プロンプトを送信
            2. LLMがツール呼び出しを判断
            3. ツールを自動実行
            4. 結果を元に構造化出力を生成
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Scenario Picker

private struct ScenarioPicker: View {
    let scenarios: [AgentScenario]
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

// MARK: - Registered Tools Section

private struct RegisteredToolsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("登録ツール")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(AgentDemoToolSet.descriptions, id: \.name) { tool in
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

// MARK: - Agent Loop Result View

private struct AgentLoopResultView: View {
    let state: AgentLoopState
    let steps: [AgentStepInfo]

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
                        description: Text("「実行」ボタンを押してエージェントループを開始")
                    )

                case .loading:
                    VStack(alignment: .leading, spacing: 12) {
                        Text("エージェント実行中...")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        StepsListView(steps: steps)
                    }

                case .success(let result):
                    VStack(alignment: .leading, spacing: 16) {
                        // ステップ履歴
                        if !steps.isEmpty {
                            StepsListView(steps: steps)
                        }

                        // 最終結果
                        VStack(alignment: .leading, spacing: 8) {
                            Text("構造化出力結果")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(formatJSON(result))
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                case .error(let error):
                    VStack(alignment: .leading, spacing: 12) {
                        if !steps.isEmpty {
                            StepsListView(steps: steps)
                        }
                        ErrorView(error: error)
                    }
                }
            }
        }
        .animation(.default, value: state.isLoading)
    }

    private func formatJSON(_ value: AnyEncodable) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(value),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "JSONへの変換に失敗しました"
        }

        return jsonString
    }
}

// MARK: - Steps List View

private struct StepsListView: View {
    let steps: [AgentStepInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("実行ステップ")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(steps) { step in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: step.type.icon)
                        .foregroundStyle(step.isError ? .red : step.type.color)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.type.label)
                            .font(.caption.bold())
                            .foregroundStyle(step.isError ? .red : step.type.color)

                        Text(step.content)
                            .font(.caption)
                            .foregroundStyle(.primary)

                        if let detail = step.detail {
                            Text(detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(step.type.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
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

        // 最終出力の型を定義
        @Structured("天気レポート")
        struct WeatherReport {
            @StructuredField("場所")
            var location: String
            @StructuredField("天気")
            var conditions: String
            @StructuredField("気温")
            var temperature: Int
            @StructuredField("単位")
            var unit: String
            @StructuredField("要約")
            var summary: String
        }

        // ツールを定義
        @Tool("天気を取得する")
        struct GetWeather {
            @ToolArgument("都市名")
            var location: String

            func call() async throws -> String {
                return "\\(location): 晴れ、25°C"
            }
        }

        @Tool("計算する")
        struct Calculator {
            @ToolArgument("数式")
            var expression: String

            func call() async throws -> String {
                // 例: 摂氏→華氏変換 (25 * 9 / 5 + 32)
                return "\\(expression) = 77"
            }
        }

        // ツールセットを作成（複数ツール）
        let tools = ToolSet {
            GetWeather.self
            Calculator.self
        }

        // エージェントループを実行
        // LLMが必要なツールを順次選択・実行します
        let client = AnthropicClient(apiKey: "...")

        let agentStream: some AgentStepStream<WeatherReport> = client.runAgent(
            prompt: "東京の天気を調べて、気温を華氏に変換してレポートを作成して",
            model: .sonnet,
            tools: tools
        )

        for try await step in agentStream {
            switch step {
            case .thinking(let response):
                print("💭 思考中...")
            case .toolCall(let info):
                print("🔧 ツール呼び出し: \\(info.name)")
            case .toolResult(let info):
                print("📤 結果: \\(info.content)")
            case .finalResponse(let report):
                print("✅ 完了: \\(report.location) - \\(report.temperature)°\\(report.unit)")
            }
        }
        // 出力例:
        // 🔧 ツール呼び出し: get_weather
        // 📤 結果: 東京: 晴れ、25°C
        // 🔧 ツール呼び出し: calculator
        // 📤 結果: 25 * 9 / 5 + 32 = 77
        // ✅ 完了: 東京 - 77°F
        """
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AgentLoopDemo()
    }
}
