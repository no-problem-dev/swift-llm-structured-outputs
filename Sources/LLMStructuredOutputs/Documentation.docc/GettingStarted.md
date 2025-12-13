# Getting Started

Learn how to add swift-llm-structured-outputs to your project and start generating structured outputs from LLMs.

## Overview

This guide walks you through the basic setup and usage of LLMStructuredOutputs.

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/no-problem-dev/swift-llm-structured-outputs.git",
        from: "1.0.0"
    )
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

## Defining Output Types

Use the `@Structured` macro to define types that can be used as structured output:

```swift
import LLMStructuredOutputs

@Structured("Information about a book")
struct BookInfo {
    @StructuredField("The book's title")
    var title: String

    @StructuredField("The author's name")
    var author: String

    @StructuredField("Publication year", .minimum(1000), .maximum(2100))
    var year: Int

    @StructuredField("Book genres")
    var genres: [String]
}
```

## Creating a Client

Choose a client based on your LLM provider:

```swift
// Anthropic Claude
let anthropic = AnthropicClient(apiKey: "sk-ant-...")

// OpenAI GPT
let openai = OpenAIClient(apiKey: "sk-...")

// Google Gemini
let gemini = GeminiClient(apiKey: "...")
```

## Generating Output

Call the `generate` method with your prompt:

```swift
let book: BookInfo = try await anthropic.generate(
    prompt: "Tell me about 1984 by George Orwell",
    model: .sonnet
)

print(book.title)   // "1984"
print(book.author)  // "George Orwell"
print(book.year)    // 1949
```

## Using Constraints

Add constraints to validate the LLM's output:

```swift
@Structured("Product listing")
struct Product {
    @StructuredField("Product name", .minLength(1), .maxLength(100))
    var name: String

    @StructuredField("Price in cents", .minimum(0))
    var price: Int

    @StructuredField("Quantity in stock", .minimum(0), .maximum(10000))
    var stock: Int

    @StructuredField("Product tags", .minItems(1), .maxItems(10))
    var tags: [String]
}
```

## Using Enums

For fixed choices, use `@StructuredEnum`:

```swift
@StructuredEnum("Sentiment analysis result")
enum Sentiment: String {
    @StructuredCase("The text expresses positive emotions")
    case positive

    @StructuredCase("The text is neutral")
    case neutral

    @StructuredCase("The text expresses negative emotions")
    case negative
}

@Structured("Analysis result")
struct Analysis {
    @StructuredField("Overall sentiment")
    var sentiment: Sentiment

    @StructuredField("Confidence score", .minimum(0), .maximum(100))
    var confidence: Int
}
```

## Error Handling

Handle potential errors gracefully:

```swift
do {
    let result: BookInfo = try await client.generate(
        prompt: "...",
        model: .sonnet
    )
} catch let error as LLMError {
    switch error {
    case .apiError(let message):
        print("API error: \(message)")
    case .decodingError(let message):
        print("Failed to decode: \(message)")
    case .invalidResponse:
        print("Invalid response")
    case .networkError(let underlying):
        print("Network error: \(underlying)")
    }
}
```

## Next Steps

- Learn about different <doc:Providers> and their models
- Explore <doc:Conversations> for multi-turn interactions
