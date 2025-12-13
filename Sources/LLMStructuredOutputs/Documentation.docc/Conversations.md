# Conversations

Learn how to manage multi-turn conversations with structured outputs.

## Overview

The ``Conversation`` class provides a convenient way to maintain context across multiple LLM interactions while still receiving type-safe structured outputs.

## Creating a Conversation

```swift
var conversation = Conversation(
    client: AnthropicClient(apiKey: "..."),
    model: .sonnet,
    systemPrompt: "You are a helpful assistant"
)
```

## Sending Messages

Use the `send` method to exchange messages:

```swift
@Structured
struct CityInfo {
    var name: String
    var country: String
}

@Structured
struct PopulationInfo {
    var population: Int
}

// First turn
let city: CityInfo = try await conversation.send("What's the capital of Japan?")
print(city.name)  // "Tokyo"

// Second turn - context is maintained
let pop: PopulationInfo = try await conversation.send("What's its population?")
print(pop.population)  // 13960000
```

## Tracking State

### Message History

```swift
// Access all messages
let messages = conversation.messages
print("Total messages: \(messages.count)")

// Number of complete turns
let turns = conversation.turnCount
```

### Token Usage

```swift
let usage = conversation.totalUsage
print("Input tokens: \(usage.inputTokens)")
print("Output tokens: \(usage.outputTokens)")
print("Total: \(usage.totalTokens)")
```

## Resetting Conversations

Clear the conversation to start fresh:

```swift
conversation.clear()
```

## Low-Level API

For more control, use ``ChatResponse`` directly:

```swift
var messages: [LLMMessage] = []
messages.append(.user("Hello"))

let response: ChatResponse<Greeting> = try await client.chat(
    messages: messages,
    model: .sonnet
)

// Add assistant response to history
messages.append(response.assistantMessage)

// Continue the conversation
messages.append(.user("How are you?"))
```

### ChatResponse Properties

| Property | Type | Description |
|----------|------|-------------|
| `result` | `T` | Structured output |
| `assistantMessage` | `LLMMessage` | For history |
| `usage` | `TokenUsage` | Token counts |
| `stopReason` | `StopReason?` | Why response ended |
| `model` | `String` | Model used |
| `rawText` | `String` | Raw response |

## Configuration

### Temperature

```swift
var conversation = Conversation(
    client: client,
    model: .sonnet,
    temperature: 0.7  // 0.0 = deterministic, 1.0 = creative
)
```

### Max Tokens

```swift
var conversation = Conversation(
    client: client,
    model: .sonnet,
    maxTokens: 500
)
```

## Concurrency

``Conversation`` is `Sendable` and safe for async use:

```swift
Task {
    var conv = conversation
    let result: MyType = try await conv.send("Hello")
}
```
