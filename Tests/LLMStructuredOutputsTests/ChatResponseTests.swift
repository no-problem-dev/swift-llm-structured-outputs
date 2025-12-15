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

    // MARK: - ConversationHistory Tests

    func testConversationHistoryInit() async {
        let history = ConversationHistory()

        let messages = await history.getMessages()
        let totalUsage = await history.getTotalUsage()
        let turnCount = await history.turnCount

        XCTAssertTrue(messages.isEmpty)
        XCTAssertEqual(totalUsage.inputTokens, 0)
        XCTAssertEqual(totalUsage.outputTokens, 0)
        XCTAssertEqual(turnCount, 0)
    }

    func testConversationHistoryInitWithExistingMessages() async {
        let existingMessages: [LLMMessage] = [
            .user("Hello"),
            .assistant("Hi there!")
        ]

        let history = ConversationHistory(messages: existingMessages)

        let messages = await history.getMessages()
        let turnCount = await history.turnCount

        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(turnCount, 1)
    }

    func testConversationHistoryInitWithMessagesAndUsage() async {
        let existingMessages: [LLMMessage] = [
            .user("Hello"),
            .assistant("Hi!")
        ]
        let existingUsage = TokenUsage(inputTokens: 100, outputTokens: 50)

        let history = ConversationHistory(
            messages: existingMessages,
            totalUsage: existingUsage
        )

        let totalUsage = await history.getTotalUsage()
        XCTAssertEqual(totalUsage.inputTokens, 100)
        XCTAssertEqual(totalUsage.outputTokens, 50)
    }

    func testConversationHistoryClear() async {
        let history = ConversationHistory(
            messages: [
                .user("Test"),
                .assistant("Response")
            ]
        )

        // Verify initial state
        let initialMessages = await history.getMessages()
        XCTAssertEqual(initialMessages.count, 2)

        await history.clear()

        let messages = await history.getMessages()
        let totalUsage = await history.getTotalUsage()
        let turnCount = await history.turnCount

        XCTAssertTrue(messages.isEmpty)
        XCTAssertEqual(totalUsage.inputTokens, 0)
        XCTAssertEqual(totalUsage.outputTokens, 0)
        XCTAssertEqual(turnCount, 0)
    }

    func testConversationHistoryTurnCount() async {
        let history = ConversationHistory(
            messages: [
                .user("Q1"),
                .assistant("A1"),
                .user("Q2"),
                .assistant("A2"),
                .user("Q3"),
                .assistant("A3")
            ]
        )

        let turnCount = await history.turnCount
        XCTAssertEqual(turnCount, 3)
    }

    func testConversationHistoryAppend() async {
        let history = ConversationHistory()

        await history.append(.user("Hello"))
        await history.append(.assistant("Hi!"))

        let messages = await history.getMessages()
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, .user)
        XCTAssertEqual(messages[1].role, .assistant)
    }

    func testConversationHistoryAddUsage() async {
        let history = ConversationHistory()

        await history.addUsage(TokenUsage(inputTokens: 100, outputTokens: 50))
        await history.addUsage(TokenUsage(inputTokens: 80, outputTokens: 40))

        let totalUsage = await history.getTotalUsage()
        XCTAssertEqual(totalUsage.inputTokens, 180)
        XCTAssertEqual(totalUsage.outputTokens, 90)
        XCTAssertEqual(totalUsage.totalTokens, 270)
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

    func testConversationHistoryIsSendable() {
        // Verify ConversationHistory conforms to Sendable
        func takeSendable<T: Sendable>(_ value: T) {}

        let history = ConversationHistory()
        takeSendable(history)
    }

    func testConversationHistoryConformsToProtocol() {
        // Verify ConversationHistory conforms to ConversationHistoryProtocol
        func takeProtocol<T: ConversationHistoryProtocol>(_ value: T) {}

        let history = ConversationHistory()
        takeProtocol(history)
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

    func testConversationEventUsageUpdated() {
        let usage = TokenUsage(inputTokens: 100, outputTokens: 50)
        let event = ConversationEvent.usageUpdated(usage)

        if case .usageUpdated(let u) = event {
            XCTAssertEqual(u.inputTokens, 100)
            XCTAssertEqual(u.outputTokens, 50)
        } else {
            XCTFail("Expected usageUpdated event")
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

    func testConversationEventError() {
        let error = LLMError.networkError(URLError(.badServerResponse))
        let event = ConversationEvent.error(error)

        if case .error(let e) = event {
            if case .networkError = e {
                // Success
            } else {
                XCTFail("Expected networkError")
            }
        } else {
            XCTFail("Expected error event")
        }
    }

    func testConversationEventIsSendable() {
        func takeSendable<T: Sendable>(_ value: T) {}

        let event = ConversationEvent.userMessage(.user("Test"))
        takeSendable(event)
    }

    // MARK: - Event Stream Tests

    func testEventStreamCanBeCreated() async {
        let history = ConversationHistory()

        // Verify eventStream is an AsyncStream
        let stream = history.eventStream
        _ = stream  // Type check passes
    }

    func testEventStreamReceivesClearedEvent() async {
        let history = ConversationHistory(
            messages: [.user("Initial"), .assistant("Response")]
        )

        // Use actor to safely collect events
        let collector = EventCollector()

        // Start monitoring events
        let monitorTask = Task {
            for await event in history.eventStream {
                await collector.append(event)
                // Stop after receiving cleared event
                if case .cleared = event {
                    break
                }
            }
        }

        // Give the stream time to set up
        try? await Task.sleep(nanoseconds: 10_000_000)

        // Clear the history - this should emit a cleared event
        await history.clear()

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

    func testEventStreamReceivesMessageEvents() async {
        let history = ConversationHistory()

        let collector = EventCollector()

        let monitorTask = Task {
            var count = 0
            for await event in history.eventStream {
                await collector.append(event)
                count += 1
                if count >= 2 {
                    break
                }
            }
        }

        // Give the stream time to set up
        try? await Task.sleep(nanoseconds: 10_000_000)

        // Add messages
        await history.append(.user("Hello"))
        await history.append(.assistant("Hi!"))

        // Wait for the monitor task
        await monitorTask.value

        let events = await collector.events
        XCTAssertEqual(events.count, 2)

        if case .userMessage(let msg) = events[0] {
            XCTAssertEqual(msg.content, "Hello")
        } else {
            XCTFail("Expected userMessage event")
        }

        if case .assistantMessage(let msg) = events[1] {
            XCTAssertEqual(msg.content, "Hi!")
        } else {
            XCTFail("Expected assistantMessage event")
        }
    }

    func testEventStreamReceivesUsageUpdatedEvent() async {
        let history = ConversationHistory()

        let collector = EventCollector()

        let monitorTask = Task {
            for await event in history.eventStream {
                await collector.append(event)
                if case .usageUpdated = event { break }
            }
        }

        // Give the stream time to set up
        try? await Task.sleep(nanoseconds: 10_000_000)

        // Add usage
        await history.addUsage(TokenUsage(inputTokens: 100, outputTokens: 50))

        // Wait for the monitor task
        await monitorTask.value

        let events = await collector.events
        XCTAssertEqual(events.count, 1)

        if case .usageUpdated(let usage) = events[0] {
            XCTAssertEqual(usage.totalTokens, 150)
        } else {
            XCTFail("Expected usageUpdated event")
        }
    }

    func testEventStreamReceivesErrorEvent() async {
        let history = ConversationHistory()

        let collector = EventCollector()

        let monitorTask = Task {
            for await event in history.eventStream {
                await collector.append(event)
                if case .error = event { break }
            }
        }

        // Give the stream time to set up
        try? await Task.sleep(nanoseconds: 10_000_000)

        // Emit error
        let error = LLMError.serverError(500, "Internal Server Error")
        await history.emitError(error)

        // Wait for the monitor task
        await monitorTask.value

        let events = await collector.events
        XCTAssertEqual(events.count, 1)

        if case .error(let e) = events[0] {
            if case .serverError(let statusCode, let message) = e {
                XCTAssertEqual(statusCode, 500)
                XCTAssertEqual(message, "Internal Server Error")
            } else {
                XCTFail("Expected serverError")
            }
        } else {
            XCTFail("Expected error event")
        }
    }

    func testEmitErrorMethod() async {
        let history = ConversationHistory()

        // emitError should not affect messages or usage
        let error = LLMError.networkError(URLError(.notConnectedToInternet))
        await history.emitError(error)

        let messages = await history.getMessages()
        let usage = await history.getTotalUsage()

        XCTAssertTrue(messages.isEmpty)
        XCTAssertEqual(usage.totalTokens, 0)
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
