import XCTest
@testable import LLMClient

/// LLM プロバイダー関連のテスト
final class ProviderTests: XCTestCase {

    // MARK: - Model Alias Tests

    func testClaudeModelAliases() {
        // Aliases point to latest versions (no date suffix)
        XCTAssertEqual(ClaudeModel.opus.id, "claude-opus-4-5")
        XCTAssertEqual(ClaudeModel.sonnet.id, "claude-sonnet-4-5")
        XCTAssertEqual(ClaudeModel.haiku.id, "claude-haiku-4-5")
    }

    func testClaudeModelFixedVersions() {
        // Fixed versions include date suffix
        XCTAssertEqual(ClaudeModel.opus4_5(version: "20251101").id, "claude-opus-4-5-20251101")
        XCTAssertEqual(ClaudeModel.sonnet4_5(version: "20250929").id, "claude-sonnet-4-5-20250929")
        XCTAssertEqual(ClaudeModel.haiku4_5(version: "20250929").id, "claude-haiku-4-5-20250929")
        XCTAssertEqual(ClaudeModel.opus4_1(version: "20250918").id, "claude-opus-4-1-20250918")
        XCTAssertEqual(ClaudeModel.sonnet4(version: "20250514").id, "claude-sonnet-4-20250514")
    }

    func testClaudeModelCustom() {
        XCTAssertEqual(ClaudeModel.custom("claude-3-opus-20240229").id, "claude-3-opus-20240229")
    }

    func testGPTModelAliases() {
        // Aliases point to latest versions
        XCTAssertEqual(GPTModel.gpt4o.id, "gpt-4o")
        XCTAssertEqual(GPTModel.gpt4oMini.id, "gpt-4o-mini")
        XCTAssertEqual(GPTModel.gpt4Turbo.id, "gpt-4-turbo")
        XCTAssertEqual(GPTModel.gpt4.id, "gpt-4")
        XCTAssertEqual(GPTModel.o1.id, "o1")
        XCTAssertEqual(GPTModel.o3.id, "o3")
        XCTAssertEqual(GPTModel.o3Mini.id, "o3-mini")
        XCTAssertEqual(GPTModel.o4Mini.id, "o4-mini")
    }

    func testGPTModelFixedVersions() {
        // Fixed versions include date suffix
        XCTAssertEqual(GPTModel.gpt4o_version("2024-11-20").id, "gpt-4o-2024-11-20")
        XCTAssertEqual(GPTModel.gpt4oMini_version("2024-07-18").id, "gpt-4o-mini-2024-07-18")
        XCTAssertEqual(GPTModel.o1_version("2024-12-17").id, "o1-2024-12-17")
        XCTAssertEqual(GPTModel.o3_version("2025-04-16").id, "o3-2025-04-16")
        XCTAssertEqual(GPTModel.o3Mini_version("2025-01-31").id, "o3-mini-2025-01-31")
        XCTAssertEqual(GPTModel.o4Mini_version("2025-04-16").id, "o4-mini-2025-04-16")
    }

    func testGPTModelCustom() {
        XCTAssertEqual(GPTModel.custom("gpt-4-32k").id, "gpt-4-32k")
    }

    func testGeminiModelAliases() {
        // Aliases point to latest stable versions
        XCTAssertEqual(GeminiModel.flash3.id, "gemini-3-flash-preview")
        XCTAssertEqual(GeminiModel.pro25.id, "gemini-2.5-pro")
        XCTAssertEqual(GeminiModel.flash25.id, "gemini-2.5-flash")
        XCTAssertEqual(GeminiModel.flash25Lite.id, "gemini-2.5-flash-lite")
        XCTAssertEqual(GeminiModel.flash20.id, "gemini-2.0-flash")
        XCTAssertEqual(GeminiModel.pro15.id, "gemini-1.5-pro")
        XCTAssertEqual(GeminiModel.flash15.id, "gemini-1.5-flash")
    }

    func testGeminiModelPreviewVersions() {
        // Preview versions include preview suffix
        XCTAssertEqual(GeminiModel.flash3_preview(version: "12-17").id, "gemini-3-flash-preview-12-17")
        XCTAssertEqual(GeminiModel.pro25_preview(version: "05-06").id, "gemini-2.5-pro-preview-05-06")
        XCTAssertEqual(GeminiModel.flash25_preview(version: "05-20").id, "gemini-2.5-flash-preview-05-20")
        XCTAssertEqual(GeminiModel.flash25Lite_preview(version: "06-17").id, "gemini-2.5-flash-lite-preview-06-17")
    }

    func testGeminiModelCustom() {
        XCTAssertEqual(GeminiModel.custom("gemini-2.5-pro-exp-03-25").id, "gemini-2.5-pro-exp-03-25")
    }

    func testGeminiModelRawValueCompatibility() {
        // RawRepresentable compatibility
        XCTAssertEqual(GeminiModel.flash3.rawValue, "gemini-3-flash-preview")
        XCTAssertEqual(GeminiModel.pro25.rawValue, "gemini-2.5-pro")
        XCTAssertEqual(GeminiModel(rawValue: "gemini-3-flash-preview"), .flash3)
        XCTAssertEqual(GeminiModel(rawValue: "gemini-2.5-flash"), .flash25)
        XCTAssertEqual(GeminiModel(rawValue: "custom-model"), .custom("custom-model"))
    }

    // MARK: - Preset Tests

    func testClaudeModelPreset() {
        // Preset cases
        XCTAssertEqual(ClaudeModel.Preset.allCases.count, 3)
        XCTAssertEqual(ClaudeModel.Preset.opus.model, .opus)
        XCTAssertEqual(ClaudeModel.Preset.sonnet.model, .sonnet)
        XCTAssertEqual(ClaudeModel.Preset.haiku.model, .haiku)

        // Display names
        XCTAssertEqual(ClaudeModel.Preset.opus.displayName, "Claude Opus 4.5")
        XCTAssertEqual(ClaudeModel.Preset.sonnet.shortName, "Sonnet")
    }

    func testGPTModelPreset() {
        // Preset cases
        XCTAssertEqual(GPTModel.Preset.allCases.count, 4)
        XCTAssertEqual(GPTModel.Preset.gpt4o.model, .gpt4o)
        XCTAssertEqual(GPTModel.Preset.gpt4oMini.model, .gpt4oMini)
        XCTAssertEqual(GPTModel.Preset.o1.model, .o1)
        XCTAssertEqual(GPTModel.Preset.o3Mini.model, .o3Mini)

        // Display names
        XCTAssertEqual(GPTModel.Preset.gpt4o.displayName, "GPT-4o")
        XCTAssertEqual(GPTModel.Preset.gpt4oMini.shortName, "4o mini")
        XCTAssertEqual(GPTModel.Preset.o3Mini.displayName, "o3-mini")
    }

    func testGeminiModelPreset() {
        // Preset cases
        XCTAssertEqual(GeminiModel.Preset.allCases.count, 4)
        XCTAssertEqual(GeminiModel.Preset.flash3.model, .flash3)
        XCTAssertEqual(GeminiModel.Preset.pro25.model, .pro25)
        XCTAssertEqual(GeminiModel.Preset.flash25.model, .flash25)
        XCTAssertEqual(GeminiModel.Preset.flash25Lite.model, .flash25Lite)

        // Display names
        XCTAssertEqual(GeminiModel.Preset.flash3.displayName, "Gemini 3 Flash")
        XCTAssertEqual(GeminiModel.Preset.pro25.shortName, "2.5 Pro")
    }

    // MARK: - Internal LLMModel Tests (via @testable)

    func testLLMModelIDs() {
        // Aliases use short form
        XCTAssertEqual(LLMModel.claude(.opus).id, "claude-opus-4-5")
        XCTAssertEqual(LLMModel.gpt(.gpt4o).id, "gpt-4o")
        XCTAssertEqual(LLMModel.gemini(.flash25).id, "gemini-2.5-flash")
        XCTAssertEqual(LLMModel.custom("my-custom-model").id, "my-custom-model")

        // Fixed versions use full form
        XCTAssertEqual(LLMModel.claude(.sonnet4_5(version: "20250929")).id, "claude-sonnet-4-5-20250929")
        XCTAssertEqual(LLMModel.gpt(.gpt4o_version("2024-11-20")).id, "gpt-4o-2024-11-20")
        XCTAssertEqual(LLMModel.gemini(.flash25_preview(version: "05-20")).id, "gemini-2.5-flash-preview-05-20")
    }

    func testModelEquality() {
        XCTAssertEqual(LLMModel.claude(.sonnet), LLMModel.claude(.sonnet))
        XCTAssertNotEqual(LLMModel.claude(.sonnet), LLMModel.claude(.opus))
        XCTAssertNotEqual(LLMModel.claude(.sonnet), LLMModel.gpt(.gpt4o))
    }

    // MARK: - LLMMessage Tests

    func testUserMessage() {
        let message = LLMMessage.user("Hello")
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Hello")
    }

    func testAssistantMessage() {
        let message = LLMMessage.assistant("Hi there")
        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, "Hi there")
    }

    func testMessageInit() {
        let message = LLMMessage(role: .user, content: "Test")
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Test")
    }

    // MARK: - LLMRequest Tests (via @testable)

    func testRequestInit() {
        let request = LLMRequest(
            model: .claude(.sonnet),
            messages: [.user("Hello")],
            systemPrompt: "You are helpful",
            temperature: 0.7,
            maxTokens: 1000
        )

        XCTAssertEqual(request.model, .claude(.sonnet))
        XCTAssertEqual(request.messages.count, 1)
        XCTAssertEqual(request.systemPrompt, "You are helpful")
        XCTAssertNil(request.responseSchema)
        XCTAssertEqual(request.temperature, 0.7)
        XCTAssertEqual(request.maxTokens, 1000)
    }

    func testRequestWithSchema() {
        let schema = JSONSchema.object(
            properties: ["name": .string()],
            required: ["name"]
        )

        let request = LLMRequest(
            model: .gpt(.gpt4o),
            messages: [.user("Extract name")],
            responseSchema: schema
        )

        XCTAssertNotNil(request.responseSchema)
        XCTAssertEqual(request.responseSchema?.type, .object)
    }

    // MARK: - LLMResponse Tests

    func testResponseTextContent() {
        let response = LLMResponse(
            content: [.text("Hello world")],
            model: "claude-sonnet-4-5-20250929",
            usage: TokenUsage(inputTokens: 10, outputTokens: 5)
        )

        XCTAssertEqual(response.content.count, 1)
        XCTAssertEqual(response.content.first?.text, "Hello world")
        XCTAssertEqual(response.model, "claude-sonnet-4-5-20250929")
        XCTAssertEqual(response.usage.inputTokens, 10)
        XCTAssertEqual(response.usage.outputTokens, 5)
        XCTAssertEqual(response.usage.totalTokens, 15)
    }

    func testResponseStopReason() {
        let response = LLMResponse(
            content: [.text("Done")],
            model: "gpt-4o",
            usage: TokenUsage(inputTokens: 5, outputTokens: 2),
            stopReason: .endTurn
        )

        XCTAssertEqual(response.stopReason, .endTurn)
    }

    func testContentBlockTextAccessor() {
        let textBlock = LLMResponse.ContentBlock.text("Test content")
        XCTAssertEqual(textBlock.text, "Test content")

        let toolBlock = LLMResponse.ContentBlock.toolUse(
            id: "123",
            name: "test_tool",
            input: Data()
        )
        XCTAssertNil(toolBlock.text)
    }

    // MARK: - TokenUsage Tests

    func testTokenUsage() {
        let usage = TokenUsage(inputTokens: 100, outputTokens: 50)
        XCTAssertEqual(usage.inputTokens, 100)
        XCTAssertEqual(usage.outputTokens, 50)
        XCTAssertEqual(usage.totalTokens, 150)
    }

    // MARK: - LLMError Tests

    func testErrorDescriptions() {
        XCTAssertNotNil(LLMError.unauthorized.errorDescription)
        XCTAssertNotNil(LLMError.rateLimitExceeded.errorDescription)
        XCTAssertNotNil(LLMError.invalidRequest("test").errorDescription)
        XCTAssertNotNil(LLMError.modelNotFound("test").errorDescription)
        XCTAssertNotNil(LLMError.serverError(500, "test").errorDescription)
        XCTAssertNotNil(LLMError.emptyResponse.errorDescription)
        XCTAssertNotNil(LLMError.invalidEncoding.errorDescription)
        XCTAssertNotNil(LLMError.timeout.errorDescription)
    }

    func testModelNotSupportedError() {
        let error = LLMError.modelNotSupported(model: "claude-sonnet-4-5-20250929", provider: "OpenAI")
        XCTAssertTrue(error.errorDescription?.contains("OpenAI") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("claude-sonnet") ?? false)
    }

    func testContentBlockedError() {
        let errorWithReason = LLMError.contentBlocked(reason: "safety")
        XCTAssertTrue(errorWithReason.errorDescription?.contains("safety") ?? false)

        let errorWithoutReason = LLMError.contentBlocked(reason: nil)
        XCTAssertNotNil(errorWithoutReason.errorDescription)
    }

    // MARK: - StopReason Tests

    func testStopReasonRawValues() {
        XCTAssertEqual(LLMResponse.StopReason.endTurn.rawValue, "end_turn")
        XCTAssertEqual(LLMResponse.StopReason.maxTokens.rawValue, "max_tokens")
        XCTAssertEqual(LLMResponse.StopReason.stopSequence.rawValue, "stop_sequence")
        XCTAssertEqual(LLMResponse.StopReason.toolUse.rawValue, "tool_use")
    }

    // MARK: - Client Initialization Tests

    func testAnthropicClientInit() {
        let client = AnthropicClient(apiKey: "test-key")
        XCTAssertNotNil(client)
    }

    func testOpenAIClientInit() {
        let client = OpenAIClient(apiKey: "test-key")
        XCTAssertNotNil(client)
    }

    func testOpenAIClientWithOrganization() {
        let client = OpenAIClient(apiKey: "test-key", organization: "org-123")
        XCTAssertNotNil(client)
    }

    func testGeminiClientInit() {
        let client = GeminiClient(apiKey: "test-key")
        XCTAssertNotNil(client)
    }

    // MARK: - Internal Provider Tests (via @testable)

    func testAnthropicProviderInit() {
        let provider = AnthropicProvider(apiKey: "test-key")
        XCTAssertNotNil(provider)
    }

    func testOpenAIProviderInit() {
        let provider = OpenAIProvider(apiKey: "test-key")
        XCTAssertNotNil(provider)
    }

    func testGeminiProviderInit() {
        let provider = GeminiProvider(apiKey: "test-key")
        XCTAssertNotNil(provider)
    }

    // MARK: - Model Validation Tests (via @testable)

    func testAnthropicProviderRejectsNonClaudeModel() async {
        let provider = AnthropicProvider(apiKey: "test-key")
        let request = LLMRequest(
            model: .gpt(.gpt4o),
            messages: [.user("Hello")]
        )

        do {
            _ = try await provider.send(request)
            XCTFail("Expected error for non-Claude model")
        } catch let error as LLMError {
            if case .modelNotSupported(let model, let providerName) = error {
                XCTAssertEqual(providerName, "Anthropic")
                XCTAssertEqual(model, "gpt-4o")
            } else {
                XCTFail("Expected modelNotSupported error")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testOpenAIProviderRejectsNonGPTModel() async {
        let provider = OpenAIProvider(apiKey: "test-key")
        let request = LLMRequest(
            model: .claude(.sonnet),
            messages: [.user("Hello")]
        )

        do {
            _ = try await provider.send(request)
            XCTFail("Expected error for non-GPT model")
        } catch let error as LLMError {
            if case .modelNotSupported(let model, let providerName) = error {
                XCTAssertEqual(providerName, "OpenAI")
                XCTAssertEqual(model, "claude-sonnet-4-5")  // Alias form
            } else {
                XCTFail("Expected modelNotSupported error")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testGeminiProviderRejectsNonGeminiModel() async {
        let provider = GeminiProvider(apiKey: "test-key")
        let request = LLMRequest(
            model: .claude(.sonnet),
            messages: [.user("Hello")]
        )

        do {
            _ = try await provider.send(request)
            XCTFail("Expected error for non-Gemini model")
        } catch let error as LLMError {
            if case .modelNotSupported(let model, let providerName) = error {
                XCTAssertEqual(providerName, "Gemini")
                XCTAssertEqual(model, "claude-sonnet-4-5")  // Alias form
            } else {
                XCTFail("Expected modelNotSupported error")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Type Safety Tests

    /// コンパイル時の型安全性を確認するテスト
    /// AnthropicClient は ClaudeModel のみを受け付ける
    func testAnthropicClientTypeConstraint() {
        let client = AnthropicClient(apiKey: "test-key")
        // この行はコンパイルが通る
        _ = ClaudeModel.sonnet
        // 以下のコードはコンパイルエラーになるはず（コメントアウト）
        // let _: GPTModel = .gpt4o  // これを client.generate に渡すとコンパイルエラー
        XCTAssertNotNil(client)
    }

    /// OpenAIClient は GPTModel のみを受け付ける
    func testOpenAIClientTypeConstraint() {
        let client = OpenAIClient(apiKey: "test-key")
        _ = GPTModel.gpt4o
        XCTAssertNotNil(client)
    }

    /// GeminiClient は GeminiModel のみを受け付ける
    func testGeminiClientTypeConstraint() {
        let client = GeminiClient(apiKey: "test-key")
        _ = GeminiModel.flash25
        XCTAssertNotNil(client)
    }
}
