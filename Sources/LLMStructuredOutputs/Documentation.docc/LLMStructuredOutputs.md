# ``LLMStructuredOutputs``

Type-safe structured output generation for Swift LLM clients.

## Overview

LLMStructuredOutputs is a Swift library that enables type-safe structured output generation from Large Language Models. Using Swift macros, you can define your output types with full validation constraints, and the library will automatically generate JSON Schema and handle responses from multiple LLM providers.

### Key Features

- **Type-safe structured outputs** using Swift macros
- **Multi-provider support**: Claude (Anthropic), GPT (OpenAI), and Gemini (Google)
- **Conversation management** for multi-turn interactions
- **Full Swift Concurrency support** with async/await
- **Zero dependencies** beyond swift-syntax

## Quick Start

Define your output type:

```swift
@Structured("User information")
struct UserInfo {
    @StructuredField("Name")
    var name: String

    @StructuredField("Age", .minimum(0))
    var age: Int
}
```

Generate structured output:

```swift
let client = AnthropicClient(apiKey: "sk-ant-...")
let user: UserInfo = try await client.generate(
    prompt: "John is 30 years old",
    model: .sonnet
)
```

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Providers>
- <doc:Conversations>

### Macros

- ``Structured(_:)``
- ``StructuredField(_:_:)``
- ``StructuredEnum(_:)``
- ``StructuredCase(_:)``

### Clients

- ``AnthropicClient``
- ``OpenAIClient``
- ``GeminiClient``
- ``StructuredLLMClient``

### Models

- ``ClaudeModel``
- ``GPTModel``
- ``GeminiModel``
- ``LLMModel``

### Conversation

- ``Conversation``
- ``ChatResponse``
- ``LLMMessage``
- ``TokenUsage``
- ``StopReason``

### Schema

- ``JSONSchema``
- ``FieldConstraint``
- ``StructuredProtocol``

### Errors

- ``LLMError``
