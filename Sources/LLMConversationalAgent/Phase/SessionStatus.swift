import Foundation

// MARK: - SessionStatus

/// 会話型エージェントセッションの状態
///
/// セッションの現在の状態を表す型パラメータなしの enum です。
/// Actor 内部の状態管理および外部公開プロパティとして使用します。
///
/// 型付きの出力を含む `SessionPhase<Output>` とは異なり、
/// この型は出力の型情報を持たないため、セッション全体で一貫して使用できます。
///
/// ## 状態遷移図
///
/// ```
/// idle ─────── run() ────→ running(step:)
///    │                          │
///    │                          ├── (ステップ更新) ──→ running(step:)
///    │                          │
///    │                          ├── cancel() ──────→ paused
///    │                          │
///    │                          ├── ask_user ─────→ awaitingUserInput
///    │                          │                         │
///    │                          │                         ├── reply() → running
///    │                          │                         └── cancel() → paused
///    │                          │
///    │                          ├── 正常完了 ─────→ idle
///    │                          │
///    │                          └── エラー ────────→ failed
///    │
///    └─ resume() ─→ running (会話履歴がある場合のみ)
///
/// paused ────── resume() ───→ running(step:)
///          └── clear() ────→ idle
///
/// failed ────── resume() ───→ running(step:)
///          └── clear() ────→ idle
/// ```
///
/// ## 使用例
///
/// ```swift
/// // セッションの状態を確認
/// if await session.status.canRun {
///     // 新しいターンを開始可能
/// }
///
/// // 状態に応じた UI 更新
/// switch await session.status {
/// case .idle:
///     showStartButton()
/// case .running(let step):
///     showProgressIndicator()
///     updateStepDisplay(step)
/// case .awaitingUserInput(let question):
///     showQuestionUI(question)
/// case .paused:
///     showResumeButton()
/// case .failed(let error):
///     showError(error)
/// }
/// ```
public enum SessionStatus: Sendable, Equatable {
    /// 待機中（未開始、完了済み、または clear() 後）
    ///
    /// 許可される操作: `run()`
    case idle

    /// 実行中（現在のステップを保持）
    ///
    /// 許可される操作: `interrupt()`, `cancel()`
    ///
    /// - Parameter step: 現在実行中のステップ
    case running(step: AgentStep)

    /// ユーザーの回答待ち（インタラクティブモード）
    ///
    /// 許可される操作: `reply()`, `cancel()`
    case awaitingUserInput(question: String)

    /// 一時停止（cancel後、再開可能）
    ///
    /// 許可される操作: `resume()`, `clear()`
    case paused

    /// エラー発生（再開可能）
    ///
    /// 許可される操作: `resume()`, `clear()`
    case failed(error: String)
}

// MARK: - Convenience Properties

extension SessionStatus {
    /// セッションが実行中かどうか
    ///
    /// `running` または `awaitingUserInput` の場合に `true`
    public var isActive: Bool {
        switch self {
        case .running, .awaitingUserInput:
            return true
        default:
            return false
        }
    }

    /// 実行中かどうか（`running` の場合のみ）
    public var isRunning: Bool {
        if case .running = self {
            return true
        }
        return false
    }

    /// `run()` が呼び出し可能かどうか
    public var canRun: Bool {
        if case .idle = self {
            return true
        }
        return false
    }

    /// `resume()` が呼び出し可能かどうか
    ///
    /// `idle`、`paused`、`failed` の場合に `true`。
    /// `idle` 状態で `resume()` を呼ぶ場合、会話履歴が必要です。
    public var canResume: Bool {
        switch self {
        case .idle, .paused, .failed:
            return true
        default:
            return false
        }
    }

    /// `interrupt()` が呼び出し可能かどうか
    public var canInterrupt: Bool {
        if case .running = self {
            return true
        }
        return false
    }

    /// `reply()` が呼び出し可能かどうか
    public var canReply: Bool {
        if case .awaitingUserInput = self {
            return true
        }
        return false
    }

    /// `cancel()` が呼び出し可能かどうか
    public var canCancel: Bool {
        switch self {
        case .running, .awaitingUserInput:
            return true
        default:
            return false
        }
    }

    /// `clear()` が呼び出し可能かどうか
    public var canClear: Bool {
        switch self {
        case .paused, .failed:
            return true
        default:
            return false
        }
    }

    /// 現在のステップ（running の場合のみ）
    public var currentStep: AgentStep? {
        if case .running(let step) = self {
            return step
        }
        return nil
    }

    /// 質問文字列（awaitingUserInput の場合のみ）
    public var question: String? {
        if case .awaitingUserInput(let question) = self {
            return question
        }
        return nil
    }

    /// エラー文字列（failed の場合のみ）
    public var error: String? {
        if case .failed(let error) = self {
            return error
        }
        return nil
    }
}

// MARK: - CustomStringConvertible

extension SessionStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .idle:
            return "idle"
        case .running(let step):
            return "running(\(step))"
        case .awaitingUserInput(let question):
            let truncated = question.prefix(30)
            return "awaitingUserInput(\(truncated)\(question.count > 30 ? "..." : ""))"
        case .paused:
            return "paused"
        case .failed(let error):
            let truncated = error.prefix(30)
            return "failed(\(truncated)\(error.count > 30 ? "..." : ""))"
        }
    }
}
