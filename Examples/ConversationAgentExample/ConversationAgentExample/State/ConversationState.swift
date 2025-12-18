import Foundation

/// 各セッションの会話状態を保持
@MainActor @Observable
final class ConversationState {

    // MARK: - Session Data

    private(set) var sessionData: SessionData

    // MARK: - Execution State

    private(set) var executionState: SessionState = .idle
    private(set) var steps: [ConversationStepInfo] = []
    private(set) var events: [ConversationStepInfo] = []
    private(set) var turnCount: Int = 0

    // MARK: - User Interaction State

    private(set) var waitingForAnswer: Bool = false
    private(set) var pendingQuestion: String?

    // MARK: - Session Settings

    private(set) var interactiveMode: Bool
    private(set) var selectedOutputType: AgentOutputType

    // MARK: - Initialization

    init(sessionData: SessionData) {
        self.sessionData = sessionData
        self.interactiveMode = sessionData.interactiveMode
        self.selectedOutputType = sessionData.outputType
        self.steps = sessionData.steps

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

    var currentResult: String? {
        if case .completed(let result) = executionState {
            return result
        }
        return nil
    }

    // MARK: - Execution State Setters

    func setExecutionState(_ state: SessionState) {
        executionState = state
    }

    func setTurnCount(_ count: Int) {
        turnCount = count
    }

    // MARK: - Step Management

    func addStep(_ step: ConversationStepInfo) {
        steps.append(step)
        sessionData.addStep(step)
    }

    func addEvent(_ message: String) {
        events.append(ConversationStepInfo(type: .event, content: message))
    }

    func clearSteps() {
        steps = []
        events = []
        sessionData.steps = []
    }

    // MARK: - User Interaction Setters

    func setWaitingForAnswer(_ waiting: Bool) {
        waitingForAnswer = waiting
    }

    func setPendingQuestion(_ question: String?) {
        pendingQuestion = question
    }

    // MARK: - Settings Setters

    func setInteractiveMode(_ mode: Bool) {
        interactiveMode = mode
        sessionData.interactiveMode = mode
    }

    func setSelectedOutputType(_ type: AgentOutputType) {
        selectedOutputType = type
        sessionData.outputType = type
    }

    // MARK: - Session Data Setters

    func updateSessionData(result: String?) {
        sessionData.result = result
        sessionData.updatedAt = Date()
    }

    func updateTitleFromFirstMessage() {
        sessionData.updateTitleFromFirstMessage()
    }

    // MARK: - Reset

    func reset() {
        executionState = .idle
        steps = []
        events = []
        turnCount = 0
        waitingForAnswer = false
        pendingQuestion = nil
        sessionData.steps = []
        sessionData.result = nil
        sessionData.updatedAt = Date()
    }
}
