import Foundation
import LLMStructuredOutputs

/// 会話ViewModel プロトコル
///
/// 会話エージェントの状態管理とアクションを定義します。
@MainActor
protocol ConversationViewModel: AnyObject, Observable {
    // MARK: - Session Data

    /// 現在のセッションデータ
    var sessionData: SessionData { get }

    // MARK: - State Properties

    /// セッションの状態
    var state: SessionState { get }

    /// 会話ステップ一覧
    var steps: [ConversationStepInfo] { get }

    /// イベントログ
    var events: [ConversationStepInfo] { get }

    /// ターン数
    var turnCount: Int { get }

    /// AI がユーザーの回答を待っているかどうか
    var waitingForAnswer: Bool { get }

    /// AI からの質問（回答待ち時）
    var pendingQuestion: String? { get }

    /// セッションが存在するか
    var hasSession: Bool { get }

    // MARK: - Bindable Properties

    /// インタラクティブモード
    var interactiveMode: Bool { get set }

    /// 選択中の出力タイプ
    var selectedOutputType: AgentOutputType { get set }

    // MARK: - Session Management

    /// セッションを作成（存在しない場合のみ）
    func createSessionIfNeeded()

    /// セッションを作成
    func createSession()

    /// セッションをクリア
    func clearSession() async

    // MARK: - Execution

    /// 選択した出力タイプで実行（async）
    ///
    /// Structured Concurrency に準拠。View の `.task(id:)` から呼び出すことで、
    /// View のライフサイクルに紐づいた自動キャンセルが可能。
    func run(prompt: String, outputType: AgentOutputType) async

    /// AI の質問に回答する
    func reply(_ answer: String)

    /// 割り込みメッセージを送信
    func interrupt(message: String) async

    /// 実行をキャンセル
    func cancel()

    // MARK: - Persistence

    /// セッションを保存
    func save() async throws
}
