import Foundation
import LLMClient

// MARK: - ToolSet

/// ツールの集合
///
/// Result Builder を使用して宣言的にツールを構築できます。
/// `Prompt` と同様のパターンで、条件分岐やループもサポートしています。
///
/// ## 使用例
///
/// ```swift
/// let tools = ToolSet {
///     GetWeatherTool.self
///     SearchTool.self
///
///     if needsCalculator {
///         CalculatorTool.self
///     }
///
///     for tool in dynamicTools {
///         tool
///     }
/// }
///
/// let result = try await client.generate(
///     prompt: "東京の天気は？",
///     model: .sonnet,
///     tools: tools
/// )
/// ```
///
/// ## ツールの結合
///
/// ```swift
/// let baseTools = ToolSet {
///     GetWeatherTool.self
///     SearchTool.self
/// }
///
/// let extendedTools = baseTools + CalculatorTool.self
/// // または
/// let extendedTools = baseTools.appending(CalculatorTool.self)
/// ```
public struct ToolSet: Sendable {

    // MARK: - Properties

    /// 内部のツール型配列
    internal let toolTypes: [any LLMToolRegistrable.Type]

    // MARK: - Initializers

    /// Result Builder でツールセットを構築
    ///
    /// - Parameter builder: ツールを構築するクロージャ
    ///
    /// ```swift
    /// let tools = ToolSet {
    ///     GetWeatherTool.self
    ///     SearchTool.self
    /// }
    /// ```
    public init(@ToolSetBuilder _ builder: () -> [any LLMToolRegistrable.Type]) {
        self.toolTypes = builder()
    }

    /// 内部配列から直接初期化（内部使用）
    internal init(toolTypes: [any LLMToolRegistrable.Type]) {
        self.toolTypes = toolTypes
    }

    /// 空の ToolSet を作成
    public init() {
        self.toolTypes = []
    }

    // MARK: - Properties

    /// ツールセットが空かどうか
    public var isEmpty: Bool {
        toolTypes.isEmpty
    }

    /// ツールの数
    public var count: Int {
        toolTypes.count
    }

    /// ツール名のリスト
    public var toolNames: [String] {
        toolTypes.map { $0.toolName }
    }

    // MARK: - Lookup

    /// 名前でツール型を検索
    ///
    /// - Parameter name: ツール名
    /// - Returns: 見つかったツール型
    public func toolType(named name: String) -> (any LLMToolRegistrable.Type)? {
        toolTypes.first { $0.toolName == name }
    }

    /// ツール定義のリストを取得
    public var definitions: [ToolDefinition] {
        toolTypes.map { toolType in
            ToolDefinition(
                name: toolType.toolName,
                description: toolType.toolDescription,
                inputSchema: toolType.inputSchema
            )
        }
    }

    /// 名前でツールを実行
    ///
    /// - Parameters:
    ///   - name: ツール名
    ///   - argumentsData: 引数の JSON データ
    /// - Returns: ツールの実行結果
    /// - Throws: ツールが見つからない場合、または実行エラー
    public func execute(toolNamed name: String, with argumentsData: Data) async throws -> ToolResult {
        guard let toolType = toolType(named: name) else {
            throw ToolExecutionError.toolNotFound(name)
        }
        return try await toolType.execute(with: argumentsData)
    }
}

// MARK: - ToolExecutionError

/// ツール実行時のエラー
public enum ToolExecutionError: Error, LocalizedError {
    /// ツールが見つからない
    case toolNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        }
    }
}

// MARK: - ToolSet Combination

extension ToolSet {
    /// 2つの ToolSet を結合
    ///
    /// - Parameters:
    ///   - lhs: 最初の ToolSet
    ///   - rhs: 追加する ToolSet
    /// - Returns: 結合された ToolSet
    public static func + (lhs: ToolSet, rhs: ToolSet) -> ToolSet {
        ToolSet(toolTypes: lhs.toolTypes + rhs.toolTypes)
    }

    /// ToolSet にツールタイプを追加
    ///
    /// - Parameters:
    ///   - lhs: ToolSet
    ///   - rhs: 追加するツールタイプ
    /// - Returns: ツールが追加された ToolSet
    public static func + <T: LLMToolRegistrable>(lhs: ToolSet, rhs: T.Type) -> ToolSet {
        ToolSet(toolTypes: lhs.toolTypes + [rhs])
    }

    /// 別の ToolSet を追加した新しい ToolSet を返す
    ///
    /// - Parameter other: 追加する ToolSet
    /// - Returns: 結合された ToolSet
    public func appending(_ other: ToolSet) -> ToolSet {
        self + other
    }

    /// ツールタイプを追加した新しい ToolSet を返す
    ///
    /// - Parameter toolType: 追加するツールタイプ
    /// - Returns: ツールが追加された ToolSet
    public func appending<T: LLMToolRegistrable>(_ toolType: T.Type) -> ToolSet {
        self + toolType
    }
}

// MARK: - CustomStringConvertible

extension ToolSet: CustomStringConvertible {
    public var description: String {
        let names = toolNames.joined(separator: ", ")
        return "ToolSet(\(count) tools: \(names))"
    }
}

// MARK: - Provider Format Conversion

extension ToolSet {
    /// Anthropic API 形式に変換
    package func toAnthropicFormat() -> [[String: Any]] {
        toolTypes.map { toolType in
            toolType.toAnthropicFormat()
        }
    }

    /// OpenAI API 形式に変換
    package func toOpenAIFormat() -> [[String: Any]] {
        toolTypes.map { toolType in
            toolType.toOpenAIFormat()
        }
    }

    /// Gemini API 形式に変換
    package func toGeminiFormat() -> [[String: Any]] {
        toolTypes.map { toolType in
            toolType.toGeminiFormat()
        }
    }
}

// MARK: - LLMToolRegistrable Provider Format Extensions

extension LLMToolRegistrable {
    /// Anthropic API 形式に変換
    ///
    /// ```json
    /// {
    ///   "name": "get_weather",
    ///   "description": "Get the weather for a location",
    ///   "input_schema": { ... }
    /// }
    /// ```
    static func toAnthropicFormat() -> [String: Any] {
        var result: [String: Any] = [
            "name": toolName,
            "description": toolDescription
        ]

        // スキーマを辞書に変換
        let adapter = AnthropicSchemaAdapter()
        if let schemaData = try? adapter.adapt(inputSchema).toJSONData(),
           let schemaDict = try? JSONSerialization.jsonObject(with: schemaData) as? [String: Any] {
            result["input_schema"] = schemaDict
        }

        return result
    }

    /// OpenAI API 形式に変換
    ///
    /// ```json
    /// {
    ///   "type": "function",
    ///   "function": {
    ///     "name": "get_weather",
    ///     "description": "Get the weather for a location",
    ///     "strict": true,
    ///     "parameters": { ... }
    ///   }
    /// }
    /// ```
    static func toOpenAIFormat() -> [String: Any] {
        var functionDict: [String: Any] = [
            "name": toolName,
            "description": toolDescription,
            "strict": true
        ]

        // スキーマを辞書に変換
        let adapter = OpenAISchemaAdapter()
        if let schemaData = try? adapter.adapt(inputSchema).toJSONData(),
           let schemaDict = try? JSONSerialization.jsonObject(with: schemaData) as? [String: Any] {
            functionDict["parameters"] = schemaDict
        }

        return [
            "type": "function",
            "function": functionDict
        ]
    }

    /// Gemini API 形式に変換
    ///
    /// ```json
    /// {
    ///   "name": "get_weather",
    ///   "description": "Get the weather for a location",
    ///   "parameters": { ... }
    /// }
    /// ```
    static func toGeminiFormat() -> [String: Any] {
        var result: [String: Any] = [
            "name": toolName,
            "description": toolDescription
        ]

        // スキーマを辞書に変換
        let adapter = GeminiSchemaAdapter()
        if let schemaData = try? adapter.adapt(inputSchema).toJSONData(),
           let schemaDict = try? JSONSerialization.jsonObject(with: schemaData) as? [String: Any] {
            result["parameters"] = schemaDict
        }

        return result
    }
}

// MARK: - LLMToolRegistrable

/// ToolSet に登録可能なツール型が準拠するプロトコル
///
/// `@Tool` マクロによって自動的に準拠が追加されます。
/// このプロトコルは型情報を消去せずにツールのメタ情報と実行機能を提供します。
///
/// ## 使用例（マクロ使用）
///
/// ```swift
/// @Tool("天気を取得します")
/// struct GetWeather {
///     @ToolArgument("都市名")
///     var location: String
///
///     func call() async throws -> String {
///         return "晴れ、25°C"
///     }
/// }
/// // 自動的に LLMToolRegistrable に準拠
/// ```
public protocol LLMToolRegistrable: Sendable {
    /// ツールの識別子
    static var toolName: String { get }

    /// ツールの説明
    static var toolDescription: String { get }

    /// 引数の JSON Schema
    static var inputSchema: JSONSchema { get }

    /// ツールを実行
    ///
    /// - Parameter argumentsData: 引数の JSON データ
    /// - Returns: ツールの実行結果
    /// - Throws: 引数のデコードエラーまたは実行エラー
    static func execute(with argumentsData: Data) async throws -> ToolResult
}
