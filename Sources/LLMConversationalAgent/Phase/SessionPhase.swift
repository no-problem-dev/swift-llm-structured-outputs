import Foundation
import LLMClient

// MARK: - SessionPhase

/// 会話型エージェントセッションのフェーズ（型付き）
///
/// ストリームで流れるイベントを表す型パラメータ付きの enum です。
/// `completed` ケースで構造化された出力を型安全に取得できます。
///
/// - Parameter Output: 構造化出力の型
///
/// ## SessionStatus との違い
///
/// | 型 | 用途 | 型パラメータ |
/// |---|------|------------|
/// | `SessionStatus` | 内部状態 & 公開プロパティ | なし |
/// | `SessionPhase<Output>` | ストリームで流れるイベント | あり |
///
/// ## 使用例
///
/// ```swift
/// @Structured("調査結果")
/// struct ResearchResult {
///     @StructuredField("要約")
///     var summary: String
/// }
///
/// for try await phase in session.run("調査して", model: .sonnet, outputType: ResearchResult.self) {
///     switch phase {
///     case .idle:
///         // 待機状態
///     case .running(let step):
///         // ステップに応じた UI 更新
///         switch step {
///         case .thinking:
///             showProgressIndicator()
///         case .toolCall(let call):
///             showToolExecution(call)
///         // ...
///         }
///     case .awaitingUserInput(let question):
///         // 質問を表示して回答入力フィールドを表示
///     case .paused:
///         // 「再開」ボタンを表示
///     case .completed(let output):
///         // 型安全に構造化された結果を使用
///         print(output.summary)
///     case .failed(let error):
///         // エラーメッセージと「再開」ボタンを表示
///     }
/// }
/// ```
public enum SessionPhase<Output: StructuredProtocol>: Sendable {
    /// 待機中（未開始、完了済み、または clear() 後）
    case idle

    /// 実行中（現在のステップを保持）
    ///
    /// - Parameter step: 現在実行中のステップ
    case running(step: AgentStep)

    /// ユーザーの回答待ち（インタラクティブモード）
    case awaitingUserInput(question: String)

    /// 一時停止（cancel後、再開可能）
    case paused

    /// 正常完了
    ///
    /// - Parameter output: 型安全な構造化出力
    case completed(output: Output)

    /// エラー発生（再開可能）
    case failed(error: String)
}

// MARK: - Equatable

extension SessionPhase: Equatable where Output: Equatable {}

// MARK: - Convenience Properties

extension SessionPhase {
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

    /// 構造化出力（completed の場合のみ）
    public var output: Output? {
        if case .completed(let output) = self {
            return output
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

extension SessionPhase: CustomStringConvertible {
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
        case .completed(let output):
            let outputStr = String(describing: output)
            let truncated = outputStr.prefix(30)
            return "completed(\(truncated)\(outputStr.count > 30 ? "..." : ""))"
        case .failed(let error):
            let truncated = error.prefix(30)
            return "failed(\(truncated)\(error.count > 30 ? "..." : ""))"
        }
    }
}
