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

    func testConversationInit() async {
        let client = AnthropicClient(apiKey: "test-key")
        let conv = Conversation(
            client: client,
            model: .sonnet,
            systemPrompt: "You are helpful",
            temperature: 0.7,
            maxTokens: 1000
        )

        let messages = await conv.messages
        let totalUsage = await conv.totalUsage
        let turnCount = await conv.turnCount

        XCTAssertTrue(messages.isEmpty)
        XCTAssertEqual(totalUsage.inputTokens, 0)
        XCTAssertEqual(totalUsage.outputTokens, 0)
        XCTAssertEqual(turnCount, 0)
    }

    func testConversationInitWithExistingMessages() async {
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

        let messages = await conv.messages
        let turnCount = await conv.turnCount

        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(turnCount, 1)
    }

    func testConversationClear() async {
        let client = GeminiClient(apiKey: "test-key")
        let conv = Conversation(
            client: client,
            model: .flash25,
            messages: [
                .user("Test"),
                .assistant("Response")
            ]
        )

        // Verify initial state
        let initialMessages = await conv.messages
        XCTAssertEqual(initialMessages.count, 2)

        await conv.clear()

        let messages = await conv.messages
        let totalUsage = await conv.totalUsage
        let turnCount = await conv.turnCount

        XCTAssertTrue(messages.isEmpty)
        XCTAssertEqual(totalUsage.inputTokens, 0)
        XCTAssertEqual(totalUsage.outputTokens, 0)
        XCTAssertEqual(turnCount, 0)
    }

    func testConversationTurnCount() async {
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

        let turnCount = await conv.turnCount
        XCTAssertEqual(turnCount, 3)
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

    // MARK: - ConversationEvent Tests

    func testConversationEventUserMessage() {
        let message = LLMMessage.user("Hello")
        let event = ConversationEvent.userMessage(message)

        if case .userMessage(let msg) = event {
            XCTAssertEqual(msg.role, .user)
            XCTAssertEqual(msg.content, "Hello")
        } else {
            XCTFail("Expected userMessage event")
        }
    }

    func testConversationEventAssistantMessage() {
        let message = LLMMessage.assistant("Hi there!")
        let event = ConversationEvent.assistantMessage(message)

        if case .assistantMessage(let msg) = event {
            XCTAssertEqual(msg.role, .assistant)
            XCTAssertEqual(msg.content, "Hi there!")
        } else {
            XCTFail("Expected assistantMessage event")
        }
    }

    func testConversationEventError() {
        let error = ConversationError.alreadySending
        let event = ConversationEvent.error(error)

        if case .error(let err) = event {
            XCTAssertTrue(err is ConversationError)
        } else {
            XCTFail("Expected error event")
        }
    }

    func testConversationEventCleared() {
        let event = ConversationEvent.cleared

        if case .cleared = event {
            // Success
        } else {
            XCTFail("Expected cleared event")
        }
    }

    func testConversationEventIsSendable() {
        func takeSendable<T: Sendable>(_ value: T) {}

        let event = ConversationEvent.userMessage(.user("Test"))
        takeSendable(event)
    }

    // MARK: - Event Stream Tests

    func testEventStreamCanBeCreated() async {
        let client = AnthropicClient(apiKey: "test-key")
        let conv = Conversation(client: client, model: .sonnet)

        // Verify eventStream returns an AsyncStream
        let stream = await conv.eventStream
        _ = stream  // Type check passes
    }

    func testEventStreamReceivesClearedEvent() async {
        let client = AnthropicClient(apiKey: "test-key")
        let conv = Conversation(
            client: client,
            model: .sonnet,
            messages: [.user("Initial"), .assistant("Response")]
        )

        // Use actor to safely collect events
        let collector = EventCollector()

        // Start monitoring events
        let monitorTask = Task {
            for await event in await conv.eventStream {
                await collector.append(event)
                // Stop after receiving cleared event
                if case .cleared = event {
                    break
                }
            }
        }

        // Give the stream time to set up
        try? await Task.sleep(nanoseconds: 10_000_000)

        // Clear the conversation - this should emit a cleared event
        await conv.clear()

        // Wait for the monitor task to complete
        await monitorTask.value

        let events = await collector.events
        XCTAssertEqual(events.count, 1)
        if case .cleared = events.first {
            // Success
        } else {
            XCTFail("Expected cleared event")
        }
    }

    func testNewEventStreamTerminatesPrevious() async {
        let client = AnthropicClient(apiKey: "test-key")
        let conv = Conversation(client: client, model: .sonnet)

        let termination = TerminationTracker()

        // Start first stream
        let firstTask = Task {
            for await _ in await conv.eventStream {
                // This loop should terminate when a new stream is created
            }
            await termination.markTerminated()
        }

        // Give the first stream time to set up
        try? await Task.sleep(nanoseconds: 10_000_000)

        // Create a new stream - this should terminate the first one
        _ = await conv.eventStream

        // Wait for the first task to complete
        try? await Task.sleep(nanoseconds: 50_000_000)

        let isTerminated = await termination.isTerminated
        XCTAssertTrue(isTerminated)
        firstTask.cancel()
    }
}

// MARK: - Test Helpers

/// Thread-safe event collector for tests
private actor EventCollector {
    var events: [ConversationEvent] = []

    func append(_ event: ConversationEvent) {
        events.append(event)
    }
}

/// Thread-safe termination tracker for tests
private actor TerminationTracker {
    var isTerminated = false

    func markTerminated() {
        isTerminated = true
    }
}
