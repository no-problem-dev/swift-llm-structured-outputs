import Foundation
import LLMClient
import LLMTool

// MARK: - ConversationalAgentStepStream

/// 会話型エージェントループのステップをストリームとして提供するプロトコル
///
/// `ConversationalAgentSession` と連携してツール呼び出しを含むエージェントループを実行し、
/// 各ステップを `AsyncSequence` として返します。
///
/// ## 概要
///
/// このプロトコルは、会話型エージェントループの実行結果を非同期シーケンスとして
/// 取得するための最小限のインターフェースを提供します。
/// 外部からは `for try await` でステップを受け取ることができます。
///
/// ## ステップの種類
///
/// シーケンスから返される `ConversationalAgentStep<Output>` は以下の種類です：
///
/// - `.userMessage(String)`: ユーザーメッセージが送信された
/// - `.thinking(LLMResponse)`: LLM が思考中
/// - `.toolCall(ToolCall)`: LLM がツール呼び出しを要求
/// - `.toolResult(ToolResponse)`: ツール実行結果
/// - `.interrupted(String)`: ユーザー割り込みが発生
/// - `.textResponse(String)`: テキスト応答（構造化出力なし）
/// - `.finalResponse(Output)`: エージェントループ完了、構造化された最終出力
///
/// ## 使用例
///
/// ```swift
/// @Structured("調査結果")
/// struct ResearchResult {
///     @StructuredField("要約")
///     var summary: String
///     @StructuredField("発見事項")
///     var findings: [String]
/// }
///
/// // 1. ストリームを取得（型アノテーションで Output を指定）
/// let stream: some ConversationalAgentStepStream<ResearchResult> = session.run(
///     "AIエージェントについて調査して",
///     model: .sonnet
/// )
///
/// // 2. ストリームをイテレート
/// for try await step in stream {
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
///         print("✅ \(output.summary)")
///     }
/// }
/// ```
///
/// ## スレッドセーフティ
///
/// このプロトコルは `Sendable` に準拠しており、複数のタスクから安全に参照できます。
/// ただし、イテレーション自体は単一のタスクから行う必要があります。
public protocol ConversationalAgentStepStream<Output>: AsyncSequence, Sendable
    where Element == ConversationalAgentStep<Output>
{
    /// 構造化出力の型
    associatedtype Output: StructuredProtocol
}

// MARK: - ConversationalAgentStepSequence

/// 会話型エージェントループのステップシーケンス実装
internal struct ConversationalAgentStepSequence<Output: StructuredProtocol>: ConversationalAgentStepStream {
    typealias Element = ConversationalAgentStep<Output>

    private let stream: AsyncThrowingStream<ConversationalAgentStep<Output>, Error>

    init(stream: AsyncThrowingStream<ConversationalAgentStep<Output>, Error>) {
        self.stream = stream
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: stream.makeAsyncIterator())
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        private var iterator: AsyncThrowingStream<ConversationalAgentStep<Output>, Error>.AsyncIterator

        init(iterator: AsyncThrowingStream<ConversationalAgentStep<Output>, Error>.AsyncIterator) {
            self.iterator = iterator
        }

        mutating func next() async throws -> Element? {
            try await iterator.next()
        }
    }
}
