import Foundation

/// アプリ側の実行状態を表す enum
///
/// ライブラリの `SessionStatus` とは独立したアプリローカルの状態管理です。
/// UI の状態遷移を管理するために使用します。
enum SessionState: Sendable, Equatable {
    /// 待機中（実行していない）
    case idle

    /// 実行中
    case running

    /// 一時停止中（cancel後、再開可能）
    case paused

    /// 完了（結果文字列を保持）
    case completed(String)

    /// エラー（エラーメッセージを保持）
    case error(String)

    /// 実行中かどうか
    var isRunning: Bool {
        if case .running = self {
            return true
        }
        return false
    }

    /// 一時停止中かどうか
    var isPaused: Bool {
        if case .paused = self {
            return true
        }
        return false
    }

    /// 完了しているかどうか
    var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }

    /// エラーかどうか
    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    /// 再開可能かどうか（paused または error）
    ///
    /// Note: `idle` または `completed` 状態で会話履歴がある場合も再開可能ですが、
    /// その判定は `ActiveSessionState.canResume` で行います。
    var canResume: Bool {
        switch self {
        case .paused, .error:
            return true
        default:
            return false
        }
    }
}
