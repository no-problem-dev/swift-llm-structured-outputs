# swift-llm-structured-outputs

Type-safe structured output generation for Swift LLM clients

🌐 English | **[日本語](README.md)**

[![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%2B%20%7C%20macOS%2014%2B-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/Documentation-DocC-blue.svg)](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/)

## Features

- **Type-safe Structured Outputs** - Automatic JSON Schema generation via Swift macros
- **Multi-provider Support** - Claude (Anthropic), GPT (OpenAI), and Gemini (Google)
- **Conversation Continuation** - State management and multi-turn conversations with `Conversation` class
- **Swift Concurrency** - Full async/await and Sendable support
- **Zero Dependencies** - Only swift-syntax required (for macro implementation)

## Quick Start

### 1. Define Your Structured Output Type

```swift
import LLMStructuredOutputs

@Structured("User information")
struct UserInfo {
    @StructuredField("Name")
    var name: String

    @StructuredField("Age", .minimum(0), .maximum(150))
    var age: Int

    @StructuredField("Email address", .format(.email))
    var email: String?
}
```

### 2. Get Structured Data from LLM

```swift
// Using Claude
let client = AnthropicClient(apiKey: "sk-ant-...")
let user: UserInfo = try await client.generate(
    prompt: "John Smith is 35 years old, email is john@example.com",
    model: .sonnet
)
print(user.name)  // "John Smith"
print(user.age)   // 35
```

### 3. Continue Conversations

```swift
var conversation = Conversation(
    client: client,
    model: .sonnet,
    systemPrompt: "You are a helpful assistant"
)

// First question
let cityInfo: CityInfo = try await conversation.send("What is the capital of Japan?")
print(cityInfo.name)  // "Tokyo"

// Continue conversation (context is maintained)
let population: PopulationInfo = try await conversation.send("What is its population?")
print(population.count)  // 13960000
```

## Installation

### Swift Package Manager

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-llm-structured-outputs.git", from: "1.0.0")
]
```

Add to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "LLMStructuredOutputs", package: "swift-llm-structured-outputs")
    ]
)
```

## Supported Providers

| Provider | Client | Model Examples |
|----------|--------|----------------|
| Anthropic | `AnthropicClient` | `.sonnet`, `.opus`, `.haiku` |
| OpenAI | `OpenAIClient` | `.gpt4o`, `.gpt4oMini`, `.o1` |
| Google | `GeminiClient` | `.pro25`, `.flash25`, `.flash25Lite` |

### Usage Examples

```swift
// Anthropic Claude
let anthropic = AnthropicClient(apiKey: "sk-ant-...")
let result: MyType = try await anthropic.generate(
    prompt: "...",
    model: .sonnet
)

// OpenAI GPT
let openai = OpenAIClient(apiKey: "sk-...")
let result: MyType = try await openai.generate(
    prompt: "...",
    model: .gpt4o
)

// Google Gemini
let gemini = GeminiClient(apiKey: "...")
let result: MyType = try await gemini.generate(
    prompt: "...",
    model: .flash25
)
```

## Macros

### @Structured

Makes a struct compatible with structured outputs.

```swift
@Structured("Product information")
struct Product {
    @StructuredField("Product name")
    var name: String

    @StructuredField("Price", .minimum(0))
    var price: Int
}
```

### @StructuredField

Adds description and constraints to fields.

**Available Constraints:**

| Constraint | Description | Example |
|------------|-------------|---------|
| `.minimum(n)` | Minimum value | `.minimum(0)` |
| `.maximum(n)` | Maximum value | `.maximum(100)` |
| `.minLength(n)` | Minimum string length | `.minLength(1)` |
| `.maxLength(n)` | Maximum string length | `.maxLength(100)` |
| `.minItems(n)` | Minimum array items | `.minItems(1)` |
| `.maxItems(n)` | Maximum array items | `.maxItems(10)` |
| `.pattern(regex)` | Regex pattern | `.pattern("^[A-Z]+$")` |
| `.format(type)` | Format type | `.format(.email)` |
| `.enum([...])` | Enumerated values | `.enum(["a", "b"])` |

### @StructuredEnum

Makes a String-based enum compatible with structured outputs.

```swift
@StructuredEnum("Priority level")
enum Priority: String {
    @StructuredCase("Urgent task")
    case high

    @StructuredCase("Normal task")
    case medium

    @StructuredCase("Can be postponed")
    case low
}
```

## Conversation Continuation

Use the `Conversation` class to manage multi-turn conversations.

```swift
var conversation = Conversation(
    client: AnthropicClient(apiKey: "..."),
    model: .sonnet,
    systemPrompt: "You are a cooking expert"
)

// Sequential questions (context is maintained)
let recipe: Recipe = try await conversation.send("How do I make pasta?")
let tips: CookingTips = try await conversation.send("Any tips for beginners?")

// Check usage
print("Turns: \(conversation.turnCount)")
print("Total tokens: \(conversation.totalUsage.totalTokens)")

// Reset conversation
conversation.clear()
```

## Requirements

- Swift 6.0+
- iOS 17.0+ / macOS 14.0+

## Example App

An iOS example app is included in `Examples/LLMStructuredOutputsExample`. Try all features interactively.

### Demo List

| Demo | Features to Verify |
|------|-------------------|
| Basic Structured Output | `@Structured` type definition, `generate()` output |
| Field Constraints | `.minimum()`, `.maximum()`, `.pattern()` constraints |
| Enum Support | `@StructuredEnum` enum output |
| Conversation | `Conversation` multi-turn conversations |
| Event Stream | `chatStream()` streaming responses |
| Prompt DSL | `Prompt { }` builder for prompt construction |
| **Provider Comparison** | Claude/GPT/Gemini parallel comparison, response time & token measurement |

### Provider Comparison Demo

Compare structured output quality across 3 major providers:

- **Model Selection**: Select models individually for each provider
- **Test Cases**: 5 categories, 14 types (extraction, reasoning, structure, quality, language)
- **Custom Input**: Run comparison tests with any prompt
- **Metrics**: Response time, token usage, output JSON

```bash
# Open the example app
open Examples/LLMStructuredOutputsExample/LLMStructuredOutputsExample.xcodeproj
```

## Documentation

For detailed documentation, see:

- [API Reference](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/)
- [Guides](documentation/)
  - [Getting Started](documentation/getting-started.md)
  - [Providers](documentation/providers.md)
  - [Conversation](documentation/conversation.md)

## License

MIT License - See [LICENSE](LICENSE) for details.

## Author

NOPROBLEM
