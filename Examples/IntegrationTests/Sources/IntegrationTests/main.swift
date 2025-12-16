import Foundation
import LLMStructuredOutputs

// MARK: - Environment Configuration

enum Config {
    static var anthropicKey: String? {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
    }
    static var openAIKey: String? {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
    }
    static var geminiKey: String? {
        ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
    }

    static func loadEnvFile() {
        let envPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".env")

        guard let contents = try? String(contentsOf: envPath, encoding: .utf8) else {
            return
        }

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            var value = String(parts[1]).trimmingCharacters(in: .whitespaces)

            // Remove quotes if present
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }

            setenv(key, value, 1)
        }
    }
}

// MARK: - Test Models

@Structured("Person information extracted from text")
struct PersonInfo {
    @StructuredField("Person's full name")
    var name: String

    @StructuredField("Person's age in years", .minimum(0), .maximum(150))
    var age: Int

    @StructuredField("Person's occupation or job title")
    var occupation: String?
}

@StructuredEnum("Sentiment classification")
enum Sentiment: String {
    case positive
    case negative
    case neutral
}

@Structured("Sentiment analysis result")
struct SentimentAnalysis {
    @StructuredField("Overall sentiment classification")
    var sentiment: Sentiment

    @StructuredField("Confidence score", .minimum(0), .maximum(1))
    var confidence: Double

    @StructuredField("Key phrases that influenced the sentiment", .minItems(1), .maxItems(5))
    var keyPhrases: [String]
}

@StructuredEnum("Task priority level")
enum Priority: String {
    case high
    case medium
    case low
}

@Structured("A single task item")
struct TaskItem {
    @StructuredField("Task title")
    var title: String

    @StructuredField("Task priority")
    var priority: Priority

    @StructuredField("Due date if mentioned")
    var dueDate: String?
}

@Structured("Extracted tasks from text")
struct TaskExtraction {
    @StructuredField("List of extracted tasks", .minItems(1))
    var tasks: [TaskItem]
}

@StructuredEnum("Issue severity level")
enum Severity: String {
    case critical
    case warning
    case info
}

@Structured("A code issue")
struct CodeIssue {
    @StructuredField("Issue severity")
    var severity: Severity

    @StructuredField("Issue description")
    var description: String

    @StructuredField("Line number if applicable", .minimum(1))
    var lineNumber: Int?
}

@Structured("Code review result")
struct CodeReview {
    @StructuredField("Overall code quality score", .minimum(1), .maximum(10))
    var qualityScore: Int

    @StructuredField("List of issues found")
    var issues: [CodeIssue]

    @StructuredField("Suggested improvements", .maxItems(5))
    var suggestions: [String]
}

@Structured("Conversation summary")
struct ConversationSummary {
    @StructuredField("Main topics discussed", .minItems(1))
    var topics: [String]

    @StructuredField("Key decisions made")
    var decisions: [String]

    @StructuredField("Action items identified")
    var actionItems: [String]

    @StructuredField("Overall tone of the conversation")
    var tone: String
}

// MARK: - Test Tools

/// 天気を取得するツール
@Tool("Get current weather for a location")
struct GetWeatherTool {
    @ToolArgument("The city name to get weather for")
    var location: String

    @ToolArgument("Temperature unit (celsius or fahrenheit)")
    var unit: String?

    func call() async throws -> String {
        // シミュレートされた天気データ
        return "Weather in \(location): Sunny, 22°\(unit == "fahrenheit" ? "F" : "C")"
    }
}

/// 計算を行うツール
@Tool("Perform a mathematical calculation")
struct CalculatorTool {
    @ToolArgument("The mathematical expression to evaluate")
    var expression: String

    func call() async throws -> String {
        // シンプルな計算シミュレーション
        return "Result of '\(expression)' = 42"
    }
}

/// 現在時刻を取得するツール
@Tool("Get the current time in a timezone", name: "get_current_time")
struct CurrentTimeTool {
    @ToolArgument("The timezone (e.g., 'Asia/Tokyo', 'America/New_York')")
    var timezone: String?

    func call() async throws -> String {
        let tz = timezone ?? "UTC"
        return "Current time in \(tz): 2024-12-14 15:30:00"
    }
}

// MARK: - Agent Test Models

/// エージェントの最終出力用: 天気レポート
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

/// エージェントの最終出力用: 計算結果レポート
@Structured("Calculation result report")
struct CalculationReport {
    @StructuredField("The original expression")
    var expression: String

    @StructuredField("The calculated result")
    var result: Int

    @StructuredField("Explanation of the calculation")
    var explanation: String
}

// MARK: - Test Runner

actor TestRunner {
    private var passedTests = 0
    private var failedTests = 0
    private var skippedTests = 0

    func recordPass() { passedTests += 1 }
    func recordFail() { failedTests += 1 }
    func recordSkip() { skippedTests += 1 }

    func summary() -> (passed: Int, failed: Int, skipped: Int) {
        (passedTests, failedTests, skippedTests)
    }
}

@MainActor
func runTest<T: Encodable & Sendable>(
    name: String,
    runner: TestRunner,
    test: @escaping @Sendable () async throws -> T
) async {
    print("\n🧪 Testing: \(name)")
    print("   " + String(repeating: "-", count: 50))

    do {
        let result = try await test()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(result),
           let json = String(data: data, encoding: .utf8) {
            print("   ✅ PASSED")
            print("   Result:")
            for line in json.components(separatedBy: .newlines) {
                print("      \(line)")
            }
        }
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }
}

func skipTest(name: String, reason: String, runner: TestRunner) async {
    print("\n⏭️  Skipping: \(name)")
    print("   Reason: \(reason)")
    await runner.recordSkip()
}

@MainActor
func runToolTest(
    name: String,
    runner: TestRunner,
    test: @escaping @Sendable () async throws -> ToolCallResponse
) async {
    print("\n🔧 Testing: \(name)")
    print("   " + String(repeating: "-", count: 50))

    do {
        let response = try await test()
        print("   ✅ PASSED")
        print("   Tool Calls: \(response.toolCalls.count)")
        for (index, call) in response.toolCalls.enumerated() {
            print("      [\(index + 1)] \(call.name)")
            if let args = try? call.argumentsDictionary() {
                print("          Arguments: \(args)")
            }
        }
        if let text = response.text {
            print("   Text: \(text.prefix(100))...")
        }
        print("   Stop Reason: \(response.stopReason?.rawValue ?? "nil")")
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }
}

// MARK: - Agent Test Runner

@MainActor
func runAgentTest<Output: StructuredProtocol & Encodable & Sendable>(
    name: String,
    runner: TestRunner,
    test: @escaping @Sendable () async throws -> Output
) async {
    print("\n🤖 Agent Test: \(name)")
    print("   " + String(repeating: "-", count: 50))

    do {
        let result = try await test()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(result),
           let json = String(data: data, encoding: .utf8) {
            print("   ✅ PASSED")
            print("   Final Result:")
            for line in json.components(separatedBy: .newlines) {
                print("      \(line)")
            }
        }
        await runner.recordPass()
    } catch {
        print("   ❌ FAILED: \(error)")
        await runner.recordFail()
    }
}

// MARK: - Test Suites

@MainActor
func runAnthropicTests(runner: TestRunner) async {
    print("\n" + String(repeating: "=", count: 60))
    print("🟠 ANTHROPIC (Claude) Tests")
    print(String(repeating: "=", count: 60))

    guard let apiKey = Config.anthropicKey, !apiKey.isEmpty else {
        print("⚠️  ANTHROPIC_API_KEY not set - skipping Anthropic tests")
        await runner.recordSkip()
        return
    }

    let client = AnthropicClient(apiKey: apiKey)

    // Test 1: Basic structured output
    await runTest(name: "Basic Person Extraction", runner: runner) {
        let response: ChatResponse<PersonInfo> = try await client.chat(
            prompt: "John Smith is a 35-year-old software engineer.",
            model: .sonnet
        )
        return response.result
    }

    // Test 2: Enum support
    await runTest(name: "Sentiment Analysis with Enum", runner: runner) {
        let response: ChatResponse<SentimentAnalysis> = try await client.chat(
            prompt: "I absolutely love this product! It's amazing and works perfectly.",
            model: .sonnet
        )
        return response.result
    }

    // Test 3: Nested structures
    await runTest(name: "Task Extraction (Nested)", runner: runner) {
        let response: ChatResponse<TaskExtraction> = try await client.chat(
            prompt: """
            Meeting notes:
            - Need to finish the report by Friday (high priority)
            - Schedule team sync next week (medium priority)
            - Update documentation when possible (low priority)
            """,
            model: .sonnet
        )
        return response.result
    }

    // Test 4: With system prompt
    await runTest(name: "Code Review with System Prompt", runner: runner) {
        let code = """
        func add(a, b) {
            return a + b
        }
        """
        let response: ChatResponse<CodeReview> = try await client.chat(
            prompt: "Review this code:\n\(code)",
            model: .sonnet,
            systemPrompt: "You are a senior code reviewer. Be thorough but fair."
        )
        return response.result
    }

    // Test 5: Prompt DSL
    await runTest(name: "Prompt DSL Usage", runner: runner) {
        let prompt = Prompt {
            PromptComponent.role("You are an expert meeting summarizer")
            PromptComponent.objective("Extract key information from meeting transcripts")
            PromptComponent.instruction("Focus on actionable items and decisions")
            PromptComponent.constraint("Only include information explicitly mentioned")
        }

        let response: ChatResponse<ConversationSummary> = try await client.chat(
            prompt: """
            Alice: Let's discuss the Q4 roadmap.
            Bob: I think we should prioritize the mobile app.
            Alice: Agreed. Let's set the deadline for end of November.
            Bob: I'll create the project plan by next Monday.
            """,
            model: .sonnet,
            systemPrompt: prompt.render()
        )
        return response.result
    }

    // Test 6: Conversation
    await runTest(name: "Conversation with History", runner: runner) {
        let conversation = Conversation<AnthropicClient>(
            client: client,
            model: .sonnet,
            systemPrompt: "Extract person information from the conversation."
        )

        let _: PersonInfo = try await conversation.send("I met someone interesting today.")
        let result: PersonInfo = try await conversation.send("His name is Bob and he's 42. He works as a chef.")
        return result
    }

    // Test 7: Tool Calling - Single Tool
    await runToolTest(name: "Tool Calling - Weather", runner: runner) {
        let tools = ToolSet {
            GetWeatherTool()
        }

        return try await client.planToolCalls(
            prompt: "What's the weather like in Tokyo?",
            model: .sonnet,
            tools: tools,
            toolChoice: .auto
        )
    }

    // Test 8: Tool Calling - Multiple Tools
    await runToolTest(name: "Tool Calling - Multiple Tools", runner: runner) {
        let tools = ToolSet {
            GetWeatherTool()
            CalculatorTool()
            CurrentTimeTool()
        }

        return try await client.planToolCalls(
            prompt: "What time is it in Tokyo and what's the weather there?",
            model: .sonnet,
            tools: tools,
            toolChoice: .auto
        )
    }

    // Test 9: Tool Calling - Required
    await runToolTest(name: "Tool Calling - Required", runner: runner) {
        let tools = ToolSet {
            CalculatorTool()
        }

        return try await client.planToolCalls(
            prompt: "Hello, how are you?",
            model: .sonnet,
            tools: tools,
            toolChoice: .required
        )
    }
}

@MainActor
func runOpenAITests(runner: TestRunner) async {
    print("\n" + String(repeating: "=", count: 60))
    print("🟢 OPENAI (GPT) Tests")
    print(String(repeating: "=", count: 60))

    guard let apiKey = Config.openAIKey, !apiKey.isEmpty else {
        print("⚠️  OPENAI_API_KEY not set - skipping OpenAI tests")
        await runner.recordSkip()
        return
    }

    let client = OpenAIClient(apiKey: apiKey)

    // Test 1: Basic structured output
    await runTest(name: "Basic Person Extraction", runner: runner) {
        let response: ChatResponse<PersonInfo> = try await client.chat(
            prompt: "Emily Chen is a 28-year-old data scientist.",
            model: .gpt4oMini
        )
        return response.result
    }

    // Test 2: Enum support
    await runTest(name: "Sentiment Analysis with Enum", runner: runner) {
        let response: ChatResponse<SentimentAnalysis> = try await client.chat(
            prompt: "This is the worst experience I've ever had. Completely disappointed.",
            model: .gpt4oMini
        )
        return response.result
    }

    // Test 3: Nested structures
    await runTest(name: "Task Extraction (Nested)", runner: runner) {
        let response: ChatResponse<TaskExtraction> = try await client.chat(
            prompt: """
            TODO list:
            - URGENT: Fix production bug
            - Review PR #123 this week
            - Research new frameworks sometime
            """,
            model: .gpt4oMini
        )
        return response.result
    }

    // Test 4: With system prompt
    await runTest(name: "Code Review with System Prompt", runner: runner) {
        let code = """
        const data = JSON.parse(userInput);
        eval(data.command);
        """
        let response: ChatResponse<CodeReview> = try await client.chat(
            prompt: "Review this JavaScript code:\n\(code)",
            model: .gpt4oMini,
            systemPrompt: "You are a security-focused code reviewer."
        )
        return response.result
    }

    // Test 5: Prompt DSL
    await runTest(name: "Prompt DSL Usage", runner: runner) {
        let prompt = Prompt {
            PromptComponent.role("Expert conversation analyst")
            PromptComponent.objective("Summarize conversations accurately")
            PromptComponent.thinkingStep("Identify main topics discussed")
            PromptComponent.thinkingStep("Note any decisions or agreements")
            PromptComponent.thinkingStep("List action items with owners if mentioned")
        }

        let response: ChatResponse<ConversationSummary> = try await client.chat(
            prompt: """
            Manager: How's the new feature coming along?
            Dev: Almost done, just need to add tests.
            Manager: Great, let's aim for release on Wednesday.
            Dev: Sure, I'll have it ready by Tuesday for QA.
            """,
            model: .gpt4oMini,
            systemPrompt: prompt.render()
        )
        return response.result
    }

    // Test 6: Conversation
    await runTest(name: "Conversation with History", runner: runner) {
        let conversation = Conversation<OpenAIClient>(
            client: client,
            model: .gpt4oMini,
            systemPrompt: "Extract person information from what the user tells you."
        )

        let _: PersonInfo = try await conversation.send("Let me tell you about my friend.")
        let result: PersonInfo = try await conversation.send("She's called Sarah, 31 years old, and she's a lawyer.")
        return result
    }

    // Test 7: Tool Calling - Single Tool
    await runToolTest(name: "Tool Calling - Weather", runner: runner) {
        let tools = ToolSet {
            GetWeatherTool()
        }

        return try await client.planToolCalls(
            prompt: "What's the weather like in New York?",
            model: .gpt4oMini,
            tools: tools,
            toolChoice: .auto
        )
    }

    // Test 8: Tool Calling - Multiple Tools
    await runToolTest(name: "Tool Calling - Multiple Tools", runner: runner) {
        let tools = ToolSet {
            GetWeatherTool()
            CalculatorTool()
            CurrentTimeTool()
        }

        return try await client.planToolCalls(
            prompt: "Calculate 15 * 7 and tell me the current time in London",
            model: .gpt4oMini,
            tools: tools,
            toolChoice: .auto
        )
    }

    // Test 9: Tool Calling - Specific Tool
    await runToolTest(name: "Tool Calling - Specific Tool", runner: runner) {
        let tools = ToolSet {
            GetWeatherTool()
            CalculatorTool()
        }

        return try await client.planToolCalls(
            prompt: "I need some help",
            model: .gpt4oMini,
            tools: tools,
            toolChoice: .tool("calculator_tool")
        )
    }
}

@MainActor
func runGeminiTests(runner: TestRunner) async {
    print("\n" + String(repeating: "=", count: 60))
    print("🔵 GEMINI Tests")
    print(String(repeating: "=", count: 60))

    guard let apiKey = Config.geminiKey, !apiKey.isEmpty else {
        print("⚠️  GEMINI_API_KEY not set - skipping Gemini tests")
        await runner.recordSkip()
        return
    }

    let client = GeminiClient(apiKey: apiKey)

    // Test 1: Basic structured output
    await runTest(name: "Basic Person Extraction", runner: runner) {
        let response: ChatResponse<PersonInfo> = try await client.chat(
            prompt: "Michael Johnson, age 45, is a professional architect.",
            model: .flash25
        )
        return response.result
    }

    // Test 2: Enum support
    await runTest(name: "Sentiment Analysis with Enum", runner: runner) {
        let response: ChatResponse<SentimentAnalysis> = try await client.chat(
            prompt: "The product is okay. Nothing special, but it works as expected.",
            model: .flash25
        )
        return response.result
    }

    // Test 3: Nested structures
    await runTest(name: "Task Extraction (Nested)", runner: runner) {
        let response: ChatResponse<TaskExtraction> = try await client.chat(
            prompt: """
            Sprint backlog:
            - Critical: Deploy hotfix today
            - Important: Refactor authentication module by EOW
            - Nice to have: Add dark mode support
            """,
            model: .flash25
        )
        return response.result
    }

    // Test 4: With system prompt
    await runTest(name: "Code Review with System Prompt", runner: runner) {
        let code = """
        password = "admin123"
        db.query("SELECT * FROM users WHERE pass = '" + password + "'")
        """
        let response: ChatResponse<CodeReview> = try await client.chat(
            prompt: "Review this Python code:\n\(code)",
            model: .flash25,
            systemPrompt: "You are a security expert reviewing code for vulnerabilities."
        )
        return response.result
    }

    // Test 5: Prompt DSL
    await runTest(name: "Prompt DSL Usage", runner: runner) {
        let prompt = Prompt {
            PromptComponent.role("Meeting notes analyzer")
            PromptComponent.context("You are analyzing a technical team's standup meeting")
            PromptComponent.instruction("Extract topics, decisions, and action items")
            PromptComponent.important("Be concise and focus on actionable information")
        }

        let response: ChatResponse<ConversationSummary> = try await client.chat(
            prompt: """
            Tom: Yesterday I fixed the login bug. Today I'm working on the dashboard.
            Jane: I'm blocked on the API integration, need help from Tom.
            Tom: I can help after lunch. Let's pair on it.
            Jane: Perfect, thanks!
            """,
            model: .flash25,
            systemPrompt: prompt.render()
        )
        return response.result
    }

    // Test 6: Conversation
    await runTest(name: "Conversation with History", runner: runner) {
        let conversation = Conversation<GeminiClient>(
            client: client,
            model: .flash25,
            systemPrompt: "Extract person details from the user's messages."
        )

        let _: PersonInfo = try await conversation.send("I want to tell you about my colleague.")
        let result: PersonInfo = try await conversation.send("His name is David Lee, he's 38, and he's our lead designer.")
        return result
    }

    // Test 7: Tool Calling - Single Tool
    await runToolTest(name: "Tool Calling - Weather", runner: runner) {
        let tools = ToolSet {
            GetWeatherTool()
        }

        return try await client.planToolCalls(
            prompt: "What's the weather like in Paris?",
            model: .flash25,
            tools: tools,
            toolChoice: .auto
        )
    }

    // Test 8: Tool Calling - Multiple Tools
    await runToolTest(name: "Tool Calling - Multiple Tools", runner: runner) {
        let tools = ToolSet {
            GetWeatherTool()
            CalculatorTool()
            CurrentTimeTool()
        }

        return try await client.planToolCalls(
            prompt: "What's 123 + 456 and what time is it in Sydney?",
            model: .flash25,
            tools: tools,
            toolChoice: .auto
        )
    }

    // Test 9: Tool Calling - Required
    await runToolTest(name: "Tool Calling - Required", runner: runner) {
        let tools = ToolSet {
            CurrentTimeTool()
        }

        return try await client.planToolCalls(
            prompt: "Just say hello",
            model: .flash25,
            tools: tools,
            toolChoice: .required
        )
    }
}

// MARK: - Agent Test Suites

@MainActor
func runAnthropicAgentTests(runner: TestRunner) async {
    print("\n" + String(repeating: "=", count: 60))
    print("🟠 ANTHROPIC Agent Tests")
    print(String(repeating: "=", count: 60))

    guard let apiKey = Config.anthropicKey, !apiKey.isEmpty else {
        print("⚠️  ANTHROPIC_API_KEY not set - skipping Anthropic agent tests")
        await runner.recordSkip()
        return
    }

    let client = AnthropicClient(apiKey: apiKey)

    // Agent Test 1: 天気ツールを使ったエージェントループ
    await runAgentTest(name: "Weather Agent Loop", runner: runner) {
        let tools = ToolSet {
            GetWeatherTool()
        }

        let agentSequence: AgentStepSequence<AnthropicClient, WeatherReport> = client.runAgent(
            prompt: "東京の天気を調べて、天気レポートを作成してください",
            model: .sonnet,
            tools: tools,
            systemPrompt: "You are a helpful weather assistant. Use the weather tool to get information, then create a structured report."
        )

        var stepCount = 0
        var finalResult: WeatherReport?

        for try await step in agentSequence {
            stepCount += 1
            switch step {
            case .thinking(let response):
                let text = response.content.compactMap { $0.text }.joined()
                print("   💭 Thinking: \(text.prefix(100))...")
            case .toolCall(let info):
                print("   🔧 Tool Call: \(info.name)")
            case .toolResult(let info):
                print("   📋 Tool Result: \(info.content)")
            case .finalResponse(let report):
                print("   ✅ Final Response: \(report.location) - \(report.conditions)")
                finalResult = report
            }
        }

        print("   📊 Total steps: \(stepCount)")
        guard let result = finalResult else {
            throw AgentError.invalidState("No final response received")
        }
        return result
    }

    // Agent Test 2: 計算ツールを使ったエージェントループ
    await runAgentTest(name: "Calculator Agent Loop", runner: runner) {
        let tools = ToolSet {
            CalculatorTool()
        }

        let agentSequence: AgentStepSequence<AnthropicClient, CalculationReport> = client.runAgent(
            prompt: "25 x 4 を計算して、結果をレポートにまとめてください",
            model: .sonnet,
            tools: tools,
            systemPrompt: "You are a calculator assistant. Use the calculator tool to compute, then provide a structured report."
        )

        var finalResult: CalculationReport?

        for try await step in agentSequence {
            switch step {
            case .thinking:
                print("   💭 Thinking...")
            case .toolCall(let info):
                print("   🔧 Tool Call: \(info.name)")
            case .toolResult(let info):
                print("   📋 Tool Result: \(info.content)")
            case .finalResponse(let report):
                print("   ✅ Final Response: \(report.expression) = \(report.result)")
                finalResult = report
            }
        }

        guard let result = finalResult else {
            throw AgentError.invalidState("No final response received")
        }
        return result
    }
}

@MainActor
func runOpenAIAgentTests(runner: TestRunner) async {
    print("\n" + String(repeating: "=", count: 60))
    print("🟢 OPENAI Agent Tests")
    print(String(repeating: "=", count: 60))

    guard let apiKey = Config.openAIKey, !apiKey.isEmpty else {
        print("⚠️  OPENAI_API_KEY not set - skipping OpenAI agent tests")
        await runner.recordSkip()
        return
    }

    let client = OpenAIClient(apiKey: apiKey)

    // Agent Test 1: 天気ツールを使ったエージェントループ
    await runAgentTest(name: "Weather Agent Loop", runner: runner) {
        let tools = ToolSet {
            GetWeatherTool()
        }

        let agentSequence: AgentStepSequence<OpenAIClient, WeatherReport> = client.runAgent(
            prompt: "Check the weather in New York and create a weather report",
            model: .gpt4oMini,
            tools: tools,
            systemPrompt: "You are a helpful weather assistant. Use the weather tool to get information, then create a structured report."
        )

        var finalResult: WeatherReport?

        for try await step in agentSequence {
            switch step {
            case .thinking:
                print("   💭 Thinking...")
            case .toolCall(let info):
                print("   🔧 Tool Call: \(info.name)")
            case .toolResult(let info):
                print("   📋 Tool Result: \(info.content)")
            case .finalResponse(let report):
                print("   ✅ Final Response: \(report.location) - \(report.conditions)")
                finalResult = report
            }
        }

        guard let result = finalResult else {
            throw AgentError.invalidState("No final response received")
        }
        return result
    }

    // Agent Test 2: 計算ツールを使ったエージェントループ
    await runAgentTest(name: "Calculator Agent Loop", runner: runner) {
        let tools = ToolSet {
            CalculatorTool()
        }

        let agentSequence: AgentStepSequence<OpenAIClient, CalculationReport> = client.runAgent(
            prompt: "Calculate 15 * 8 and create a calculation report",
            model: .gpt4oMini,
            tools: tools,
            systemPrompt: "You are a calculator assistant. Use the calculator tool to compute, then provide a structured report."
        )

        var finalResult: CalculationReport?

        for try await step in agentSequence {
            switch step {
            case .thinking:
                print("   💭 Thinking...")
            case .toolCall(let info):
                print("   🔧 Tool Call: \(info.name)")
            case .toolResult(let info):
                print("   📋 Tool Result: \(info.content)")
            case .finalResponse(let report):
                print("   ✅ Final Response: \(report.expression) = \(report.result)")
                finalResult = report
            }
        }

        guard let result = finalResult else {
            throw AgentError.invalidState("No final response received")
        }
        return result
    }
}

@MainActor
func runGeminiAgentTests(runner: TestRunner) async {
    print("\n" + String(repeating: "=", count: 60))
    print("🔵 GEMINI Agent Tests")
    print(String(repeating: "=", count: 60))

    // Note: Gemini API doesn't support function calling with JSON response mime type
    // This is an API limitation, not a library issue
    print("⚠️  Gemini API doesn't support agent loops with structured output")
    print("   (Function calling + JSON response mime type is unsupported)")
    await runner.recordSkip()
    return

    guard let apiKey = Config.geminiKey, !apiKey.isEmpty else {
        print("⚠️  GEMINI_API_KEY not set - skipping Gemini agent tests")
        await runner.recordSkip()
        return
    }

    let client = GeminiClient(apiKey: apiKey)

    // Agent Test 1: 天気ツールを使ったエージェントループ
    await runAgentTest(name: "Weather Agent Loop", runner: runner) {
        let tools = ToolSet {
            GetWeatherTool()
        }

        let agentSequence: AgentStepSequence<GeminiClient, WeatherReport> = client.runAgent(
            prompt: "パリの天気を調べて、天気レポートを作成してください",
            model: .flash25,
            tools: tools,
            systemPrompt: "You are a helpful weather assistant. Use the weather tool to get information, then create a structured report."
        )

        var finalResult: WeatherReport?

        for try await step in agentSequence {
            switch step {
            case .thinking:
                print("   💭 Thinking...")
            case .toolCall(let info):
                print("   🔧 Tool Call: \(info.name)")
            case .toolResult(let info):
                print("   📋 Tool Result: \(info.content)")
            case .finalResponse(let report):
                print("   ✅ Final Response: \(report.location) - \(report.conditions)")
                finalResult = report
            }
        }

        guard let result = finalResult else {
            throw AgentError.invalidState("No final response received")
        }
        return result
    }

    // Agent Test 2: 計算ツールを使ったエージェントループ
    await runAgentTest(name: "Calculator Agent Loop", runner: runner) {
        let tools = ToolSet {
            CalculatorTool()
        }

        let agentSequence: AgentStepSequence<GeminiClient, CalculationReport> = client.runAgent(
            prompt: "100 + 200 を計算して、結果をレポートにまとめてください",
            model: .flash25,
            tools: tools,
            systemPrompt: "You are a calculator assistant. Use the calculator tool to compute, then provide a structured report."
        )

        var finalResult: CalculationReport?

        for try await step in agentSequence {
            switch step {
            case .thinking:
                print("   💭 Thinking...")
            case .toolCall(let info):
                print("   🔧 Tool Call: \(info.name)")
            case .toolResult(let info):
                print("   📋 Tool Result: \(info.content)")
            case .finalResponse(let report):
                print("   ✅ Final Response: \(report.expression) = \(report.result)")
                finalResult = report
            }
        }

        guard let result = finalResult else {
            throw AgentError.invalidState("No final response received")
        }
        return result
    }
}

// MARK: - Main Entry Point

/// テストモード: "all" = 全テスト, "agent" = エージェントテストのみ, "basic" = 基本テストのみ
let testMode = ProcessInfo.processInfo.environment["TEST_MODE"] ?? "all"
let isAgentOnly = testMode == "agent"
let isBasicOnly = testMode == "basic"

let title = isAgentOnly ? "Agent Tests" : (isBasicOnly ? "Basic Tests" : "All Tests")

print("""

╔══════════════════════════════════════════════════════════════╗
║     LLMStructuredOutputs Integration Tests                   ║
║     Mode: \(title.padding(toLength: 46, withPad: " ", startingAt: 0)) ║
╚══════════════════════════════════════════════════════════════╝
""")

// Load .env file if present
Config.loadEnvFile()

// Check API keys
print("\n📋 API Key Status:")
print("   ANTHROPIC_API_KEY: \(Config.anthropicKey != nil ? "✅ Set" : "❌ Not set")")
print("   OPENAI_API_KEY:    \(Config.openAIKey != nil ? "✅ Set" : "❌ Not set")")
print("   GEMINI_API_KEY:    \(Config.geminiKey != nil ? "✅ Set" : "❌ Not set")")

let runner = TestRunner()

// Run test suites based on mode
if !isAgentOnly {
    // Basic tests (structured output, tool calling, etc.)
    await runAnthropicTests(runner: runner)
    await runOpenAITests(runner: runner)
    await runGeminiTests(runner: runner)
}

if !isBasicOnly {
    // Agent tests (runAgent loop)
    await runAnthropicAgentTests(runner: runner)
    await runOpenAIAgentTests(runner: runner)
    await runGeminiAgentTests(runner: runner)
}

// Print summary
let summary = await runner.summary()
print("\n" + String(repeating: "=", count: 60))
print("📊 TEST SUMMARY")
print(String(repeating: "=", count: 60))
print("   ✅ Passed:  \(summary.passed)")
print("   ❌ Failed:  \(summary.failed)")
print("   ⏭️  Skipped: \(summary.skipped)")
print(String(repeating: "=", count: 60))

if summary.failed > 0 {
    print("\n⚠️  Some tests failed. Check the output above for details.")
} else if summary.passed > 0 {
    print("\n🎉 All executed tests passed!")
} else {
    print("\n⚠️  No tests were executed. Set API keys to run tests.")
}
print("")
