import Foundation

/// アプリ側の実行状態を表す enum
///
/// UI の状態遷移を管理するために使用する。
enum SessionState: Sendable, Equatable {
    /// 待機中（実行していない）
    case idle

    /// 実行中
    case running

    /// 一時停止中（cancel後、再開可能）
    case paused

    /// 完了（結果を保持）
    case completed

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
    var canResume: Bool {
        switch self {
        case .paused, .error:
            return true
        default:
            return false
        }
    }
}

/// 入力フィールドのモード
enum InputMode {
    /// 通常のプロンプト入力
    case prompt
    /// 実行中（入力不可）
    case interrupt
    /// 一時停止からの再開
    case resume
}
