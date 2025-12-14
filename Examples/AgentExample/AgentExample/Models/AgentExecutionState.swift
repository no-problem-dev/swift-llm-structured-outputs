//
//  AgentExecutionState.swift
//  AgentExample
//
//  エージェント実行状態
//

import Foundation

// MARK: - Agent Step Type

/// エージェントステップの種類
enum AgentStepType {
    case thinking
    case toolCall
    case toolResult
    case finalResponse

    var icon: String {
        switch self {
        case .thinking: return "brain.head.profile"
        case .toolCall: return "wrench.and.screwdriver"
        case .toolResult: return "doc.text"
        case .finalResponse: return "checkmark.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .thinking: return "思考中"
        case .toolCall: return "ツール呼び出し"
        case .toolResult: return "ツール結果"
        case .finalResponse: return "最終レスポンス"
        }
    }
}

// MARK: - Agent Step Info

/// エージェントステップ情報
struct AgentStepInfo: Identifiable {
    let id = UUID()
    let type: AgentStepType
    let content: String
    var detail: String?
    var isError: Bool = false
    let timestamp: Date = Date()
}

// MARK: - Agent Execution State

/// エージェント実行状態
enum AgentExecutionState: Equatable {
    case idle
    case loading
    case success(AgentResult)
    case error(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    var result: AgentResult? {
        if case .success(let result) = self { return result }
        return nil
    }

    var errorMessage: String? {
        if case .error(let message) = self { return message }
        return nil
    }

    var isCancelled: Bool {
        if case .error(let message) = self {
            return message == "キャンセルされました"
        }
        return false
    }

    static var cancelled: AgentExecutionState {
        .error("キャンセルされました")
    }
}
