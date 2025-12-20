import Foundation
import LLMDynamicStructured
import LLMClient

/// エージェントセッションの状態を保持する Observable コンテナ
///
/// ビジネスロジックを持たず、状態の保持と更新のみを担当する。
@MainActor @Observable
final class AgentSessionState {

    // MARK: - Session

    private(set) var session: ProviderSession?
    private(set) var messages: [LLMMessage] = []

    // MARK: - Type Definition

    let builtType: BuiltType

    // MARK: - Execution

    private(set) var executionState: SessionState = .idle
    private var liveSteps: [ConversationStepInfo] = []
    private(set) var events: [ConversationStepInfo] = []
    private(set) var turnCount: Int = 0

    // MARK: - Result

    private(set) var result: DynamicStructuredResult?

    // MARK: - Initialization

    init(builtType: BuiltType) {
        self.builtType = builtType
    }

    // MARK: - Computed Properties

    var steps: [ConversationStepInfo] {
        if executionState.isRunning || !liveSteps.isEmpty {
            return liveSteps
        }
        return messages.toStepInfos()
    }

    var hasActiveSession: Bool {
        session != nil
    }

    var isExecuting: Bool {
        executionState.isRunning
    }

    var hasConversationHistory: Bool {
        messages.contains { $0.role == .user }
    }

    var canResume: Bool {
        guard hasActiveSession && !executionState.isRunning else {
            return false
        }
        if executionState.isCompleted {
            return false
        }
        if executionState.canResume {
            return true
        }
        return hasConversationHistory
    }

    var isCompleted: Bool {
        executionState.isCompleted
    }

    var inputMode: InputMode {
        if executionState.isRunning { return .interrupt }
        if canResume { return .resume }
        return .prompt
    }

    // MARK: - Session

    func setSession(_ session: ProviderSession?) {
        self.session = session
    }

    // MARK: - Execution State

    func setExecutionState(_ state: SessionState) {
        executionState = state
    }

    func setTurnCount(_ count: Int) {
        turnCount = count
    }

    // MARK: - Result

    func setResult(_ result: DynamicStructuredResult?) {
        self.result = result
    }

    // MARK: - Steps

    func addStep(_ step: ConversationStepInfo) {
        liveSteps.append(step)
    }

    func addEvent(_ message: String) {
        events.append(ConversationStepInfo(type: .event, content: message))
    }

    func initializeLiveSteps() {
        liveSteps = messages.toStepInfos()
    }

    func syncStepsFromMessages() {
        liveSteps = []
    }

    func clearSteps() {
        liveSteps = []
        events = []
        messages = []
    }

    // MARK: - Messages

    func syncMessagesFromSession() async {
        guard let session = session else { return }
        messages = await session.getMessages()
    }

    // MARK: - Reset

    func resetExecutionState() {
        executionState = .idle
    }

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
