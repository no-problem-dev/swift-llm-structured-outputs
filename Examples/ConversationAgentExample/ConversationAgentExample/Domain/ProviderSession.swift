import Foundation
import LLMStructuredOutputs
import LLMToolkits

/// 各プロバイダーのセッションを統一的に扱うための enum
enum ProviderSession: Sendable {
    case anthropic(ConversationalAgentSession<AnthropicClient>)
    case openai(ConversationalAgentSession<OpenAIClient>)
    case gemini(ConversationalAgentSession<GeminiClient>)

    // MARK: - Event Stream

    var eventStream: AsyncStream<ConversationalAgentEvent> {
        switch self {
        case .anthropic(let session): session.eventStream
        case .openai(let session): session.eventStream
        case .gemini(let session): session.eventStream
        }
    }

    // MARK: - Properties

    var running: Bool {
        get async {
            switch self {
            case .anthropic(let session): await session.running
            case .openai(let session): await session.running
            case .gemini(let session): await session.running
            }
        }
    }

    var turnCount: Int {
        get async {
            switch self {
            case .anthropic(let session): await session.turnCount
            case .openai(let session): await session.turnCount
            case .gemini(let session): await session.turnCount
            }
        }
    }

    var waitingForAnswer: Bool {
        get async {
            switch self {
            case .anthropic(let session): await session.waitingForAnswer
            case .openai(let session): await session.waitingForAnswer
            case .gemini(let session): await session.waitingForAnswer
            }
        }
    }

    // MARK: - Session Control

    func interrupt(_ message: String) async {
        switch self {
        case .anthropic(let session): await session.interrupt(message)
        case .openai(let session): await session.interrupt(message)
        case .gemini(let session): await session.interrupt(message)
        }
    }

    func clear() async {
        switch self {
        case .anthropic(let session): await session.clear()
        case .openai(let session): await session.clear()
        case .gemini(let session): await session.clear()
        }
    }

    func cancel() async {
        switch self {
        case .anthropic(let session): await session.cancel()
        case .openai(let session): await session.cancel()
        case .gemini(let session): await session.cancel()
        }
    }

    func reply(_ answer: String) async {
        switch self {
        case .anthropic(let session): await session.reply(answer)
        case .openai(let session): await session.reply(answer)
        case .gemini(let session): await session.reply(answer)
        }
    }

    // MARK: - Run Methods

    func runResearch(_ prompt: String) async -> AsyncThrowingStream<ConversationalAgentStep<AnalysisResult>, Error> {
        switch self {
        case .anthropic(let session):
            await session.run(prompt, model: .sonnet, outputType: AnalysisResult.self)
        case .openai(let session):
            await session.run(prompt, model: .gpt4o, outputType: AnalysisResult.self)
        case .gemini(let session):
            await session.run(prompt, model: .flash25, outputType: AnalysisResult.self)
        }
    }

    func runArticleSummary(_ prompt: String) async -> AsyncThrowingStream<ConversationalAgentStep<Summary>, Error> {
        switch self {
        case .anthropic(let session):
            await session.run(prompt, model: .sonnet, outputType: Summary.self)
        case .openai(let session):
            await session.run(prompt, model: .gpt4o, outputType: Summary.self)
        case .gemini(let session):
            await session.run(prompt, model: .flash25, outputType: Summary.self)
        }
    }

    func runCodeReview(_ prompt: String) async -> AsyncThrowingStream<ConversationalAgentStep<CodeReview>, Error> {
        switch self {
        case .anthropic(let session):
            await session.run(prompt, model: .sonnet, outputType: CodeReview.self)
        case .openai(let session):
            await session.run(prompt, model: .gpt4o, outputType: CodeReview.self)
        case .gemini(let session):
            await session.run(prompt, model: .flash25, outputType: CodeReview.self)
        }
    }
}
