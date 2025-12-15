import Foundation

// MARK: - AgentStepSequence

/// エージェントループの具象実装
internal struct AgentStepSequence<Client: AgentCapableClient, Output: StructuredProtocol>: AgentStepSequenceProtocol
    where Client.Model: Sendable
{
    typealias Element = AgentStep<Output>

    private let client: Client
    private let model: Client.Model
    let context: AgentContext
    private let runner: AgentLoopRunner<Client, Output>

    init(client: Client, model: Client.Model, context: AgentContext) {
        self.client = client
        self.model = model
        self.context = context
        self.runner = AgentLoopRunner(client: client, model: model, context: context)
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(runner: runner)
    }

    func currentPhase() async -> AgentExecutionPhase {
        await runner.currentPhase()
    }

    func cancel() async {
        await runner.cancel()
    }
}

// MARK: - AgentStepSequence.AsyncIterator

extension AgentStepSequence {
    struct AsyncIterator: AsyncIteratorProtocol {
        private let runner: AgentLoopRunner<Client, Output>

        init(runner: AgentLoopRunner<Client, Output>) {
            self.runner = runner
        }

        mutating func next() async throws -> Element? {
            try await runner.nextStep()
        }
    }
}
