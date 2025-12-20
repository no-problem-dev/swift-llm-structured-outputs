import Foundation
import LLMAgent
import LLMClient
import LLMStructuredOutputs
import LLMToolkits
import LLMConversationalAgent

/// アクティブセッションの状態を保持する純粋な状態コンテナ
///
/// ビジネスロジックを持たず、状態の保持と更新のみを担当する。
/// UseCaseには依存しない。ViewがStateとUseCaseを結びつける。
@MainActor @Observable
final class ActiveSessionState {

    // MARK: - Session

    private(set) var session: ProviderSession?
    private(set) var sessionData: SessionData

    // MARK: - Execution

    private(set) var executionState: SessionState = .idle
    private var liveSteps: [ConversationStepInfo] = []
    private(set) var events: [ConversationStepInfo] = []
    private(set) var turnCount: Int = 0

    // MARK: - User Interaction

    private(set) var waitingForAnswer: Bool = false
    private(set) var pendingQuestion: String?

    // MARK: - Settings

    private(set) var interactiveMode: Bool
    private(set) var selectedOutputType: AgentOutputType

    // MARK: - Initialization

    init(sessionData: SessionData) {
        self.sessionData = sessionData
        self.interactiveMode = sessionData.interactiveMode
        self.selectedOutputType = sessionData.outputType

        if let result = sessionData.result {
            self.executionState = .completed(result)
        }
    }

    init() {
        let newSession = SessionData()
        self.sessionData = newSession
        self.interactiveMode = newSession.interactiveMode
        self.selectedOutputType = newSession.outputType
    }

    // MARK: - Computed Properties

    var steps: [ConversationStepInfo] {
        if executionState.isRunning || !liveSteps.isEmpty {
            return liveSteps
        }
        return sessionData.messages.toStepInfos()
    }

    var currentResult: String? {
        if case .completed(let result) = executionState {
            return result
        }
        return nil
    }

    var hasActiveSession: Bool {
        session != nil
    }

    var isExecuting: Bool {
        executionState.isRunning
    }

    var hasConversationHistory: Bool {
        sessionData.messages.contains { $0.role == .user }
    }

    var canResume: Bool {
        guard hasActiveSession && !executionState.isRunning && !waitingForAnswer else {
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
        if waitingForAnswer { return .answer }
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

    // MARK: - Steps

    func addStep(_ step: ConversationStepInfo) {
        liveSteps.append(step)
    }

    func addEvent(_ message: String) {
        events.append(ConversationStepInfo(type: .event, content: message))
    }

    func initializeLiveSteps() {
        liveSteps = sessionData.messages.toStepInfos()
    }

    func syncStepsFromMessages() {
        liveSteps = []
    }

    func clearSteps() {
        liveSteps = []
        events = []
        sessionData.messages = []
    }

    // MARK: - User Interaction

    func setWaitingForAnswer(_ waiting: Bool) {
        waitingForAnswer = waiting
    }

    func setPendingQuestion(_ question: String?) {
        pendingQuestion = question
    }

    // MARK: - Settings

    func setInteractiveMode(_ mode: Bool) {
        interactiveMode = mode
        sessionData.interactiveMode = mode
    }

    func setSelectedOutputType(_ type: AgentOutputType) {
        selectedOutputType = type
        sessionData.outputType = type
    }

    // MARK: - Session Data

    func updateSessionData(result: String?) {
        sessionData.result = result
        sessionData.updatedAt = Date()
    }

    func updateTitleFromFirstMessage() {
        sessionData.updateTitleFromFirstMessage()
    }

    func syncMessagesFromSession() async {
        guard let session = session else { return }
        sessionData.messages = await session.getMessages()
        sessionData.updatedAt = Date()
    }

    func setSessionData(_ data: SessionData) {
        self.sessionData = data
        self.interactiveMode = data.interactiveMode
        self.selectedOutputType = data.outputType
        self.liveSteps = []

        if let result = data.result {
            self.executionState = .completed(result)
        } else {
            self.executionState = .idle
        }
    }

    // MARK: - Reset

    func resetExecutionState() {
        executionState = .idle
        waitingForAnswer = false
        pendingQuestion = nil
    }

    func resetAll() {
        session = nil
        executionState = .idle
        liveSteps = []
        events = []
        turnCount = 0
        waitingForAnswer = false
        pendingQuestion = nil
        sessionData.messages = []
        sessionData.result = nil
        sessionData.updatedAt = Date()
    }
}
