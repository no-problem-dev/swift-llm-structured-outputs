import Foundation
import LLMAgent
import LLMClient
import LLMStructuredOutputs
import LLMToolkits
import LLMConversationalAgent

/// セッション実行のビジネスロジック
///
/// Stateには依存せず、純粋な実行ロジックのみを担当する。
/// View側でUseCaseの結果をStateに反映する。
protocol SessionExecutionUseCase: Sendable {
    func interrupt(session: ProviderSession, message: String) async
    func reply(session: ProviderSession, answer: String) async
    func stop(session: ProviderSession) async
    func save(sessionData: SessionData, sessionUseCase: SessionUseCase) async throws
}

final class SessionExecutionUseCaseImpl: SessionExecutionUseCase {

    func interrupt(session: ProviderSession, message: String) async {
        await session.interrupt(message)
    }

    func reply(session: ProviderSession, answer: String) async {
        await session.reply(answer)
    }

    func stop(session: ProviderSession) async {
        await session.cancel()
    }

    func save(sessionData: SessionData, sessionUseCase: SessionUseCase) async throws {
        guard !sessionData.messages.isEmpty else { return }
        try await sessionUseCase.saveSession(sessionData)
    }
}
