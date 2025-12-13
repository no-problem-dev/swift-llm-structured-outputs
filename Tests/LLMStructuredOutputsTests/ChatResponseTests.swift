import XCTest
@testable import LLMStructuredOutputs

/// ChatResponse と会話継続機能のテスト
final class ChatResponseTests: XCTestCase {

    // MARK: - Test Types

    /// テスト用の構造化出力型
    struct CityInfo: StructuredProtocol, Equatable {
        let name: String
        let country: String

        static var jsonSchema: JSONSchema {
            .object(
                description: "City information",
                properties: [
                    "name": .string(description: "City name"),
                    "country": .string(description: "Country name")
                ],
                required: ["name", "country"]
            )
        }
    }

    struct PopulationInfo: StructuredProtocol, Equatable {
        let count: Int

        static var jsonSchema: JSONSchema {
            .object(
                description: "Population information",
                properties: [
                    "count": .integer(description: "Population count")
                ],
                required: ["count"]
            )
        }
    }

    // MARK: - ChatResponse Tests

    func testChatResponseInit() {
        let cityInfo = CityInfo(name: "Tokyo", country: "Japan")
        let rawText = """
        {"name": "Tokyo", "country": "Japan"}
        """

        let response = ChatResponse(
            result: cityInfo,
            assistantMessage: .assistant(rawText),
            usage: TokenUsage(inputTokens: 10, outputTokens: 5),
            stopReason: .endTurn,
            model: "claude-sonnet-4-5-20250929",
            rawText: rawText
        )

        XCTAssertEqual(response.result.name, "Tokyo")
        XCTAssertEqual(response.result.country, "Japan")
        XCTAssertEqual(response.assistantMessage.role, .assistant)
        XCTAssertEqual(response.assistantMessage.content, rawText)
        XCTAssertEqual(response.usage.inputTokens, 10)
        XCTAssertEqual(response.usage.outputTokens, 5)
        XCTAssertEqual(response.stopReason, .endTurn)
        XCTAssertEqual(response.model, "claude-sonnet-4-5-20250929")
        XCTAssertEqual(response.rawText, rawText)
    }

    func testChatResponseWithNilStopReason() {
        let cityInfo = CityInfo(name: "Tokyo", country: "Japan")
        let rawText = """
        {"name": "Tokyo", "country": "Japan"}
        """

        let response = ChatResponse(
            result: cityInfo,
            assistantMessage: .assistant(rawText),
            usage: TokenUsage(inputTokens: 10, outputTokens: 5),
            stopReason: nil,
            model: "gpt-4o",
            rawText: rawText
        )

        XCTAssertNil(response.stopReason)
    }

    // MARK: - Conversation Tests

    func testConversationInit() {
        let client = AnthropicClient(apiKey: "test-key")
        let conv = Conversation(
            client: client,
            model: .sonnet,
            systemPrompt: "You are helpful",
            temperature: 0.7,
            maxTokens: 1000
        )

        XCTAssertTrue(conv.messages.isEmpty)
        XCTAssertEqual(conv.totalUsage.inputTokens, 0)
        XCTAssertEqual(conv.totalUsage.outputTokens, 0)
        XCTAssertEqual(conv.turnCount, 0)
    }

    func testConversationInitWithExistingMessages() {
        let client = OpenAIClient(apiKey: "test-key")
        let existingMessages: [LLMMessage] = [
            .user("Hello"),
            .assistant("Hi there!")
        ]

        let conv = Conversation(
            client: client,
            model: .gpt4o,
            messages: existingMessages
        )

        XCTAssertEqual(conv.messages.count, 2)
        XCTAssertEqual(conv.turnCount, 1)
    }

    func testConversationClear() {
        let client = GeminiClient(apiKey: "test-key")
        var conv = Conversation(
            client: client,
            model: .flash25,
            messages: [
                .user("Test"),
                .assistant("Response")
            ]
        )

        // Manually set some usage for testing
        // (In real usage, this would be set by send())
        XCTAssertEqual(conv.messages.count, 2)

        conv.clear()

        XCTAssertTrue(conv.messages.isEmpty)
        XCTAssertEqual(conv.totalUsage.inputTokens, 0)
        XCTAssertEqual(conv.totalUsage.outputTokens, 0)
        XCTAssertEqual(conv.turnCount, 0)
    }

    func testConversationTurnCount() {
        let client = AnthropicClient(apiKey: "test-key")
        let conv = Conversation(
            client: client,
            model: .sonnet,
            messages: [
                .user("Q1"),
                .assistant("A1"),
                .user("Q2"),
                .assistant("A2"),
                .user("Q3"),
                .assistant("A3")
            ]
        )

        XCTAssertEqual(conv.turnCount, 3)
    }

    // MARK: - LLMMessage Helper Tests

    func testAssistantMessageCreation() {
        let message = LLMMessage.assistant("Hello from assistant")
        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, "Hello from assistant")
    }

    func testUserMessageCreation() {
        let message = LLMMessage.user("Hello from user")
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Hello from user")
    }

    // MARK: - Type Safety Tests

    func testConversationWithAnthropicClient() {
        let client = AnthropicClient(apiKey: "test-key")
        let conv = Conversation(client: client, model: .sonnet)
        // This compiles - ClaudeModel is correct
        _ = conv
    }

    func testConversationWithOpenAIClient() {
        let client = OpenAIClient(apiKey: "test-key")
        let conv = Conversation(client: client, model: .gpt4o)
        // This compiles - GPTModel is correct
        _ = conv
    }

    func testConversationWithGeminiClient() {
        let client = GeminiClient(apiKey: "test-key")
        let conv = Conversation(client: client, model: .flash25)
        // This compiles - GeminiModel is correct
        _ = conv
    }

    // MARK: - Protocol Conformance Tests

    func testChatResponseIsSendable() {
        // Verify ChatResponse conforms to Sendable
        func takeSendable<T: Sendable>(_ value: T) {}

        let response = ChatResponse(
            result: CityInfo(name: "Tokyo", country: "Japan"),
            assistantMessage: .assistant("{}"),
            usage: TokenUsage(inputTokens: 0, outputTokens: 0),
            stopReason: nil,
            model: "test",
            rawText: "{}"
        )

        takeSendable(response)
    }

    func testConversationIsSendable() {
        // Verify Conversation conforms to Sendable
        func takeSendable<T: Sendable>(_ value: T) {}

        let client = AnthropicClient(apiKey: "test-key")
        let conv = Conversation(client: client, model: .sonnet)

        takeSendable(conv)
    }

    // MARK: - TokenUsage Accumulation Tests

    func testTokenUsageAccumulation() {
        // Test that TokenUsage can be accumulated correctly
        let usage1 = TokenUsage(inputTokens: 100, outputTokens: 50)
        let usage2 = TokenUsage(inputTokens: 80, outputTokens: 40)

        let accumulated = TokenUsage(
            inputTokens: usage1.inputTokens + usage2.inputTokens,
            outputTokens: usage1.outputTokens + usage2.outputTokens
        )

        XCTAssertEqual(accumulated.inputTokens, 180)
        XCTAssertEqual(accumulated.outputTokens, 90)
        XCTAssertEqual(accumulated.totalTokens, 270)
    }
}
