# swift-llm-structured-outputs

Type-safe structured output generation for Swift LLM clients

🌐 English | **[日本語](README.md)**

![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%2B%20%7C%20macOS%2014%2B%20%7C%20Linux-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Overview

A Swift library for getting type-safe structured outputs from Claude, GPT, and Gemini. Map LLM responses directly to Swift structs defined with Swift Macros.

## Key Features

- **Structured Outputs** - Define type-safe outputs with `@Structured` macro, auto-generate schemas
- **Agents** - Auto-execute tools and generate structured outputs (`runAgent`)
- **Conversations** - Maintain multi-turn context with `ConversationHistory`
- **Multimodal** - Image, audio, video input (Vision) and generation
- **3 Providers** - Claude, GPT, Gemini via unified API

## Quick Start

```swift
import LLMStructuredOutputs

@Structured("User information")
struct UserInfo {
    @StructuredField("Name") var name: String
    @StructuredField("Age", .minimum(0)) var age: Int
}

let client = AnthropicClient(apiKey: "sk-ant-...")
let user: UserInfo = try await client.generate(
    input: "John Smith is 35 years old",
    model: .sonnet
)
// user.name → "John Smith", user.age → 35
```

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-llm-structured-outputs.git", from: "1.0.0")
]

.target(
    name: "YourApp",
    dependencies: [
        .product(name: "LLMStructuredOutputs", package: "swift-llm-structured-outputs"),
        // Optional
        .product(name: "LLMToolkits", package: "swift-llm-structured-outputs"),
        .product(name: "LLMMCP", package: "swift-llm-structured-outputs")
    ]
)
```

## Documentation

### API Reference (DocC)

| Module | Description |
|--------|-------------|
| [LLMStructuredOutputs](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/) | Main module (structured outputs, agents, conversations) |
| [LLMClient](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmclient/) | LLM clients, prompts, multimodal |
| [LLMToolkits](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmtoolkits/) | Presets, built-in tools, common output structures |
| [LLMMCP](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmmcp/) | MCP integration, built-in ToolKits |

### Guides

| Topic | Description |
|-------|-------------|
| [Getting Started](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/gettingstarted) | Installation and basic usage |
| [Prompt Building](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/promptbuilding) | Building prompts with Prompt DSL |
| [Conversations](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/conversations) | Implementing multi-turn conversations |
| [Agent Loop](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/agentloop) | Auto tool execution and structured output |
| [Conversational Agent](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/conversationalagent) | Agents with multi-turn conversation |
| [Multimodal](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmclient/multimodal) | Image, audio, video input and generation |
| [Providers](https://no-problem-dev.github.io/swift-llm-structured-outputs/documentation/llmstructuredoutputs/providers) | Provider and model details |

## Feature Matrix

### Text Features

| Feature | Anthropic | OpenAI | Gemini |
|---------|:---------:|:------:|:------:|
| Structured Output | ✓ | ✓ | ✓ |
| Streaming | ✓ | ✓ | ✓ |
| Tool Calling | ✓ | ✓ | ✓ |
| Agent Loop | ✓ | ✓ | ✓ |

### Multimodal Input (Vision)

| Feature | Anthropic | OpenAI | Gemini |
|---------|:---------:|:------:|:------:|
| Image Analysis | ✓ | ✓ | ✓ |
| Audio Analysis | - | ✓ | ✓ |
| Video Analysis | - | - | ✓ |

### Multimodal Generation

| Feature | Anthropic | OpenAI | Gemini |
|---------|:---------:|:------:|:------:|
| Image Generation | - | ✓ DALL-E, GPT-Image | ✓ Imagen 4 |
| Speech Generation | - | ✓ TTS-1, TTS-1-HD | - |
| Video Generation | - | ✓ Sora 2 | ✓ Veo 2.0-3.1 |

## Supported Providers

| Provider | Client | Model Examples |
|----------|--------|----------------|
| Anthropic | `AnthropicClient` | `.sonnet`, `.opus`, `.haiku` |
| OpenAI | `OpenAIClient` | `.gpt4o`, `.gpt4oMini`, `.o1`, `.o3Mini` |
| Google | `GeminiClient` | `.flash3`, `.pro25`, `.flash25` |

## Requirements

- iOS 17.0+ / macOS 14.0+ / Linux
- Swift 6.0+
- Xcode 16+

## Example App

An iOS example app is available at `Examples/LLMStructuredOutputsExample`.

## License

MIT License - See [LICENSE](LICENSE) for details.

---

Made with ❤️ by [NOPROBLEM](https://github.com/no-problem-dev)
