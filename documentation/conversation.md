# Conversation

The `Conversation` class provides a convenient way to manage multi-turn conversations with LLMs while maintaining type-safe structured outputs.

## Basic Usage

### Creating a Conversation

```swift
import LLMStructuredOutputs

let client = AnthropicClient(apiKey: "sk-ant-...")

var conversation = Conversation(
    client: client,
    model: .sonnet,
    systemPrompt: "You are a helpful cooking assistant"
)
```

### Sending Messages

Use the `send` method to send messages and receive structured responses:

```swift
@Structured("Recipe information")
struct Recipe {
    @StructuredField("Recipe name")
    var name: String

    @StructuredField("List of ingredients")
    var ingredients: [String]

    @StructuredField("Cooking instructions")
    var instructions: [String]
}

// First message
let recipe: Recipe = try await conversation.send("How do I make pasta carbonara?")
print(recipe.name)  // "Pasta Carbonara"

// Follow-up question (context is maintained)
@Structured("Cooking tips")
struct CookingTips {
    @StructuredField("List of tips")
    var tips: [String]
}

let tips: CookingTips = try await conversation.send("Any tips for a beginner?")
```

## Conversation State

### Tracking Messages

```swift
// Get all messages in the conversation
let messages = conversation.messages

// Get the number of turns (user-assistant pairs)
let turns = conversation.turnCount
```

### Token Usage

```swift
// Track total token usage across all turns
let totalUsage = conversation.totalUsage
print("Input tokens: \(totalUsage.inputTokens)")
print("Output tokens: \(totalUsage.outputTokens)")
print("Total tokens: \(totalUsage.totalTokens)")
```

### Clearing Conversation

```swift
// Reset the conversation to start fresh
conversation.clear()
```

## Starting with Existing Messages

You can initialize a conversation with existing message history:

```swift
let existingMessages: [LLMMessage] = [
    .user("What's the capital of France?"),
    .assistant("{\"name\": \"Paris\", \"country\": \"France\"}")
]

var conversation = Conversation(
    client: client,
    model: .sonnet,
    messages: existingMessages
)
```

## Using Different Output Types

Each message in a conversation can return a different structured type:

```swift
@Structured
struct CityInfo {
    var name: String
    var country: String
}

@Structured
struct PopulationInfo {
    var population: Int
    var year: Int
}

@Structured
struct WeatherInfo {
    var temperature: Double
    var condition: String
}

// Same conversation, different response types
let city: CityInfo = try await conversation.send("What's the capital of Japan?")
let population: PopulationInfo = try await conversation.send("What's its population?")
let weather: WeatherInfo = try await conversation.send("What's the weather like there?")
```

## Low-Level Chat API

For more control, you can use the `chat` methods directly on the client:

```swift
var messages: [LLMMessage] = []

// First turn
messages.append(.user("What is 2 + 2?"))
let response1: ChatResponse<MathAnswer> = try await client.chat(
    messages: messages,
    model: .sonnet
)
messages.append(response1.assistantMessage)

// Second turn
messages.append(.user("Now multiply that by 3"))
let response2: ChatResponse<MathAnswer> = try await client.chat(
    messages: messages,
    model: .sonnet
)
```

### ChatResponse Properties

```swift
let response: ChatResponse<MyType> = try await client.chat(...)

// The structured result
let result = response.result

// The assistant's raw message (for adding to history)
let assistantMessage = response.assistantMessage

// Token usage for this turn
let usage = response.usage

// Why the response ended
let stopReason = response.stopReason

// The model that was used
let model = response.model

// Raw text before parsing
let rawText = response.rawText
```

## Configuration Options

### Temperature

Control response randomness:

```swift
var conversation = Conversation(
    client: client,
    model: .sonnet,
    temperature: 0.7  // 0.0 = deterministic, 1.0 = creative
)
```

### Max Tokens

Limit response length:

```swift
var conversation = Conversation(
    client: client,
    model: .sonnet,
    maxTokens: 500
)
```

## Type Safety

The `Conversation` class is generic over the client type, ensuring model compatibility:

```swift
// Using Anthropic client - only ClaudeModel allowed
var anthropicConv = Conversation(
    client: AnthropicClient(apiKey: "..."),
    model: .sonnet  // ✅ ClaudeModel
)

// Using OpenAI client - only GPTModel allowed
var openaiConv = Conversation(
    client: OpenAIClient(apiKey: "..."),
    model: .gpt4o  // ✅ GPTModel
)

// Using Gemini client - only GeminiModel allowed
var geminiConv = Conversation(
    client: GeminiClient(apiKey: "..."),
    model: .flash25  // ✅ GeminiModel
)
```

## Concurrency

`Conversation` is `Sendable` and can be safely used across async contexts:

```swift
let conversation = Conversation(
    client: client,
    model: .sonnet
)

// Safe to use in concurrent contexts
Task {
    var conv = conversation
    let result: MyType = try await conv.send("Hello")
}
```

## Best Practices

1. **Reuse conversations** for related questions to maintain context
2. **Clear conversations** when starting a new topic
3. **Monitor token usage** for cost management
4. **Use appropriate models** based on task complexity
5. **Handle errors** gracefully with do-catch blocks

## Next Steps

- Check the [Providers](providers.md) guide for provider-specific details
- See [Getting Started](getting-started.md) for basic setup
- Browse the [API Reference](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/) for complete documentation
