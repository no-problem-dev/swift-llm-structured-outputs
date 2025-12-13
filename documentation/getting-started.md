# Getting Started

This guide will help you get started with swift-llm-structured-outputs.

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-llm-structured-outputs.git", from: "1.0.0")
]
```

Then add `LLMStructuredOutputs` to your target's dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "LLMStructuredOutputs", package: "swift-llm-structured-outputs")
    ]
)
```

## Basic Usage

### 1. Define Your Output Type

Use the `@Structured` macro to define a type that can be used as structured output:

```swift
import LLMStructuredOutputs

@Structured("Information about a person")
struct PersonInfo {
    @StructuredField("The person's full name")
    var name: String

    @StructuredField("The person's age", .minimum(0), .maximum(150))
    var age: Int

    @StructuredField("The person's email address", .format(.email))
    var email: String?
}
```

### 2. Create a Client

Choose a client based on your LLM provider:

```swift
// For Anthropic Claude
let client = AnthropicClient(apiKey: "your-api-key")

// For OpenAI GPT
let client = OpenAIClient(apiKey: "your-api-key")

// For Google Gemini
let client = GeminiClient(apiKey: "your-api-key")
```

### 3. Generate Structured Output

Use the `generate` method to get structured output from the LLM:

```swift
let person: PersonInfo = try await client.generate(
    prompt: "John Smith is 35 years old, his email is john@example.com",
    model: .sonnet  // or .gpt4o, .flash25, etc.
)

print(person.name)   // "John Smith"
print(person.age)    // 35
print(person.email)  // Optional("john@example.com")
```

## Adding Constraints

The `@StructuredField` macro supports various constraints:

### Numeric Constraints

```swift
@Structured
struct Product {
    @StructuredField("Price in cents", .minimum(0))
    var price: Int

    @StructuredField("Discount percentage", .minimum(0), .maximum(100))
    var discount: Int
}
```

### String Constraints

```swift
@Structured
struct User {
    @StructuredField("Username", .minLength(3), .maxLength(20))
    var username: String

    @StructuredField("Phone number", .pattern("^\\d{3}-\\d{4}-\\d{4}$"))
    var phone: String
}
```

### Array Constraints

```swift
@Structured
struct Order {
    @StructuredField("Order items", .minItems(1), .maxItems(100))
    var items: [String]
}
```

### Format Constraints

```swift
@Structured
struct Contact {
    @StructuredField("Email", .format(.email))
    var email: String

    @StructuredField("Website", .format(.uri))
    var website: String?
}
```

## Using Enums

Use `@StructuredEnum` for enum types:

```swift
@StructuredEnum("Task priority level")
enum Priority: String {
    @StructuredCase("Urgent, needs immediate attention")
    case high

    @StructuredCase("Normal priority")
    case medium

    @StructuredCase("Can be done later")
    case low
}

@Structured("A task item")
struct Task {
    @StructuredField("Task title")
    var title: String

    @StructuredField("Priority level")
    var priority: Priority
}
```

## Next Steps

- Learn about [Providers](providers.md) in detail
- Explore [Conversation](conversation.md) for multi-turn interactions
- Check the [API Reference](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/) for complete documentation
