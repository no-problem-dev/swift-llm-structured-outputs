import Foundation
import LLMClient
import LLMTool

// MARK: - ToolCallRecord

/// ツール呼び出しの履歴レコード
///
/// 重複検出の目的では `name` と `inputHash` のみで等価性を判定します。
/// `timestamp` は履歴追跡用で、等価性判定には使用されません。
internal struct ToolCallRecord: Sendable {
    /// ツール名
    let name: String

    /// 入力のハッシュ値（重複検出用）
    let inputHash: Int

    /// タイムスタンプ
    let timestamp: Date

    init(name: String, inputHash: Int, timestamp: Date = Date()) {
        self.name = name
        self.inputHash = inputHash
        self.timestamp = timestamp
    }

    /// ToolCall から作成
    init(from call: ToolCall) {
        self.name = call.name
        self.inputHash = call.arguments.hashValue
        self.timestamp = Date()
    }
}

extension ToolCallRecord: Hashable {
    /// 重複検出用の等価性判定（name と inputHash のみ比較）
    static func == (lhs: ToolCallRecord, rhs: ToolCallRecord) -> Bool {
        lhs.name == rhs.name && lhs.inputHash == rhs.inputHash
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(inputHash)
    }
}

// MARK: - AgentLoopStateSnapshot

/// ループ状態のスナップショット（読み取り専用）
internal struct AgentLoopStateSnapshot: Sendable {
    /// 現在のステップ数
    let currentStep: Int

    /// 最大ステップ数
    let maxSteps: Int

    /// ツール呼び出し履歴
    let toolCallHistory: [ToolCallRecord]

    /// 残りステップ数
    var remainingSteps: Int {
        max(0, maxSteps - currentStep)
    }

    /// ステップ上限に達しているか
    var isAtLimit: Bool {
        currentStep >= maxSteps
    }
}

// MARK: - AgentLoopStateManager

/// エージェントループの状態を管理する Actor
///
/// ステップ数、ツール呼び出し履歴などを追跡し、
/// `AgentLoopContext` プロトコルを通じて終了ポリシーに情報を提供します。
internal actor AgentLoopStateManager: AgentLoopContext {
    // MARK: - Properties

    /// 現在のステップ数
    private(set) var currentStep: Int = 0

    /// 最大ステップ数
    let maxSteps: Int

    /// ツール呼び出し履歴
    private var toolCallHistory: [ToolCallRecord] = []

    /// ループが完了したか
    private(set) var isCompleted: Bool = false

    // MARK: - Initialization

    init(maxSteps: Int) {
        self.maxSteps = maxSteps
    }

    init(configuration: AgentConfiguration) {
        self.maxSteps = configuration.maxSteps
    }

    // MARK: - AgentLoopContext Conformance

    /// ステップ上限に達しているか
    var isAtStepLimit: Bool {
        currentStep >= maxSteps
    }

    /// 指定ツールの呼び出し回数をカウント
    func countToolCalls(named name: String) -> Int {
        toolCallHistory.filter { $0.name == name }.count
    }

    /// 重複するツール呼び出し（同名・同入力）をカウント
    func countDuplicateToolCalls(name: String, inputHash: Int) -> Int {
        toolCallHistory.filter {
            $0.name == name && $0.inputHash == inputHash
        }.count
    }

    // MARK: - State Mutation

    /// ステップを進める
    ///
    /// - Returns: 新しいステップ数
    /// - Throws: `AgentError.maxStepsExceeded` if limit reached
    @discardableResult
    func incrementStep() throws -> Int {
        currentStep += 1
        if currentStep > maxSteps {
            throw AgentError.maxStepsExceeded(steps: maxSteps)
        }
        return currentStep
    }

    /// ツール呼び出しを履歴に記録
    func recordToolCall(_ call: ToolCall) {
        let record = ToolCallRecord(from: call)
        toolCallHistory.append(record)
    }

    /// 複数のツール呼び出しを履歴に記録
    func recordToolCalls(_ calls: [ToolCall]) {
        for call in calls {
            recordToolCall(call)
        }
    }

    /// ループを完了としてマーク
    func markCompleted() {
        isCompleted = true
    }

    /// ループが継続可能かチェック
    func canContinue() -> Bool {
        !isCompleted && currentStep < maxSteps
    }

    // MARK: - Snapshot

    /// 現在の状態のスナップショットを取得
    func snapshot() -> AgentLoopStateSnapshot {
        AgentLoopStateSnapshot(
            currentStep: currentStep,
            maxSteps: maxSteps,
            toolCallHistory: toolCallHistory
        )
    }

    // MARK: - Query Methods

    /// 最後のツール呼び出しを取得
    func lastToolCall() -> ToolCallRecord? {
        toolCallHistory.last
    }

    /// 指定ツールの最後の呼び出しを取得
    func lastToolCall(named name: String) -> ToolCallRecord? {
        toolCallHistory.last { $0.name == name }
    }

    /// 連続して同じツールが呼ばれた回数をカウント
    func countConsecutiveSameToolCalls() -> Int {
        guard let lastCall = toolCallHistory.last else { return 0 }

        var count = 0
        for record in toolCallHistory.reversed() {
            if record.name == lastCall.name && record.inputHash == lastCall.inputHash {
                count += 1
            } else {
                break
            }
        }
        return count
    }

    // MARK: - Reset

    /// 状態をリセット（テスト用）
    func reset() {
        currentStep = 0
        toolCallHistory = []
        isCompleted = false
    }
}
