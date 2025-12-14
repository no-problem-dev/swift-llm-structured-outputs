import Foundation

// MARK: - ConversationEvent

/// 会話イベント
///
/// 会話中に発生するすべてのイベントを表現します。
/// メッセージの送受信やエラーを統一的に扱うことができます。
public enum ConversationEvent: Sendable {
    /// ユーザーメッセージが送信された
    case userMessage(LLMMessage)

    /// アシスタントからの応答を受信した
    case assistantMessage(LLMMessage)

    /// エラーが発生した
    case error(Error)

    /// 会話がクリアされた
    case cleared
}

// MARK: - Conversation

/// 会話セッションを管理する Actor
///
/// 会話履歴とトークン使用量を自動的に追跡し、
/// マルチターンの会話を簡潔に実装できます。
/// Actor として実装されているため、並行アクセスに対して安全です。
///
/// ## 使用例
///
/// ```swift
/// let client = AnthropicClient(apiKey: "...")
///
/// let conv = Conversation(
///     client: client,
///     model: .sonnet,
///     systemPrompt: "あなたは親切なアシスタントです。"
/// )
///
/// // 最初の質問
/// let city: CityInfo = try await conv.send("日本の首都はどこですか？")
/// print(city.name)  // "東京"
///
/// // 会話を継続（履歴は自動追跡）
/// let population: PopulationInfo = try await conv.send("その都市の人口は？")
/// print(population.count)  // 13960000
///
/// // トークン使用量を確認
/// print(await conv.totalUsage.totalTokens)  // 累計トークン数
/// print(await conv.messages.count)  // 4 (user, assistant, user, assistant)
/// ```
///
/// ## イベントストリーム
///
/// `eventStream` を使用すると、会話中のイベント（メッセージ、エラー等）を
/// AsyncSequence として購読できます：
///
/// ```swift
/// // バックグラウンドでイベントを監視
/// Task {
///     for await event in conv.eventStream {
///         switch event {
///         case .userMessage(let message):
///             print("👤 User: \(message.content)")
///         case .assistantMessage(let message):
///             print("🤖 Assistant: \(message.content)")
///         case .error(let error):
///             print("❌ Error: \(error)")
///         case .cleared:
///             print("🗑️ Conversation cleared")
///         }
///     }
/// }
///
/// // メッセージを送信すると、ストリームにイベントが流れる
/// let result: CityInfo = try await conv.send("日本の首都は？")
/// ```
public actor Conversation<Client: StructuredLLMClient> where Client.Model: Sendable {
    /// LLM クライアント
    private let client: Client

    /// 使用するモデル
    private let model: Client.Model

    /// システムプロンプト
    private let systemPrompt: String?

    /// 温度パラメータ
    private let temperature: Double?

    /// 最大トークン数
    private let maxTokens: Int?

    /// 現在の会話履歴
    ///
    /// ユーザーとアシスタントのメッセージが交互に格納されます。
    public private(set) var messages: [LLMMessage]

    /// 累計トークン使用量
    ///
    /// この会話セッションで使用されたトークンの合計。
    public private(set) var totalUsage: TokenUsage

    /// 送信中フラグ（二重送信防止）
    private var isSending: Bool = false

    /// イベントストリームの継続（AsyncStream 用）
    private var eventContinuation: AsyncStream<ConversationEvent>.Continuation?

    // MARK: - Initializers

    /// 会話セッションを初期化
    ///
    /// - Parameters:
    ///   - client: LLM クライアント
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    public init(
        client: Client,
        model: Client.Model,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.client = client
        self.model = model
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.messages = []
        self.totalUsage = TokenUsage(inputTokens: 0, outputTokens: 0)
    }

    /// 既存の会話履歴から会話セッションを初期化
    ///
    /// - Parameters:
    ///   - client: LLM クライアント
    ///   - model: 使用するモデル
    ///   - messages: 既存の会話履歴
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    public init(
        client: Client,
        model: Client.Model,
        messages: [LLMMessage],
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.client = client
        self.model = model
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.messages = messages
        self.totalUsage = TokenUsage(inputTokens: 0, outputTokens: 0)
    }

    // MARK: - Public Methods

    /// メッセージを送信して構造化出力を取得
    ///
    /// ユーザーメッセージを送信し、アシスタントからの応答を
    /// 指定された型にデコードして返します。
    /// 会話履歴とトークン使用量は自動的に更新されます。
    ///
    /// - Parameter prompt: ユーザーメッセージ
    /// - Returns: 指定された型にデコードされた構造化出力
    /// - Throws: `ConversationError.alreadySending` - 既に送信中の場合
    /// - Throws: `LLMError` - API エラー、デコードエラーなど
    public func send<T: StructuredProtocol>(
        _ prompt: String
    ) async throws -> T {
        guard !isSending else {
            throw ConversationError.alreadySending
        }
        isSending = true
        defer { isSending = false }

        // ユーザーメッセージを追加
        let userMessage = LLMMessage.user(prompt)
        messages.append(userMessage)
        emit(.userMessage(userMessage))

        do {
            // API リクエスト
            let response: ChatResponse<T> = try await client.chat(
                messages: messages,
                model: model,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens
            )

            // アシスタントメッセージを追加
            messages.append(response.assistantMessage)
            emit(.assistantMessage(response.assistantMessage))

            // トークン使用量を累積
            totalUsage = TokenUsage(
                inputTokens: totalUsage.inputTokens + response.usage.inputTokens,
                outputTokens: totalUsage.outputTokens + response.usage.outputTokens
            )

            return response.result
        } catch {
            // エラー時はユーザーメッセージを削除してロールバック
            messages.removeLast()
            emit(.error(error))
            throw error
        }
    }

    /// 詳細な応答を含むメッセージを送信
    ///
    /// 構造化出力に加えて、`ChatResponse` のメタ情報も取得したい場合に使用します。
    ///
    /// - Parameter prompt: ユーザーメッセージ
    /// - Returns: 構造化出力と会話継続情報を含む `ChatResponse`
    /// - Throws: `ConversationError.alreadySending` - 既に送信中の場合
    /// - Throws: `LLMError` - API エラー、デコードエラーなど
    public func sendWithDetails<T: StructuredProtocol>(
        _ prompt: String
    ) async throws -> ChatResponse<T> {
        guard !isSending else {
            throw ConversationError.alreadySending
        }
        isSending = true
        defer { isSending = false }

        // ユーザーメッセージを追加
        let userMessage = LLMMessage.user(prompt)
        messages.append(userMessage)
        emit(.userMessage(userMessage))

        do {
            // API リクエスト
            let response: ChatResponse<T> = try await client.chat(
                messages: messages,
                model: model,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens
            )

            // アシスタントメッセージを追加
            messages.append(response.assistantMessage)
            emit(.assistantMessage(response.assistantMessage))

            // トークン使用量を累積
            totalUsage = TokenUsage(
                inputTokens: totalUsage.inputTokens + response.usage.inputTokens,
                outputTokens: totalUsage.outputTokens + response.usage.outputTokens
            )

            return response
        } catch {
            // エラー時はユーザーメッセージを削除してロールバック
            messages.removeLast()
            emit(.error(error))
            throw error
        }
    }

    /// 会話履歴をクリア
    ///
    /// 会話履歴とトークン使用量をリセットして新しい会話を開始できます。
    /// イベントストリームに `.cleared` イベントが送信されます。
    public func clear() {
        messages = []
        totalUsage = TokenUsage(inputTokens: 0, outputTokens: 0)
        emit(.cleared)
    }

    /// 会話のターン数を取得
    ///
    /// ユーザーとアシスタントのメッセージペア数を返します。
    public var turnCount: Int {
        messages.count / 2
    }

    // MARK: - Event Stream

    /// 会話イベントを購読する AsyncStream
    ///
    /// メッセージの送受信、エラー、会話のクリアなど、
    /// 会話中に発生するすべてのイベントがリアルタイムで流れます。
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// // バックグラウンドでイベントを監視
    /// Task {
    ///     for await event in await conv.eventStream {
    ///         switch event {
    ///         case .userMessage(let message):
    ///             print("👤 User: \(message.content)")
    ///         case .assistantMessage(let message):
    ///             print("🤖 Assistant: \(message.content)")
    ///         case .error(let error):
    ///             print("❌ Error: \(error)")
    ///         case .cleared:
    ///             print("🗑️ Conversation cleared")
    ///         }
    ///     }
    /// }
    ///
    /// // メッセージを送信するとイベントが流れる
    /// let result: CityInfo = try await conv.send("日本の首都は？")
    /// ```
    ///
    /// - Note: 1つの Conversation につき1つのストリームのみ有効です。
    ///   新しいストリームを作成すると、以前のストリームは終了します。
    public var eventStream: AsyncStream<ConversationEvent> {
        // 既存のストリームがあれば終了
        eventContinuation?.finish()

        return AsyncStream { continuation in
            self.eventContinuation = continuation

            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.clearEventContinuation()
                }
            }
        }
    }

    /// イベント継続をクリア
    private func clearEventContinuation() {
        eventContinuation = nil
    }

    /// ストリームにイベントを送信
    private func emit(_ event: ConversationEvent) {
        eventContinuation?.yield(event)
    }
}

// MARK: - ConversationError

/// 会話エラー
public enum ConversationError: Error, Sendable {
    /// 既に送信中
    ///
    /// 前のリクエストが完了する前に新しいリクエストを送信しようとした場合に発生します。
    case alreadySending
}

extension ConversationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .alreadySending:
            return "A message is already being sent. Please wait for the current request to complete."
        }
    }
}
