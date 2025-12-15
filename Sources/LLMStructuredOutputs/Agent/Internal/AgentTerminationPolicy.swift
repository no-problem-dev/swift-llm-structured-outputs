import Foundation

// MARK: - TerminationDecision

/// エージェントループの終了判定結果
///
/// `AgentTerminationPolicy` が LLM レスポンスを評価した結果を表します。
internal enum TerminationDecision: Sendable {
    /// ツール呼び出しを処理してループを継続
    case continueWithTools([ToolCall])

    /// テキスト応答を処理してループを継続（次のステップで再評価）
    case continueWithThinking

    /// 指定されたテキストを最終出力としてデコードを試行し、ループを終了
    case terminateWithOutput(String)

    /// 即座にループを終了（エラーまたは強制終了）
    case terminateImmediately(TerminationReason)
}

// MARK: - TerminationReason

/// ループ終了の理由
internal enum TerminationReason: Sendable, Equatable {
    /// 正常終了（出力なし）
    case completed

    /// 最大ステップ数に到達
    case maxStepsReached(Int)

    /// 重複するツール呼び出しを検出
    case duplicateToolCallDetected(toolName: String, count: Int)

    /// 同一ツールの呼び出し回数上限に到達
    case maxToolCallsPerToolReached(toolName: String, count: Int)

    /// 予期しない停止理由
    case unexpectedStopReason(String?)

    /// 空のレスポンス
    case emptyResponse
}

// MARK: - AgentLoopContext

/// 終了ポリシーに渡されるループコンテキスト
///
/// ループの現在状態を読み取り専用で提供します。
internal protocol AgentLoopContext: Sendable {
    /// 現在のステップ数
    var currentStep: Int { get async }

    /// 最大ステップ数
    var maxSteps: Int { get async }

    /// ステップ上限に達しているか
    var isAtStepLimit: Bool { get async }

    /// 指定ツールの呼び出し回数をカウント
    func countToolCalls(named name: String) async -> Int

    /// 重複するツール呼び出し（同名・同入力）をカウント
    func countDuplicateToolCalls(name: String, inputHash: Int) async -> Int
}

// MARK: - AgentTerminationPolicy

/// エージェントループの終了条件を判定するポリシー
///
/// LLM からのレスポンスを評価し、ループを継続するか終了するかを決定します。
/// このプロトコルを実装することで、カスタムの終了条件を定義できます。
///
/// ## 実装例
///
/// ```swift
/// struct CustomTerminationPolicy: AgentTerminationPolicy {
///     func shouldTerminate(
///         response: LLMResponse,
///         context: AgentLoopContext
///     ) async -> TerminationDecision {
///         // カスタムロジック
///         if response.stopReason == .endTurn {
///             return .terminateWithOutput(response.textContent ?? "")
///         }
///         return .continueWithThinking
///     }
/// }
/// ```
internal protocol AgentTerminationPolicy: Sendable {
    /// レスポンスを評価し、ループを終了すべきか判定
    ///
    /// - Parameters:
    ///   - response: LLM からのレスポンス
    ///   - context: 現在のループコンテキスト
    /// - Returns: 終了判定結果
    func shouldTerminate(
        response: LLMResponse,
        context: any AgentLoopContext
    ) async -> TerminationDecision
}

// MARK: - StandardTerminationPolicy

/// 標準的な終了ポリシー
///
/// Anthropic 推奨パターンに準拠した終了判定を行います：
/// - `stopReason == .toolUse`: ツール呼び出しを処理して継続
/// - `stopReason == .endTurn`: テキスト出力で終了を試行
/// - その他: 即座に終了
internal struct StandardTerminationPolicy: AgentTerminationPolicy {

    func shouldTerminate(
        response: LLMResponse,
        context: any AgentLoopContext
    ) async -> TerminationDecision {
        // 1. ステップ上限チェック
        if await context.isAtStepLimit {
            let maxSteps = await context.maxSteps
            return .terminateImmediately(.maxStepsReached(maxSteps))
        }

        // 2. stopReason に基づく判定
        switch response.stopReason {
        case .toolUse:
            // ツール呼び出しを抽出して継続
            let toolCalls = response.extractToolCalls()
            if toolCalls.isEmpty {
                // stopReason が toolUse なのにツール呼び出しがない（異常ケース）
                return .terminateImmediately(.unexpectedStopReason("tool_use without tool calls"))
            }
            return .continueWithTools(toolCalls)

        case .endTurn:
            // Gemini など一部のプロバイダーは関数呼び出しでも STOP (endTurn) を返す
            // まずツール呼び出しがあるかチェック
            let toolCallsInEndTurn = response.extractToolCalls()
            if !toolCallsInEndTurn.isEmpty {
                return .continueWithTools(toolCallsInEndTurn)
            }
            // テキスト出力で終了を試行
            if let textContent = response.extractTextContent(), !textContent.isEmpty {
                return .terminateWithOutput(textContent)
            }
            // テキストがない場合は正常終了
            return .terminateImmediately(.completed)

        case .maxTokens:
            // トークン上限に達した場合、テキストがあれば出力試行
            if let textContent = response.extractTextContent(), !textContent.isEmpty {
                return .terminateWithOutput(textContent)
            }
            return .terminateImmediately(.unexpectedStopReason("max_tokens"))

        case .stopSequence:
            // 停止シーケンスに達した場合
            if let textContent = response.extractTextContent(), !textContent.isEmpty {
                return .terminateWithOutput(textContent)
            }
            return .terminateImmediately(.completed)

        case nil:
            // stopReason がない場合（異常ケース）
            // ツール呼び出しがあればそれを処理
            let toolCalls = response.extractToolCalls()
            if !toolCalls.isEmpty {
                return .continueWithTools(toolCalls)
            }
            // テキストがあれば出力試行
            if let textContent = response.extractTextContent(), !textContent.isEmpty {
                return .terminateWithOutput(textContent)
            }
            return .terminateImmediately(.emptyResponse)
        }
    }
}

// MARK: - DuplicateDetectionPolicy

/// 重複するツール呼び出しを検出して終了させるポリシー
///
/// ベースポリシーをラップし、以下の条件でループを終了させます：
/// 1. 同じツールが同じ引数で指定回数以上呼ばれた場合
/// 2. 同じツールが（異なる引数でも）指定回数以上呼ばれた場合
internal struct DuplicateDetectionPolicy: AgentTerminationPolicy {
    /// ベースとなる終了ポリシー
    private let basePolicy: any AgentTerminationPolicy

    /// 重複として検出するまでの呼び出し回数（同一ツール・同一入力）
    private let maxDuplicates: Int

    /// 同一ツールの最大呼び出し回数（異なる引数でも）
    private let maxToolCallsPerTool: Int?

    /// 初期化
    ///
    /// - Parameters:
    ///   - basePolicy: ベースとなる終了ポリシー
    ///   - maxDuplicates: 重複として検出するまでの呼び出し回数（デフォルト: 2）
    ///   - maxToolCallsPerTool: 同一ツールの最大呼び出し回数（nil で無制限）
    init(
        basePolicy: any AgentTerminationPolicy = StandardTerminationPolicy(),
        maxDuplicates: Int = 2,
        maxToolCallsPerTool: Int? = 5
    ) {
        self.basePolicy = basePolicy
        self.maxDuplicates = maxDuplicates
        self.maxToolCallsPerTool = maxToolCallsPerTool
    }

    func shouldTerminate(
        response: LLMResponse,
        context: any AgentLoopContext
    ) async -> TerminationDecision {
        // まずベースポリシーで判定
        let decision = await basePolicy.shouldTerminate(response: response, context: context)

        // ツール継続の場合のみ重複チェック
        guard case .continueWithTools(let calls) = decision else {
            return decision
        }

        // 各ツール呼び出しをチェック
        for call in calls {
            // 1. 同一ツールの総呼び出し回数チェック
            if let maxPerTool = maxToolCallsPerTool {
                let totalCount = await context.countToolCalls(named: call.name)
                if totalCount >= maxPerTool {
                    return .terminateImmediately(
                        .maxToolCallsPerToolReached(
                            toolName: call.name,
                            count: totalCount + 1
                        )
                    )
                }
            }

            // 2. 同一入力の重複チェック
            let inputHash = call.arguments.hashValue
            let duplicateCount = await context.countDuplicateToolCalls(
                name: call.name,
                inputHash: inputHash
            )

            if duplicateCount >= maxDuplicates {
                return .terminateImmediately(
                    .duplicateToolCallDetected(
                        toolName: call.name,
                        count: duplicateCount + 1
                    )
                )
            }
        }

        return decision
    }
}

// MARK: - CompositeTerminationPolicy

/// 複数のポリシーを組み合わせるポリシー
///
/// 最初に終了判定を返したポリシーの結果を採用します。
internal struct CompositeTerminationPolicy: AgentTerminationPolicy {
    private let policies: [any AgentTerminationPolicy]

    init(policies: [any AgentTerminationPolicy]) {
        self.policies = policies
    }

    func shouldTerminate(
        response: LLMResponse,
        context: any AgentLoopContext
    ) async -> TerminationDecision {
        for policy in policies {
            let decision = await policy.shouldTerminate(response: response, context: context)

            // 終了判定が出たらそれを採用
            switch decision {
            case .terminateWithOutput, .terminateImmediately:
                return decision
            case .continueWithTools, .continueWithThinking:
                continue
            }
        }

        // どのポリシーも終了判定を出さなかった場合
        // 最後のポリシーの結果を返す（通常はここには来ない）
        if let lastPolicy = policies.last {
            return await lastPolicy.shouldTerminate(response: response, context: context)
        }

        return .terminateImmediately(.completed)
    }
}

// MARK: - Default Policy Factory

/// デフォルトの終了ポリシーを作成
///
/// 標準ポリシーに重複検出を組み込んだポリシーを返します。
internal enum TerminationPolicyFactory {
    /// デフォルトポリシーを作成
    ///
    /// - Parameters:
    ///   - maxDuplicates: 重複として検出するまでの呼び出し回数
    ///   - maxToolCallsPerTool: 同一ツールの最大呼び出し回数（nil で無制限）
    /// - Returns: 重複検出付きの標準ポリシー
    static func makeDefault(
        maxDuplicates: Int = 2,
        maxToolCallsPerTool: Int? = 5
    ) -> any AgentTerminationPolicy {
        DuplicateDetectionPolicy(
            basePolicy: StandardTerminationPolicy(),
            maxDuplicates: maxDuplicates,
            maxToolCallsPerTool: maxToolCallsPerTool
        )
    }

    /// 設定から作成
    static func make(from configuration: AgentConfiguration) -> any AgentTerminationPolicy {
        DuplicateDetectionPolicy(
            basePolicy: StandardTerminationPolicy(),
            maxDuplicates: configuration.maxDuplicateToolCalls,
            maxToolCallsPerTool: configuration.maxToolCallsPerTool
        )
    }

    /// 標準ポリシーのみを作成（重複検出なし）
    static func makeStandard() -> any AgentTerminationPolicy {
        StandardTerminationPolicy()
    }
}

// MARK: - LLMResponse Extensions

extension LLMResponse {
    /// ツール呼び出し情報を抽出
    internal func extractToolCalls() -> [ToolCall] {
        content.compactMap { block in
            guard case .toolUse(let id, let name, let input) = block else {
                return nil
            }
            return ToolCall(id: id, name: name, arguments: input)
        }
    }

    /// テキストコンテンツを抽出
    internal func extractTextContent() -> String? {
        let text = content.compactMap { block -> String? in
            if case .text(let value) = block {
                return value
            }
            return nil
        }.joined()

        return text.isEmpty ? nil : text
    }
}
