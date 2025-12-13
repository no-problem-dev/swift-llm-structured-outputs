# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.3] - 2025-12-13

### Added
- Model aliases for all providers (ClaudeModel, GPTModel, GeminiModel)
  - `.sonnet`, `.opus`, `.haiku` for Claude
  - `.gpt4o`, `.gpt4oMini`, `.o1` for GPT
  - `.pro25`, `.flash25`, `.flash25Lite` for Gemini
- Preview version support with explicit version strings
- Custom model support via `.custom(String)` case
- `RawRepresentable` conformance for backward compatibility

### Changed
- Model enums now use computed `id` property instead of raw values
- Simplified model version management with aliases

## [1.0.2] - 2025-12-12

### Added
- `Conversation<Client>` class for multi-turn conversation management
- `ChatResponse<T>` struct with full response metadata
- Token usage tracking with `TokenUsage` struct
- `StopReason` enum for response termination reasons
- `LLMMessage` struct with `.user()` and `.assistant()` factory methods
- `chat()` methods on all clients for conversation continuation

### Changed
- All response types now include raw text and usage information

## [1.0.1] - 2025-12-11

### Added
- `@StructuredEnum` macro for String-based enum support
- `@StructuredCase` macro for enum case descriptions
- Automatic enum description generation for LLM prompts
- Nested type support in `@Structured` macro

### Fixed
- Optional field handling in JSON Schema generation
- Array type detection in macro expansion

## [1.0.0] - 2025-12-10

### Added
- Initial release
- `@Structured` macro for struct-based structured outputs
- `@StructuredField` macro with constraint support
- `StructuredProtocol` for manual JSON Schema definition
- `JSONSchema` enum for schema construction
- `FieldConstraint` enum for field validation
- Multi-provider support:
  - `AnthropicClient` for Claude models
  - `OpenAIClient` for GPT models
  - `GeminiClient` for Gemini models
- `StructuredLLMClient` protocol for unified API
- `LLMError` enum for error handling
- Full Swift 6 concurrency support
- iOS 17+ and macOS 14+ support

[Unreleased]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.3...HEAD
[1.0.3]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/no-problem-dev/swift-llm-structured-outputs/releases/tag/v1.0.0
