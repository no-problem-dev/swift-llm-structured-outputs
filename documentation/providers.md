# Providers

swift-llm-structured-outputs supports multiple LLM providers through a unified interface.

## Supported Providers

| Provider | Client Class | Model Enum |
|----------|-------------|------------|
| Anthropic | `AnthropicClient` | `ClaudeModel` |
| OpenAI | `OpenAIClient` | `GPTModel` |
| Google | `GeminiClient` | `GeminiModel` |

## Anthropic Claude

### Setup

```swift
let client = AnthropicClient(apiKey: "sk-ant-...")
```

### Available Models

| Alias | Model ID | Description |
|-------|----------|-------------|
| `.sonnet` | claude-sonnet-4-20250514 | Best balance of speed and quality |
| `.opus` | claude-opus-4-20250514 | Most capable model |
| `.haiku` | claude-haiku-3-20250307 | Fastest model |

### Using Fixed Versions

```swift
// Use a specific version
let result: MyType = try await client.generate(
    prompt: "...",
    model: .sonnet_20250514
)

// Use preview versions
let result: MyType = try await client.generate(
    prompt: "...",
    model: .sonnet_preview(version: "2025-01-15")
)
```

### Custom Models

```swift
let result: MyType = try await client.generate(
    prompt: "...",
    model: .custom("claude-3-5-sonnet-20241022")
)
```

## OpenAI GPT

### Setup

```swift
let client = OpenAIClient(apiKey: "sk-...")
```

### Available Models

| Alias | Model ID | Description |
|-------|----------|-------------|
| `.gpt4o` | gpt-4o | Most capable GPT model |
| `.gpt4oMini` | gpt-4o-mini | Faster, more economical |
| `.o1` | o1 | Reasoning model |
| `.o1Mini` | o1-mini | Faster reasoning model |
| `.o3Mini` | o3-mini | Latest compact reasoning |

### Using Fixed Versions

```swift
let result: MyType = try await client.generate(
    prompt: "...",
    model: .gpt4o_20241120
)
```

### Preview Versions

```swift
let result: MyType = try await client.generate(
    prompt: "...",
    model: .gpt4o_preview(version: "2024-12-17")
)
```

## Google Gemini

### Setup

```swift
let client = GeminiClient(apiKey: "...")
```

### Available Models

| Alias | Model ID | Description |
|-------|----------|-------------|
| `.pro25` | gemini-2.5-pro-preview-06-05 | Most capable |
| `.flash25` | gemini-2.5-flash-preview-05-20 | Fast and efficient |
| `.flash25Lite` | gemini-2.5-flash-lite-preview-06-17 | Lightweight |
| `.flash20` | gemini-2.0-flash | Stable flash model |
| `.pro15` | gemini-1.5-pro | Previous generation pro |
| `.flash15` | gemini-1.5-flash | Previous generation flash |

### Preview Versions

```swift
let result: MyType = try await client.generate(
    prompt: "...",
    model: .pro25_preview(version: "06-05")
)
```

## Common Parameters

All clients support the following parameters:

```swift
let result: MyType = try await client.generate(
    prompt: "Your prompt here",
    model: .sonnet,
    systemPrompt: "You are a helpful assistant",  // Optional
    temperature: 0.7,  // Optional: 0.0-1.0
    maxTokens: 1000    // Optional
)
```

### Parameter Descriptions

| Parameter | Type | Description |
|-----------|------|-------------|
| `prompt` | `String` | The user's input prompt |
| `model` | Provider-specific | The model to use |
| `systemPrompt` | `String?` | System instructions |
| `temperature` | `Double?` | Randomness (0.0-1.0) |
| `maxTokens` | `Int?` | Maximum response tokens |

## Type Safety

The library ensures type safety at compile time:

```swift
// ✅ Compiles - correct model type
let anthropic = AnthropicClient(apiKey: "...")
let result: MyType = try await anthropic.generate(
    prompt: "...",
    model: .sonnet  // ClaudeModel
)

// ❌ Won't compile - wrong model type
let result: MyType = try await anthropic.generate(
    prompt: "...",
    model: .gpt4o  // GPTModel - type mismatch!
)
```

## Error Handling

```swift
do {
    let result: MyType = try await client.generate(
        prompt: "...",
        model: .sonnet
    )
} catch let error as LLMError {
    switch error {
    case .apiError(let message):
        print("API error: \(message)")
    case .decodingError(let message):
        print("Failed to decode response: \(message)")
    case .invalidResponse:
        print("Invalid response from API")
    case .networkError(let underlying):
        print("Network error: \(underlying)")
    }
}
```

## Next Steps

- Learn about [Conversation](conversation.md) for multi-turn interactions
- Check the [API Reference](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/) for complete documentation
