# Providers

Learn about the supported LLM providers and their models.

## Overview

LLMStructuredOutputs supports three major LLM providers, each with their own client class and model options.

## Anthropic Claude

### Client Setup

```swift
let client = AnthropicClient(apiKey: "sk-ant-...")
```

### Model Options

Use ``ClaudeModel`` for model selection:

| Alias | Description |
|-------|-------------|
| `.sonnet` | Claude Sonnet - balanced performance |
| `.opus` | Claude Opus - highest capability |
| `.haiku` | Claude Haiku - fastest |

```swift
let result: MyType = try await client.generate(
    prompt: "...",
    model: .sonnet
)
```

### Fixed Versions

For production stability, use fixed versions:

```swift
model: .sonnet_20250514
model: .opus_20250514
model: .haiku_20250307
```

## OpenAI GPT

### Client Setup

```swift
let client = OpenAIClient(apiKey: "sk-...")
```

### Model Options

Use ``GPTModel`` for model selection:

| Alias | Description |
|-------|-------------|
| `.gpt4o` | GPT-4o - most capable |
| `.gpt4oMini` | GPT-4o Mini - faster |
| `.o1` | o1 - reasoning model |
| `.o1Mini` | o1 Mini - compact reasoning |
| `.o3Mini` | o3 Mini - latest reasoning |

```swift
let result: MyType = try await client.generate(
    prompt: "...",
    model: .gpt4o
)
```

## Google Gemini

### Client Setup

```swift
let client = GeminiClient(apiKey: "...")
```

### Model Options

Use ``GeminiModel`` for model selection:

| Alias | Description |
|-------|-------------|
| `.pro25` | Gemini 2.5 Pro - most capable |
| `.flash25` | Gemini 2.5 Flash - fast |
| `.flash25Lite` | Gemini 2.5 Flash Lite - lightweight |
| `.flash20` | Gemini 2.0 Flash - stable |
| `.pro15` | Gemini 1.5 Pro - previous gen |
| `.flash15` | Gemini 1.5 Flash - previous gen |

```swift
let result: MyType = try await client.generate(
    prompt: "...",
    model: .flash25
)
```

## Common Parameters

All providers support these parameters:

```swift
let result: MyType = try await client.generate(
    prompt: "Your prompt",
    model: .sonnet,
    systemPrompt: "You are a helpful assistant",
    temperature: 0.7,
    maxTokens: 1000
)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `prompt` | `String` | User input |
| `model` | Provider-specific | Model selection |
| `systemPrompt` | `String?` | System instructions |
| `temperature` | `Double?` | Randomness (0.0-1.0) |
| `maxTokens` | `Int?` | Max response tokens |

## Type Safety

The library enforces type safety at compile time:

```swift
// ✅ Correct - ClaudeModel with AnthropicClient
let anthropic = AnthropicClient(apiKey: "...")
try await anthropic.generate(prompt: "...", model: .sonnet)

// ❌ Won't compile - GPTModel with AnthropicClient
try await anthropic.generate(prompt: "...", model: .gpt4o)
```

## Custom Models

All providers support custom model IDs:

```swift
// Anthropic
model: .custom("claude-3-opus-20240229")

// OpenAI
model: .custom("gpt-4-1106-preview")

// Gemini
model: .custom("gemini-1.0-pro")
```
