import Foundation
import LLMDynamicStructured
import LLMClient

/// 会話の状態を保持
@MainActor @Observable
final class ChatState {
    private(set) var session: ProviderSession?
    private(set) var messages: [LLMMessage] = []
    let outputSchema: OutputSchema

    private(set) var executionState: SessionState = .idle
    private var liveSteps: [ConversationStepInfo] = []
    private(set) var events: [ConversationStepInfo] = []
    private(set) var turnCount: Int = 0
    private(set) var result: DynamicStructuredResult?

    init(outputSchema: OutputSchema) {
        self.outputSchema = outputSchema
    }

    var steps: [ConversationStepInfo] {
        if executionState.isRunning || !liveSteps.isEmpty {
            return liveSteps
        }
        return messages.toStepInfos()
    }

    var hasActiveSession: Bool { session != nil }
    var isExecuting: Bool { executionState.isRunning }
    var hasConversationHistory: Bool { messages.contains { $0.role == .user } }

    var canResume: Bool {
        guard hasActiveSession && !executionState.isRunning else { return false }
        if executionState.isCompleted { return false }
        if executionState.canResume { return true }
        return hasConversationHistory
    }

    var isCompleted: Bool { executionState.isCompleted }

    var inputMode: InputMode {
        if executionState.isRunning { return .interrupt }
        if canResume { return .resume }
        return .prompt
    }

    func setSession(_ session: ProviderSession?) { self.session = session }
    func setExecutionState(_ state: SessionState) { executionState = state }
    func setTurnCount(_ count: Int) { turnCount = count }
    func setResult(_ result: DynamicStructuredResult?) { self.result = result }

    func addStep(_ step: ConversationStepInfo) { liveSteps.append(step) }
    func addEvent(_ message: String) { events.append(ConversationStepInfo(type: .event, content: message)) }
    func initializeLiveSteps() { liveSteps = messages.toStepInfos() }
    func syncStepsFromMessages() { liveSteps = [] }
    func clearSteps() { liveSteps = []; events = []; messages = [] }

    func syncMessagesFromSession() async {
        guard let session else { return }
        messages = await session.getMessages()
    }

    func resetExecutionState() { executionState = .idle }

    func resetAll() {
        session = nil
        executionState = .idle
        liveSteps = []
        events = []
        turnCount = 0
        messages = []
        result = nil
    }
}
