import Foundation

// MARK: - AgentStepSequenceProtocol

/// エージェントループの内部機能を提供するプロトコル
///
/// `AgentStepStream` を継承し、実行フェーズの監視やキャンセル機能など、
/// 内部実装で必要な追加機能を提供します。
///
/// ## 概要
///
/// エージェントループは以下のフェーズを順に遷移します：
///
/// 1. **ツール使用フェーズ** (`toolUse`): LLM がツールを自由に呼び出せる状態
/// 2. **最終出力フェーズ** (`finalOutput`): 構造化 JSON の生成を要求する状態
/// 3. **完了** (`completed`): ループが終了した状態
///
/// ## 実行フェーズの監視
///
/// `currentPhase()` メソッドを使用して、現在の実行フェーズを監視できます。
/// これにより、UI でのプログレス表示やデバッグに活用できます。
///
/// ```swift
/// let phase = await sequence.currentPhase()
/// switch phase {
/// case .toolUse:
///     print("ツール使用中...")
/// case .finalOutput:
///     print("最終出力生成中...")
/// case .completed:
///     print("完了")
/// }
/// ```
///
/// ## キャンセル
///
/// `cancel()` メソッドを呼び出すことで、実行中のループをキャンセルできます。
/// キャンセル後、シーケンスは次のイテレーションで `nil` を返します。
///
/// ## 拡張ポイント
///
/// このプロトコルを実装することで、以下のような拡張が可能です：
///
/// - **ロギングデコレータ**: 各ステップをログに記録
/// - **永続化ラッパー**: ステップ履歴をストレージに保存
/// - **テストモック**: 固定のステップシーケンスを返す
/// - **メトリクス収集**: 実行時間やトークン使用量を計測
///
/// ## プロトコル階層
///
/// ```
/// AgentStepStream (public)        - 外部向け、AsyncSequence のみ
///        ↑
/// AgentStepSequenceProtocol (internal) - 内部向け、監視・制御機能
///        ↑
/// AgentStepSequence (internal)    - 具象実装
/// ```
///
/// - Note: このプロトコルは internal です。外部には `AgentStepStream` のみ公開します。
internal protocol AgentStepSequenceProtocol<Output>: AgentStepStream {
    // MARK: - Properties

    /// エージェントコンテキスト
    ///
    /// メッセージ履歴、システムプロンプト、ツールセット、設定などを含む
    /// エージェントループの状態を管理するコンテキストです。
    ///
    /// - Note: コンテキストは Actor として実装されているため、
    ///         プロパティへのアクセスには `await` が必要です。
    var context: AgentContext { get }

    // MARK: - Phase Monitoring

    /// 現在の実行フェーズを取得
    ///
    /// エージェントループの現在の状態を返します。
    /// UI でのプログレス表示やデバッグに活用できます。
    ///
    /// - Returns: 現在の実行フェーズ
    ///
    /// ## フェーズの遷移
    ///
    /// ```
    /// toolUse → (ツール呼び出し継続) → toolUse
    ///    ↓
    /// (endTurn 受信)
    ///    ↓
    /// finalOutput → (デコード成功) → completed
    ///    ↓
    /// (デコード失敗、リトライ)
    ///    ↓
    /// finalOutput
    /// ```
    func currentPhase() async -> AgentExecutionPhase

    // MARK: - Control

    /// エージェントループをキャンセル
    ///
    /// 実行中のループを中断します。キャンセル後、シーケンスの次のイテレーションで
    /// `nil` が返され、ループが終了します。
    ///
    /// - Note: キャンセルは協調的に行われます。現在実行中の LLM リクエストや
    ///         ツール実行が完了するまで待機する場合があります。
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// Task {
    ///     for try await step in sequence {
    ///         // ステップを処理
    ///     }
    /// }
    ///
    /// // 別のタスクからキャンセル
    /// await sequence.cancel()
    /// ```
    func cancel() async
}

// MARK: - Default Implementations

extension AgentStepSequenceProtocol {
    /// デフォルトのキャンセル実装（何もしない）
    func cancel() async {
        // デフォルトでは何もしない
        // 具象型でオーバーライド可能
    }
}
