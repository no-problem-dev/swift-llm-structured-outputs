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
/// - **セッション状態管理**: `SessionStatus` を通じたライフサイクル管理
/// - **型安全なストリーミング**: `SessionPhase<Output>` を通じた型付き出力
/// - **柔軟な出力**: ターンごとに異なる構造化出力型を使用可能
///
/// ## 設計概念
///
/// ### SessionStatus と SessionPhase の違い
///
/// | 型 | 用途 | 型パラメータ |
/// |---|------|------------|
/// | `SessionStatus` | 内部状態 & 公開プロパティ | なし |
/// | `SessionPhase<Output>` | ストリームで流れるイベント | あり |
///
/// `SessionStatus` は Actor の内部状態として保持され、公開プロパティとしても使用します。
/// 型パラメータがないため、異なる Output 型を使う複数ターンでも一貫して使用できます。
///
/// `SessionPhase<Output>` はストリームイベントとして使用し、
/// `completed(output: Output)` で型安全に構造化出力を取得できます。
///
/// ## 典型的なユースケース
///
/// ### 調査タスクの対話的実行
///
/// ```swift
/// @Structured("調査結果")
/// struct ResearchResult {
///     @StructuredField("要約")
///     var summary: String
/// }
///
/// // 1. セッション作成
/// let session = ConversationalAgentSession(
///     client: AnthropicClient(apiKey: "..."),
///     systemPrompt: Prompt { "あなたはリサーチアシスタントです。" },
///     tools: ToolSet {
///         WebSearchTool()
///         ReadDocumentTool()
///     }
/// )
///
/// // 2. ストリームを取得して各フェーズを処理
/// for try await phase in session.run("AIエージェントについて調査して", model: .sonnet, outputType: ResearchResult.self) {
///     switch phase {
///     case .running(let step):
///         switch step {
///         case .toolCall(let call):
///             print("ツール実行: \(call.name)")
///         case .thinking:
///             print("思考中...")
///         default:
///             break
///         }
///     case .completed(let result):
///         // 型安全に ResearchResult を取得
///         print("調査結果: \(result.summary)")
///     default:
///         break
///     }
/// }
///
/// // 3. 深掘り依頼（前の会話を自動で保持）
/// for try await phase in session.run("それをもうちょっと深掘りして", model: .sonnet, outputType: ResearchResult.self) {
///     if case .completed(let result) = phase {
///         print("深掘り結果: \(result.summary)")
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
/// // 2. バックグラウンドでストリームをイテレート
/// let task = Task {
///     for try await phase in session.run("長時間の調査タスク", model: .sonnet, outputType: Result.self) {
///         switch phase {
///         case .running(let step):
///             switch step {
///             case .interrupted(let message):
///                 print("⚡ 割り込み処理: \(message)")
///             case .toolCall(let call):
///                 print("🔧 ツール実行: \(call.name)")
///             default:
///                 break
///             }
///         default:
///             break
///         }
///     }
/// }
///
/// // 3. セッションに対して割り込み
/// try await Task.sleep(for: .seconds(2))
/// await session.interrupt("特にセキュリティ面に焦点を当てて")
///
/// // 4. さらに追加指示
/// try await Task.sleep(for: .seconds(3))
/// await session.interrupt("コード例も含めて")
///
/// await task.value
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

    /// セッションの現在の状態
    ///
    /// セッションのライフサイクルを表す状態です。
    /// UI はこのプロパティを監視して適切な表示を行うことができます。
    ///
    /// ## 状態の種類
    ///
    /// - `idle`: 待機中（未開始、完了済み、または clear() 後）
    /// - `running(step:)`: 実行中（現在のステップを保持）
    /// - `awaitingUserInput(question:)`: ユーザーの回答待ち（インタラクティブモード）
    /// - `paused`: 一時停止（cancel後、再開可能）
    /// - `failed(error:)`: エラー発生（再開可能）
    ///
    /// ## 使用例
    ///
    /// ```swift
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
    var status: SessionStatus { get async }

    /// 現在実行中かどうか
    ///
    /// `status.isActive` と同等です。
    /// `run()` の実行中または `awaitingUserInput` 状態の場合に `true` を返します。
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
    /// 2. 次の LLM 呼び出し前にメッセージが会話履歴に追加される
    /// 3. `running(step: .interrupted(message))` がストリームに送信される
    /// 4. LLM は追加されたメッセージを含む履歴で応答を生成する
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
    /// - `status.canClear` が `true` の場合のみ実行されます
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
    /// 3. `paused` 状態に遷移
    ///
    /// ## 注意事項
    ///
    /// - キャンセル後も会話履歴は保持されます
    /// - 次の `run()` または `resume()` 呼び出しは正常に開始できます
    /// - 実行中でない場合は何もしません
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// // 停止ボタンが押されたとき
    /// await session.cancel()
    /// ```
    func cancel() async

    /// エラー後にセッションを再開
    ///
    /// maxStepsExceeded などのエラーで中断したセッションを再開します。
    /// 不完全な tool_use に対してダミーの tool_result を追加し、
    /// エージェントループを継続します。
    ///
    /// ## 動作
    ///
    /// 1. 不完全な tool_use を検出してダミーの tool_result を追加
    /// 2. ステップカウンタをリセット
    /// 3. エージェントループを再開
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// @Structured("結果")
    /// struct Result {
    ///     @StructuredField("内容")
    ///     var content: String
    /// }
    ///
    /// // エラー発生後に「続ける」ボタンが押されたとき
    /// for try await phase in session.resume(model: .sonnet, outputType: Result.self) {
    ///     switch phase {
    ///     case .running(let step):
    ///         // ステップ処理
    ///     case .completed(let result):
    ///         // 型安全に Result を取得
    ///         print("結果: \(result.content)")
    ///     default:
    ///         break
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - model: 使用するモデル
    ///   - outputType: 期待する出力の型
    /// - Returns: 各フェーズを返す `AsyncThrowingStream`
    nonisolated func resume<Output: StructuredProtocol>(
        model: Client.Model,
        outputType: Output.Type
    ) -> AsyncThrowingStream<SessionPhase<Output>, Error>

    // MARK: - User Interaction API

    /// ユーザーの回答を待っているかどうか
    ///
    /// `status.canReply` と同等です。
    /// インタラクティブモードで AI が質問し、ユーザーの回答を待っている場合に `true` を返します。
    var waitingForAnswer: Bool { get async }

    /// AI の質問に回答する
    ///
    /// インタラクティブモードで AI が質問した後、ユーザーの回答を提供します。
    /// 回答はツール結果として AI に渡され、一時停止していたストリームが自動的に再開されます。
    ///
    /// ## 動作
    ///
    /// 1. 回答をツール結果として記録
    /// 2. `running(step: .userMessage(answer))` がストリームに送信される
    /// 3. 一時停止していたストリームが自動的に再開
    ///
    /// ## 注意事項
    ///
    /// - `waitingForAnswer` が `false` の場合、この呼び出しは無視されます
    /// - 回答は AI にとってツール実行結果として扱われます
    /// - ストリームは `completed` まで継続します
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// @Structured("結果")
    /// struct Result {
    ///     @StructuredField("内容")
    ///     var content: String
    /// }
    ///
    /// for try await phase in session.run("調査して", model: .sonnet, outputType: Result.self) {
    ///     switch phase {
    ///     case .running(let step):
    ///         if case .askingUser(let question) = step {
    ///             print("❓ \(question)")
    ///         }
    ///     case .awaitingUserInput:
    ///         // ストリームは一時停止中 - ユーザー入力を取得して回答
    ///         let answer = getUserInput()
    ///         await session.reply(answer)
    ///         // ストリームは自動的に再開される
    ///     case .completed(let result):
    ///         print("✅ \(result.content)")
    ///     default:
    ///         break
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter answer: ユーザーの回答
    func reply(_ answer: String) async

    // MARK: - Core API

    /// LLM入力を送信してエージェントループを実行
    ///
    /// 会話履歴を保持しながらエージェントループを実行します。
    /// ループはツール呼び出しがなくなるか、構造化出力が得られるまで続きます。
    /// 結果は自動的に会話履歴に追加されます。
    ///
    /// テキストとマルチモーダルコンテンツ（画像、音声、動画）を
    /// 含む入力をサポートします。
    ///
    /// - Parameters:
    ///   - input: LLM 入力（テキスト、画像、音声、動画を含む）
    ///   - model: 使用するモデル
    ///   - outputType: 期待する出力の型
    /// - Returns: 各フェーズを返す `AsyncThrowingStream`
    ///
    /// ## フェーズとステップの種類
    ///
    /// **SessionPhase**:
    /// - `idle`: 待機中
    /// - `running(step:)`: 実行中（AgentStep を含む）
    /// - `awaitingUserInput(question:)`: ユーザー回答待ち
    /// - `paused`: 一時停止
    /// - `completed(output:)`: 正常完了（型安全な出力）
    /// - `failed(error:)`: エラー発生
    ///
    /// **AgentStep** (`running` 中のステップ):
    /// - `userMessage`: ユーザーメッセージが送信された
    /// - `thinking`: LLM が思考中
    /// - `toolCall`: ツール呼び出しが要求された
    /// - `toolResult`: ツール実行結果
    /// - `interrupted`: ユーザー割り込みが発生
    /// - `askingUser`: AI がユーザーに質問中
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
    /// @Structured("調査結果")
    /// struct ResearchResult {
    ///     @StructuredField("要約")
    ///     var summary: String
    /// }
    ///
    /// // テキスト入力
    /// for try await phase in session.run(
    ///     input: "AIエージェントについて調査して",
    ///     model: .sonnet,
    ///     outputType: ResearchResult.self
    /// ) {
    ///     switch phase {
    ///     case .running(let step):
    ///         switch step {
    ///         case .userMessage(let msg):
    ///             print("👤 \(msg)")
    ///         case .thinking:
    ///             print("🤔 思考中...")
    ///         case .toolCall(let call):
    ///             print("🔧 \(call.name)")
    ///         case .toolResult(let result):
    ///             print("📄 \(result.output)")
    ///         case .interrupted(let msg):
    ///             print("⚡ \(msg)")
    ///         case .askingUser(let question):
    ///             print("❓ \(question)")
    ///         }
    ///     case .awaitingUserInput(let question):
    ///         print("回答待ち: \(question)")
    ///     case .completed(let result):
    ///         // 型安全に ResearchResult を取得
    ///         print("✅ \(result.summary)")
    ///     case .failed(let error):
    ///         print("❌ \(error)")
    ///     default:
    ///         break
    ///     }
    /// }
    ///
    /// // マルチモーダル入力
    /// for try await phase in session.run(
    ///     input: LLMInput("この画像を分析して", images: [imageContent]),
    ///     model: .sonnet,
    ///     outputType: ImageAnalysis.self
    /// ) {
    ///     // ...
    /// }
    /// ```
    nonisolated func run<Output: StructuredProtocol>(
        input: LLMInput,
        model: Client.Model,
        outputType: Output.Type
    ) -> AsyncThrowingStream<SessionPhase<Output>, Error>
}
