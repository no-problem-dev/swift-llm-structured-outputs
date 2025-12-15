import Foundation

// MARK: - ToolCall

/// ツール呼び出し要求
///
/// LLM がツールを呼び出すことを決定した際の情報を保持します。
/// 呼び出し ID、ツール名、引数データを含み、対応する `ToolResponse` と
/// ID で紐付けられます。
///
/// ## 使用例
///
/// ```swift
/// // ToolCallResponse から取得
/// let plan = try await client.planToolCalls(prompt: "天気を調べて", ...)
/// for call in plan.toolCalls {
///     print("ツール: \(call.name)")
///     let args: MyArgs = try call.decodeArguments(as: MyArgs.self)
///     // ツールを実行...
/// }
///
/// // AgentStep から取得
/// for try await step in client.runAgent(...) {
///     if case .toolCall(let call) = step {
///         print("呼び出し: \(call.name)")
///     }
/// }
/// ```
public struct ToolCall: Sendable {
    /// 呼び出し ID
    ///
    /// ツール実行結果を返す際に、どの呼び出しに対する応答かを
    /// 識別するために使用します。
    public let id: String

    /// ツール名
    public let name: String

    /// 引数データ（JSON 形式）
    public let arguments: Data

    // MARK: - Initializer

    /// ToolCall を初期化
    ///
    /// - Parameters:
    ///   - id: 呼び出し ID
    ///   - name: ツール名
    ///   - arguments: 引数データ（JSON 形式）
    public init(id: String, name: String, arguments: Data) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }

    // MARK: - Decoding

    /// 引数を指定された型にデコード
    ///
    /// - Parameter type: デコード先の型
    /// - Returns: デコードされた引数
    /// - Throws: デコードエラー
    ///
    /// ```swift
    /// struct WeatherArgs: Decodable {
    ///     let location: String
    /// }
    /// let args = try call.decodeArguments(as: WeatherArgs.self)
    /// ```
    public func decodeArguments<T: Decodable>(as type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: arguments)
    }

    /// 引数を辞書形式で取得
    ///
    /// - Returns: 引数の辞書表現
    /// - Throws: JSON パースエラー
    ///
    /// ```swift
    /// let dict = try call.argumentsDictionary()
    /// if let location = dict["location"] as? String {
    ///     print(location)
    /// }
    /// ```
    public func argumentsDictionary() throws -> [String: Any] {
        guard let dict = try JSONSerialization.jsonObject(with: arguments) as? [String: Any] else {
            return [:]
        }
        return dict
    }
}
