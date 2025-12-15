import Foundation

// MARK: - AgentExecutionPhase

/// エージェントループの実行フェーズ
///
/// 外部から実行状態を監視するための公開用列挙型です。
internal enum AgentExecutionPhase: Sendable, Equatable {
    /// ツール使用フェーズ
    ///
    /// LLM がツールを呼び出し可能な状態です。
    case toolUse

    /// 最終出力フェーズ
    ///
    /// ツールを無効化し、構造化出力を要求している状態です。
    case finalOutput

    /// ループ完了
    ///
    /// エージェントループが終了した状態です。
    case completed
}

// MARK: - LoopPhase

/// エージェントループの内部フェーズ
///
/// `AgentLoopRunner` が内部的に使用するフェーズ管理用の列挙型です。
internal enum LoopPhase: Sendable, Equatable {
    /// ツール使用フェーズ
    ///
    /// LLM がツールを呼び出し可能。`responseSchema` は送信しない。
    case toolUse

    /// 最終出力フェーズ
    ///
    /// ツールを無効化し、`responseSchema` を送信して構造化出力を要求。
    /// - Parameter retryCount: デコード再試行回数
    case finalOutput(retryCount: Int)

    /// ループ完了
    case completed

    /// 公開用フェーズに変換
    var toPublic: AgentExecutionPhase {
        switch self {
        case .toolUse:
            return .toolUse
        case .finalOutput:
            return .finalOutput
        case .completed:
            return .completed
        }
    }
}

// MARK: - PendingEvent

/// 保留中のイベント
///
/// ツール呼び出しと結果を順次返すためにバッファリングされるイベントです。
internal enum PendingEvent: Sendable {
    /// ツール呼び出しイベント
    case toolCall(ToolCall)

    /// ツール結果イベント
    case toolResult(ToolResponse)
}
