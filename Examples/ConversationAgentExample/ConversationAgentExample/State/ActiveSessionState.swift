import Foundation
import LLMAgent
import LLMClient
import LLMStructuredOutputs
import LLMToolkits
import LLMConversationalAgent

/// アクティブセッションの状態を保持
///
/// アプリ全体で共有されるセッション状態。
/// セッション参照を一元管理し、View間で状態を同期する。
/// 実行タスクもここで管理し、Viewのライフサイクルから独立させる。
///
/// ## データの流れ
///
/// - **永続化**: `sessionData.messages: [LLMMessage]` が Single Source of Truth
/// - **UI表示**: `steps: [ConversationStepInfo]` は `messages` から動的に生成
/// - **ライブ表示**: 実行中は `liveSteps` に一時的なステップを蓄積
@MainActor @Observable
final class ActiveSessionState {

    // MARK: - Session Reference

    /// 現在アクティブなセッション
    ///
    /// アプリ全体で共有される単一のセッション参照。
    /// Viewのライフサイクルとは独立して保持される。
    private(set) var session: ProviderSession?

    // MARK: - Session Data

    /// 永続化用のセッションデータ
    private(set) var sessionData: SessionData

    // MARK: - Execution State

    /// 現在の実行状態
    private(set) var executionState: SessionState = .idle

    /// ライブ実行中の一時的なステップ
    ///
    /// ストリーム実行中に追加されるステップ。
    /// 実行完了後、messages から再生成される steps と置き換わる。
    private var liveSteps: [ConversationStepInfo] = []

    /// イベントログ
    private(set) var events: [ConversationStepInfo] = []

    /// 現在のターン数
    private(set) var turnCount: Int = 0

    // MARK: - User Interaction State

    /// ユーザーの回答待ち状態
    private(set) var waitingForAnswer: Bool = false

    /// 保留中の質問
    private(set) var pendingQuestion: String?

    // MARK: - Session Settings

    /// インタラクティブモード
    private(set) var interactiveMode: Bool

    /// 選択された出力タイプ
    private(set) var selectedOutputType: AgentOutputType

    // MARK: - Task Management

    /// 実行タスク
    ///
    /// run/resumeの実行を管理するタスク。
    /// Viewのライフサイクルから独立して保持される。
    private(set) var executionTask: Task<Void, Never>?

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

    /// 会話ステップの履歴（UI表示用）
    ///
    /// 永続化された `messages` から動的に生成。
    /// ライブ実行中は `liveSteps` を返す。
    var steps: [ConversationStepInfo] {
        if executionState.isRunning || !liveSteps.isEmpty {
            return liveSteps
        }
        return sessionData.messages.toStepInfos()
    }

    /// 完了時の結果（存在する場合）
    var currentResult: String? {
        if case .completed(let result) = executionState {
            return result
        }
        return nil
    }

    /// セッションがアクティブかどうか
    var hasActiveSession: Bool {
        session != nil
    }

    /// 実行中かどうか
    var isExecuting: Bool {
        executionTask != nil && executionState.isRunning
    }

    /// セッションが既に開始されているかどうか（会話履歴がある）
    ///
    /// `true`の場合、新しいプロンプトは`run()`ではなく`resume()`または`interrupt()`で処理すべき。
    var hasConversationHistory: Bool {
        // messages にユーザーメッセージがあるかどうかで判定
        sessionData.messages.contains { $0.role == .user }
    }

    /// 再開可能な状態かどうか
    ///
    /// 以下の条件で`true`:
    /// - 一時停止（paused）またはエラー（error）状態
    /// - idle/completed状態で会話履歴がある場合
    ///
    /// 実行中（running）または回答待ち（waitingForAnswer）の場合は`false`。
    var canResume: Bool {
        guard hasActiveSession && !executionState.isRunning && !waitingForAnswer else {
            return false
        }
        // paused/error は常に再開可能
        if executionState.canResume {
            return true
        }
        // idle/completed で会話履歴がある場合も再開可能
        return hasConversationHistory
    }

    /// 完了状態かどうか
    ///
    /// 構造化出力の生成が完了した状態。
    var isCompleted: Bool {
        executionState.isCompleted
    }

    // MARK: - Session Setters

    func setSession(_ session: ProviderSession?) {
        self.session = session
    }

    // MARK: - Execution State Setters

    func setExecutionState(_ state: SessionState) {
        executionState = state
    }

    func setTurnCount(_ count: Int) {
        turnCount = count
    }

    // MARK: - Step Management

    /// ライブ実行中にステップを追加
    func addStep(_ step: ConversationStepInfo) {
        liveSteps.append(step)
    }

    func addEvent(_ message: String) {
        events.append(ConversationStepInfo(type: .event, content: message))
    }

    /// ライブステップをクリアして messages から再生成
    func syncStepsFromMessages() {
        liveSteps = []
    }

    /// 全てクリア
    func clearSteps() {
        liveSteps = []
        events = []
        sessionData.messages = []
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

    /// セッションから messages を同期
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

    // MARK: - Execution Actions

    /// セッションを実行開始
    ///
    /// - Parameters:
    ///   - prompt: ユーザーのプロンプト
    ///   - onSave: セッション保存時のコールバック
    func startExecution(prompt: String, onSave: @escaping () async throws -> Void) {
        guard let session = session else {
            setExecutionState(.error("セッションが作成されていません"))
            return
        }
        guard !executionState.isRunning else { return }

        // 既存の実行タスクをキャンセル
        executionTask?.cancel()

        // ライブステップを初期化（既存の messages から変換）
        liveSteps = sessionData.messages.toStepInfos()

        setExecutionState(.running)

        // 実行タスクを作成して保持
        executionTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                switch self.selectedOutputType {
                case .research:
                    let stream = session.runResearch(prompt)
                    try await self.processStream(stream, session: session, onSave: onSave) { $0.formatted }

                case .articleSummary:
                    let stream = session.runArticleSummary(prompt)
                    try await self.processStream(stream, session: session, onSave: onSave) { $0.formatted }

                case .codeReview:
                    let stream = session.runCodeReview(prompt)
                    try await self.processStream(stream, session: session, onSave: onSave) { $0.formatted }
                }
            } catch is CancellationError {
                // タスクキャンセルは正常終了として扱う
                self.addEvent("実行がキャンセルされました")
                await self.syncMessagesFromSession()
            } catch {
                self.setExecutionState(.error(error.localizedDescription))
                self.addStep(ConversationStepInfo(type: .error, content: error.localizedDescription, isError: true))
                await self.syncMessagesFromSession()
            }

            self.executionTask = nil
        }
    }

    /// セッションを再開
    ///
    /// - Parameter onSave: セッション保存時のコールバック
    func resumeExecution(onSave: @escaping () async throws -> Void) {
        guard let session = session else {
            setExecutionState(.error("セッションが存在しません"))
            return
        }

        // 既存の実行タスクをキャンセル
        executionTask?.cancel()

        // ライブステップを初期化
        liveSteps = sessionData.messages.toStepInfos()

        setExecutionState(.running)
        addStep(ConversationStepInfo(type: .event, content: "セッションを再開しています..."))

        // 実行タスクを作成して保持
        executionTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                switch self.selectedOutputType {
                case .research:
                    let stream = session.resumeResearch()
                    try await self.processStream(stream, session: session, onSave: onSave) { $0.formatted }

                case .articleSummary:
                    let stream = session.resumeArticleSummary()
                    try await self.processStream(stream, session: session, onSave: onSave) { $0.formatted }

                case .codeReview:
                    let stream = session.resumeCodeReview()
                    try await self.processStream(stream, session: session, onSave: onSave) { $0.formatted }
                }
            } catch is CancellationError {
                // タスクキャンセルは正常終了として扱う
                self.addEvent("実行がキャンセルされました")
                await self.syncMessagesFromSession()
            } catch {
                self.setExecutionState(.error(error.localizedDescription))
                self.addStep(ConversationStepInfo(type: .error, content: error.localizedDescription, isError: true))
                await self.syncMessagesFromSession()
            }

            self.executionTask = nil
        }
    }

    /// 実行を停止
    func stopExecution() {
        guard executionState.isRunning else { return }

        Task {
            await session?.cancel()
            await syncMessagesFromSession()
        }

        executionTask?.cancel()
        executionTask = nil

        // 一時停止状態に遷移（会話履歴は保持）
        executionState = .paused
        waitingForAnswer = false
        pendingQuestion = nil
        addStep(ConversationStepInfo(type: .event, content: "実行を停止しました"))
    }

    // MARK: - Stream Processing

    private func processStream<Output: StructuredProtocol>(
        _ stream: AsyncThrowingStream<SessionPhase<Output>, Error>,
        session: ProviderSession,
        onSave: @escaping () async throws -> Void,
        formatResult: @escaping (Output) -> String
    ) async throws {
        var finalOutput: Output?

        for try await phase in stream {
            // キャンセルチェック
            try Task.checkCancellation()

            // フェーズに応じてステップを追加
            switch phase {
            case .idle:
                break

            case .running(let step):
                addStep(step.toStepInfo())

                // 特定のステップに応じた処理
                if case .askingUser(let question) = step {
                    setPendingQuestion(question)
                }

            case .awaitingUserInput(let question):
                setPendingQuestion(question)
                setWaitingForAnswer(true)
                setExecutionState(.idle)
                addStep(ConversationStepInfo(type: .awaitingInput, content: "下の入力欄から回答してください"))

            case .paused:
                addEvent("セッションが一時停止されました")

            case .completed(let output):
                finalOutput = output
                addStep(ConversationStepInfo(type: .finalResponse, content: "レポート生成完了"))

            case .failed(let error):
                addStep(ConversationStepInfo(type: .error, content: error, isError: true))
            }
        }

        // ストリーム完了後、messages を同期
        await syncMessagesFromSession()

        if let output = finalOutput {
            setExecutionState(.completed(formatResult(output)))
        } else {
            setExecutionState(.completed("完了しました（テキスト応答）"))
        }

        setTurnCount(await session.turnCount)

        // ライブステップをクリア（steps は messages から再生成される）
        syncStepsFromMessages()

        try? await onSave()
    }

    // MARK: - Reset

    /// セッションの状態をリセット（会話履歴を保持しながら）
    ///
    /// セッション参照は維持しつつ、
    /// 実行状態と入力状態のみをリセットする。
    func resetExecutionState() {
        executionState = .idle
        waitingForAnswer = false
        pendingQuestion = nil
    }

    /// 完全リセット（会話履歴も含めて）
    ///
    /// 新規セッション開始時に使用する。
    /// 既存の会話履歴も含めて完全にクリアする。
    func resetAll() {
        // タスクをキャンセル
        executionTask?.cancel()
        executionTask = nil

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
