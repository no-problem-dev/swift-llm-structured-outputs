import Foundation

// MARK: - ToolCallResponse

/// ツール呼び出し計画レスポンス
///
/// LLM がどのツールをどの引数で呼び出すべきか判断した結果を表します。
/// このレスポンスは計画のみを含み、実際のツール実行は開発者が行います。
/// テキスト応答とツール呼び出し情報の両方を含む場合があります。
///
/// ## 使用例
///
/// ```swift
/// let client = AnthropicClient(apiKey: "...")
///
/// @Tool("天気を取得する")
/// struct GetWeather {
///     @ToolArgument("場所")
///     var location: String
///
///     func call() async throws -> String {
///         // 天気API呼び出し
///         return "晴れ、25度"
///     }
/// }
///
/// let tools = ToolSet {
///     GetWeather.self
/// }
///
/// // LLM にどのツールを呼ぶべきか計画させる
/// let plan = try await client.planToolCalls(
///     prompt: "東京の天気を教えて",
///     model: .sonnet,
///     tools: tools
/// )
///
/// // 計画されたツール呼び出しを実行
/// for call in plan.toolCalls {
///     let result = try await tools.execute(toolNamed: call.name, with: call.arguments)
///     print(result)
/// }
/// ```
public struct ToolCallResponse: Sendable {
    /// ツール呼び出し情報のリスト
    public let toolCalls: [ToolCall]

    /// テキスト応答（ある場合）
    public let text: String?

    /// トークン使用量
    public let usage: TokenUsage

    /// 停止理由
    public let stopReason: LLMResponse.StopReason?

    /// 使用されたモデルID
    public let model: String

    /// ツール呼び出しがあるかどうか
    public var hasToolCalls: Bool {
        !toolCalls.isEmpty
    }

    // MARK: - Initializer

    /// ToolCallResponse を初期化
    ///
    /// - Parameters:
    ///   - toolCalls: ツール呼び出し情報のリスト
    ///   - text: テキスト応答
    ///   - usage: トークン使用量
    ///   - stopReason: 停止理由
    ///   - model: 使用されたモデルID
    public init(
        toolCalls: [ToolCall],
        text: String?,
        usage: TokenUsage,
        stopReason: LLMResponse.StopReason?,
        model: String
    ) {
        self.toolCalls = toolCalls
        self.text = text
        self.usage = usage
        self.stopReason = stopReason
        self.model = model
    }
}

// MARK: - ToolCall

/// 単一のツール呼び出し情報
public struct ToolCall: Sendable {
    /// ツール呼び出しID（レスポンス送信時に必要）
    public let id: String

    /// ツール名
    public let name: String

    /// 引数データ（JSON形式）
    public let arguments: Data

    /// ツール呼び出し情報を初期化
    ///
    /// - Parameters:
    ///   - id: ツール呼び出しID
    ///   - name: ツール名
    ///   - arguments: 引数データ
    public init(id: String, name: String, arguments: Data) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }

    /// 引数を指定された型にデコード
    ///
    /// - Parameter type: デコード先の型
    /// - Returns: デコードされた引数
    /// - Throws: デコードエラー
    public func decodeArguments<T: Decodable>(as type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: arguments)
    }

    /// 引数を辞書形式で取得
    ///
    /// - Returns: 引数の辞書表現
    /// - Throws: JSON パースエラー
    public func argumentsDictionary() throws -> [String: Any] {
        guard let dict = try JSONSerialization.jsonObject(with: arguments) as? [String: Any] else {
            return [:]
        }
        return dict
    }
}
