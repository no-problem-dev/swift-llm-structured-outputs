# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-12-13

### Added

#### Macros
- `@Structured` macro for struct-based structured outputs with automatic JSON Schema generation
- `@StructuredField` macro with constraint support (minimum, maximum, minLength, maxLength, minItems, maxItems, pattern, format, enum)
- `@StructuredEnum` macro for String-based enum support
- `@StructuredCase` macro for enum case descriptions
- Automatic enum description generation for LLM prompts
- Nested type support in `@Structured` macro

#### Clients
- `AnthropicClient` for Claude models
- `OpenAIClient` for GPT models
- `GeminiClient` for Gemini models
- `StructuredLLMClient` protocol for unified API

#### Models
- Model aliases for all providers:
  - `.sonnet`, `.opus`, `.haiku` for Claude
  - `.gpt4o`, `.gpt4oMini`, `.o1`, `.o1Mini`, `.o3Mini` for GPT
  - `.pro25`, `.flash25`, `.flash25Lite`, `.flash20`, `.pro15`, `.flash15` for Gemini
- Fixed version support (e.g., `.sonnet_20250514`)
- Preview version support with explicit version strings
- Custom model support via `.custom(String)` case
- `RawRepresentable` conformance for backward compatibility

#### Conversation
- `Conversation<Client>` class for multi-turn conversation management
- `ChatResponse<T>` struct with full response metadata
- Token usage tracking with `TokenUsage` struct
- `StopReason` enum for response termination reasons
- `LLMMessage` struct with `.user()` and `.assistant()` factory methods
- `chat()` methods on all clients for conversation continuation

#### Schema
- `StructuredProtocol` for manual JSON Schema definition
- `JSONSchema` enum for schema construction
- `FieldConstraint` enum for field validation

#### Infrastructure
- Full Swift 6 concurrency support (async/await, Sendable)
- iOS 17+ and macOS 14+ support
- `LLMError` enum for comprehensive error handling
- Documentation with DocC
- GitHub Actions for auto-release and documentation generation

[Unreleased]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/no-problem-dev/swift-llm-structured-outputs/releases/tag/v1.0.0
