import Foundation
import LLMClient
import LLMTool
import LLMAgent

// MARK: - ConversationalAgentSessionProtocol

/// 会話型エージェントセッションのプロトコル
///
/// 会話履歴を保持しながらエージェントループを実行し、
/// ユーザーが実行中に割り込みメッセージを送信できる機能を定義します。
///
/// ## 概要
///
/// `ConversationalAgentSessionProtocol` は以下の機能を定義します：
///
/// - **会話履歴の自動管理**: 複数ターンにわたる会話を自動的に追跡
/// - **割り込みサポート**: 実行中のエージェントに新しい指示を注入
/// - **イベントストリーム**: UI 更新用の非同期イベント配信
/// - **柔軟な出力**: ターンごとに異なる構造化出力型を使用可能
///
/// ## 典型的なユースケース
///
/// ### 調査タスクの対話的実行
///
/// ```swift
/// // 1. セッション作成
/// let session = ConversationalAgentSession(
///     client: AnthropicClient(apiKey: "..."),
///     systemPrompt: Prompt { "あなたはリサーチアシスタントです。" },
///     tools: ToolSet {
///         WebSearchTool.self
///         ReadDocumentTool.self
///     }
/// )
///
/// // 2. ストリームを取得（型アノテーションで Output を指定）
/// let stream: some ConversationalAgentStepStream<ResearchResult> = session.run(
///     "AIエージェントについて調査して",
///     model: .sonnet
/// )
///
/// // 3. ストリームをイテレート
/// for try await step in stream {
///     switch step {
///     case .toolCall(let call):
///         print("ツール実行: \(call.name)")
///     case .finalResponse(let output):
///         print("調査結果: \(output)")
///     default:
///         break
///     }
/// }
///
/// // 4. 深掘り依頼（前の会話を自動で保持）
/// let deepDiveStream: some ConversationalAgentStepStream<ResearchResult> = session.run(
///     "それをもうちょっと深掘りして",
///     model: .sonnet
/// )
///
/// // 5. 深掘り結果をイテレート
/// for try await step in deepDiveStream {
///     if case .finalResponse(let output) = step {
///         print("深掘り結果: \(output)")
///     }
/// }
/// ```
///
/// ### 割り込み機能の使用
///
/// エージェント実行中にユーザーが追加の指示を送信できます：
///
/// ```swift
/// // 1. セッションを作成（変数として保持）
/// let session = ConversationalAgentSession(
///     client: client,
///     systemPrompt: Prompt { "あなたはリサーチアシスタントです。" },
///     tools: tools
/// )
///
/// // 2. ストリームを取得
/// let stream: some ConversationalAgentStepStream<ResearchResult> = session.run(
///     "長時間の調査タスク",
///     model: .sonnet
/// )
///
/// // 3. バックグラウンドでイテレート開始
/// let task = Task {
///     for try await step in stream {
///         switch step {
///         case .interrupted(let message):
///             print("⚡ 割り込み処理: \(message)")
///         case .toolCall(let call):
///             print("🔧 ツール実行: \(call.name)")
///         default:
///             break
///         }
///     }
/// }
///
/// // 4. セッションに対して割り込み
/// try await Task.sleep(for: .seconds(2))
/// await session.interrupt("特にセキュリティ面に焦点を当てて")
///
/// // 5. さらに追加指示
/// try await Task.sleep(for: .seconds(3))
/// await session.interrupt("コード例も含めて")
///
/// await task.value
/// ```
///
/// ## イベント監視
///
/// UI 更新やログ記録のためにイベントストリームを監視できます：
///
/// ```swift
/// // イベントを監視するタスク
/// Task {
///     for await event in session.eventStream {
///         switch event {
///         case .userMessage(let msg):
///             updateChatUI(with: msg, isUser: true)
///         case .assistantMessage(let msg):
///             updateChatUI(with: msg, isUser: false)
///         case .interruptQueued(let message):
///             showInterruptNotification(message)
///         case .sessionStarted:
///             showLoadingIndicator()
///         case .sessionCompleted:
///             hideLoadingIndicator()
///         case .error(let error):
///             showError(error)
///         default:
///             break
///         }
///     }
/// }
/// ```
///
/// ## カスタム実装
///
/// テストやカスタム動作のために独自の実装を作成できます：
///
/// ```swift
/// actor MockConversationalAgentSession: ConversationalAgentSessionProtocol {
///     // テスト用のモック実装
/// }
/// ```
///
/// ## スレッドセーフティ
///
/// このプロトコルの実装は `Sendable` に準拠し、
/// 複数のタスクから安全にアクセスできる必要があります。
/// 標準実装の `ConversationalAgentSession` は Actor として実装されています。
public protocol ConversationalAgentSessionProtocol<Client>: Actor {
    /// LLM クライアントの型
    associatedtype Client: AgentCapableClient where Client.Model: Sendable

    // MARK: - Properties

    /// イベントストリーム
    ///
    /// セッションの状態変化を監視するための非同期ストリームです。
    /// UI 更新、ログ記録、分析などに使用できます。
    ///
    /// ## イベントの種類
    ///
    /// - `userMessage`: ユーザーメッセージが履歴に追加された
    /// - `assistantMessage`: アシスタントメッセージが履歴に追加された
    /// - `interruptQueued`: 割り込みメッセージがキューに追加された
    /// - `interruptProcessed`: 割り込みメッセージが処理された
    /// - `sessionStarted`: セッションが開始された
    /// - `sessionCompleted`: セッションが完了した
    /// - `cleared`: 会話履歴がクリアされた
    /// - `error`: エラーが発生した
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// for await event in session.eventStream {
    ///     switch event {
    ///     case .userMessage(let msg):
    ///         print("User: \(msg)")
    ///     case .error(let error):
    ///         print("Error: \(error)")
    ///     default:
    ///         break
    ///     }
    /// }
    /// ```
    nonisolated var eventStream: AsyncStream<ConversationalAgentEvent> { get }

    /// 現在実行中かどうか
    ///
    /// `run()` の実行中は `true` を返します。
    /// 同時に複数の `run()` を実行することはできません。
    var running: Bool { get async }

    /// 現在のターン数
    ///
    /// ユーザーメッセージの数をカウントします。
    /// 割り込みメッセージもターンとしてカウントされます。
    var turnCount: Int { get async }

    // MARK: - Interrupt API

    /// 実行中のエージェントに割り込みメッセージを送信
    ///
    /// 割り込みメッセージは次の LLM 呼び出し前に会話履歴に追加されます。
    /// 複数の割り込みを連続して送信した場合、順番に処理されます。
    ///
    /// - Parameter message: 割り込みメッセージ
    ///
    /// ## 動作
    ///
    /// 1. メッセージが割り込みキューに追加される
    /// 2. `interruptQueued` イベントが発行される
    /// 3. 次の LLM 呼び出し前にメッセージが会話履歴に追加される
    /// 4. `interrupted` ステップがストリームに送信される
    /// 5. LLM は追加されたメッセージを含む履歴で応答を生成する
    ///
    /// ## 注意事項
    ///
    /// - セッションが実行中でない場合、割り込みはキューに保持され、
    ///   次の `run()` 呼び出し時に処理されます
    /// - 割り込みメッセージは通常のユーザーメッセージとして扱われます
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// // エージェント実行中に追加指示を送信
    /// await session.interrupt("特にセキュリティ面に焦点を当てて")
    /// await session.interrupt("コード例も含めて")
    /// ```
    func interrupt(_ message: String) async

    /// 割り込みキューをクリア
    ///
    /// まだ処理されていない割り込みメッセージをすべて削除します。
    /// 既に処理された割り込みには影響しません。
    func clearInterrupts() async

    // MARK: - Session Management

    /// 現在の会話履歴を取得
    ///
    /// セッション内のすべてのメッセージ（ユーザー、アシスタント、ツール結果）を返します。
    ///
    /// - Returns: メッセージ履歴の配列
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// let messages = await session.getMessages()
    /// for message in messages {
    ///     print("\(message.role): \(message.content)")
    /// }
    /// ```
    func getMessages() async -> [LLMMessage]

    /// 会話履歴をクリア
    ///
    /// すべてのメッセージ履歴と割り込みキューを削除します。
    /// 新しい会話を開始する場合に使用します。
    ///
    /// ## 注意事項
    ///
    /// - 実行中のセッションをクリアすると、動作が不安定になる可能性があります
    /// - クリア後は `cleared` イベントが発行されます
    func clear() async

    /// 実行中のセッションをキャンセル
    ///
    /// 実行中のエージェントループを強制的に停止し、セッション状態をリセットします。
    /// 会話履歴は保持されます。
    ///
    /// ## 動作
    ///
    /// 1. 実行フラグ (`running`) を `false` にリセット
    /// 2. 割り込みキューをクリア
    /// 3. `sessionCancelled` イベントを発行
    ///
    /// ## 注意事項
    ///
    /// - キャンセル後も会話履歴は保持されます
    /// - 次の `run()` 呼び出しは正常に開始できます
    /// - 実行中でない場合は何もしません
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// // 停止ボタンが押されたとき
    /// await session.cancel()
    /// ```
    func cancel() async

    // MARK: - User Interaction API

    /// ユーザーの回答を待っているかどうか
    ///
    /// `AskUserTool` が呼び出され、セッションがユーザーの回答を待っている場合に `true` を返します。
    var waitingForAnswer: Bool { get async }

    /// AI の質問に回答する
    ///
    /// `AskUserTool` が呼び出された後、ユーザーの回答を提供します。
    /// 回答はツール結果として AI に渡され、一時停止していたストリームが自動的に再開されます。
    ///
    /// ## 動作
    ///
    /// 1. 回答をツール結果として記録
    /// 2. `userAnswerProvided` イベントを発行
    /// 3. 一時停止していたストリームが自動的に再開
    ///
    /// ## 注意事項
    ///
    /// - `waitingForAnswer` が `false` の場合、この呼び出しは無視されます
    /// - 回答は AI にとってツール実行結果として扱われます
    /// - ストリームは `finalResponse` まで継続します
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// for try await step in session.run("調査して", model: .sonnet) {
    ///     switch step {
    ///     case .askingUser(let question):
    ///         print("❓ \(question)")
    ///     case .awaitingUserInput:
    ///         // ストリームは一時停止中 - ユーザー入力を取得して回答
    ///         let answer = getUserInput()
    ///         await session.reply(answer)
    ///         // ストリームは自動的に再開される
    ///     case .finalResponse(let output):
    ///         print("✅ \(output)")
    ///     default:
    ///         break
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter answer: ユーザーの回答
    func reply(_ answer: String) async

    // MARK: - Core API

    /// ユーザーメッセージを送信してエージェントループを実行
    ///
    /// 会話履歴を保持しながらエージェントループを実行します。
    /// ループはツール呼び出しがなくなるか、構造化出力が得られるまで続きます。
    /// 結果は自動的に会話履歴に追加されます。
    ///
    /// - Parameters:
    ///   - userMessage: ユーザーメッセージ
    ///   - model: 使用するモデル
    ///   - outputType: 期待する出力の型
    /// - Returns: 各ステップを返す `AsyncThrowingStream`
    ///
    /// ## ステップの種類
    ///
    /// - `userMessage`: ユーザーメッセージが送信された
    /// - `thinking`: LLM が思考中
    /// - `toolCall`: ツール呼び出しが要求された
    /// - `toolResult`: ツール実行結果
    /// - `interrupted`: ユーザー割り込みが発生
    /// - `textResponse`: テキスト応答（構造化出力なし）
    /// - `finalResponse`: 最終構造化出力
    ///
    /// ## エラー
    ///
    /// - `sessionAlreadyRunning`: セッションが既に実行中
    /// - `maxStepsExceeded`: 最大ステップ数を超過
    /// - `llmError`: LLM からのエラー
    /// - `toolExecutionFailed`: ツール実行エラー
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// for try await step in session.run(
    ///     "AIエージェントについて調査して",
    ///     model: .sonnet,
    ///     outputType: ResearchResult.self
    /// ) {
    ///     switch step {
    ///     case .userMessage(let msg):
    ///         print("👤 \(msg)")
    ///     case .thinking(let response):
    ///         print("🤔 思考中...")
    ///     case .toolCall(let call):
    ///         print("🔧 \(call.name)")
    ///     case .toolResult(let result):
    ///         print("📄 \(result.output)")
    ///     case .interrupted(let msg):
    ///         print("⚡ \(msg)")
    ///     case .textResponse(let text):
    ///         print("💬 \(text)")
    ///     case .finalResponse(let output):
    ///         print("✅ \(output)")
    ///     }
    /// }
    /// ```
    func run<Output: StructuredProtocol>(
        _ userMessage: String,
        model: Client.Model,
        outputType: Output.Type
    ) -> AsyncThrowingStream<ConversationalAgentStep<Output>, Error>
}

// MARK: - Default Implementation

extension ConversationalAgentSessionProtocol {
    /// 型推論を活用したエージェントループ実行
    ///
    /// `outputType` パラメータを省略し、戻り値の型から `Output` を推論します。
    /// `AgentCapableClient.runAgent` と同じパターンで、型アノテーションにより
    /// 出力型を指定できます。
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
    /// // 型アノテーションで Output を指定
    /// let stream: some ConversationalAgentStepStream<ResearchResult> = session.run(
    ///     "AIエージェントについて調査して",
    ///     model: .sonnet
    /// )
    ///
    /// for try await step in stream {
    ///     if case .finalResponse(let result) = step {
    ///         print(result.summary)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - userMessage: ユーザーメッセージ
    ///   - model: 使用するモデル
    /// - Returns: 各ステップを返す `ConversationalAgentStepStream`
    public func run<Output: StructuredProtocol>(
        _ userMessage: String,
        model: Client.Model
    ) -> some ConversationalAgentStepStream<Output> {
        ConversationalAgentStepSequence(
            stream: run(userMessage, model: model, outputType: Output.self)
        )
    }

}
