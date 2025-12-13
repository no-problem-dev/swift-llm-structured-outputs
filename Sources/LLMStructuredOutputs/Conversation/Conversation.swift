import Foundation

// MARK: - Conversation

/// 会話セッションを管理する型
///
/// 会話履歴とトークン使用量を自動的に追跡し、
/// マルチターンの会話を簡潔に実装できます。
///
/// ## 使用例
///
/// ```swift
/// let client = AnthropicClient(apiKey: "...")
///
/// var conv = Conversation(
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
/// print(conv.totalUsage.totalTokens)  // 累計トークン数
/// print(conv.messages.count)  // 4 (user, assistant, user, assistant)
/// ```
///
/// ## 注意事項
/// - この型は `struct` であるため、`send` メソッドは `mutating` です
/// - 並行処理で使用する場合は、適切な同期が必要です
public struct Conversation<Client: StructuredLLMClient>: Sendable where Client.Model: Sendable {
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
    /// - Throws: `LLMError` - API エラー、デコードエラーなど
    public mutating func send<T: StructuredProtocol>(
        _ prompt: String
    ) async throws -> T {
        // ユーザーメッセージを追加
        messages.append(.user(prompt))

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

        // トークン使用量を累積
        totalUsage = TokenUsage(
            inputTokens: totalUsage.inputTokens + response.usage.inputTokens,
            outputTokens: totalUsage.outputTokens + response.usage.outputTokens
        )

        return response.result
    }

    /// 詳細な応答を含むメッセージを送信
    ///
    /// 構造化出力に加えて、`ChatResponse` のメタ情報も取得したい場合に使用します。
    ///
    /// - Parameter prompt: ユーザーメッセージ
    /// - Returns: 構造化出力と会話継続情報を含む `ChatResponse`
    /// - Throws: `LLMError` - API エラー、デコードエラーなど
    public mutating func sendWithDetails<T: StructuredProtocol>(
        _ prompt: String
    ) async throws -> ChatResponse<T> {
        // ユーザーメッセージを追加
        messages.append(.user(prompt))

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

        // トークン使用量を累積
        totalUsage = TokenUsage(
            inputTokens: totalUsage.inputTokens + response.usage.inputTokens,
            outputTokens: totalUsage.outputTokens + response.usage.outputTokens
        )

        return response
    }

    /// 会話履歴をクリア
    ///
    /// 会話履歴とトークン使用量をリセットして新しい会話を開始できます。
    public mutating func clear() {
        messages = []
        totalUsage = TokenUsage(inputTokens: 0, outputTokens: 0)
    }

    /// 会話のターン数を取得
    ///
    /// ユーザーとアシスタントのメッセージペア数を返します。
    public var turnCount: Int {
        messages.count / 2
    }
}
