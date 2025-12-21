import LLMClient

// MARK: - Tool Macros

/// LLM から呼び出し可能なツールを定義するマクロ
///
/// このマクロを適用することで、構造体は自動的に以下の機能を持ちます：
/// - `Tool` への準拠
/// - `toolName` と `toolDescription` の自動生成
/// - `Arguments` 型の自動生成（`@ToolArgument` を持つプロパティから）
/// - `execute(with:)` インスタンスメソッドの生成
///
/// ## 使用例
///
/// ```swift
/// @Tool("指定された都市の現在の天気を取得します")
/// struct GetWeather {
///     // 設定プロパティ（オプショナル）- ツール初期化時に設定
///     var apiKey: String?
///
///     @ToolArgument("都市名（例: 東京、大阪）")
///     var location: String
///
///     @ToolArgument("温度の単位", .enum(["celsius", "fahrenheit"]))
///     var unit: String?
///
///     func call() async throws -> String {
///         // 天気 API を呼び出す
///         let weather = try await WeatherAPI.fetch(
///             location: location,
///             unit: unit ?? "celsius",
///             apiKey: apiKey
///         )
///         return "\(location): \(weather.condition), \(weather.temperature)°"
///     }
/// }
/// ```
///
/// ## ToolSet での使用
///
/// ```swift
/// let tools = ToolSet {
///     GetWeather(apiKey: weatherApiKey)
///     SearchWeb()
///     Calculator()
///
///     if needsAdvancedTools {
///         DataAnalyzer()
///     }
/// }
///
/// let result = try await client.generate(
///     input: "東京の天気は？",
///     model: .sonnet,
///     tools: tools
/// )
/// ```
///
/// ## 引数なしのツール
///
/// ```swift
/// @Tool("現在の日時を取得します")
/// struct GetCurrentTime {
///     // @ToolArgument なし → 引数なしのツールになる
///
///     func call() async throws -> String {
///         return ISO8601DateFormatter().string(from: Date())
///     }
/// }
/// ```
///
/// ## 戻り値の型
///
/// `call()` メソッドの戻り値は `ToolResultConvertible` に準拠した型を使用できます：
/// - `String`: テキストとして返される
/// - `Int`, `Double`, `Bool`: 文字列に変換される
/// - `Array`, `Dictionary`: JSON として返される
/// - `ToolResult`: 直接制御する場合
/// - カスタム型: `ToolResultConvertible` に準拠させる
///
/// - Parameters:
///   - description: ツールの説明。LLM がツールを選択する際に参照します。
///     詳細に記述することで、適切なタイミングでツールが呼び出されやすくなります。
///   - name: ツール名（オプション）。省略時は型名から自動生成されます。
///     `^[a-zA-Z0-9_-]{1,64}$` のパターンに従う必要があります。
@attached(member, names: named(toolName), named(toolDescription), named(inputSchema), named(Arguments), named(arguments), named(init), named(execute))
@attached(extension, conformances: Tool, Sendable)
public macro Tool(
    _ description: String,
    name: String? = nil
) = #externalMacro(module: "StructuredMacros", type: "ToolMacro")

/// ツールの引数を定義するマクロ
///
/// `@Tool` マクロが適用された型のプロパティに使用します。
/// プロパティは自動的にツールの引数として公開されます。
///
/// ## 使用例
///
/// ```swift
/// @Tool("商品を検索します")
/// struct SearchProducts {
///     // 必須の引数
///     @ToolArgument("検索キーワード")
///     var query: String
///
///     // オプショナルな引数
///     @ToolArgument("最大件数", .minimum(1), .maximum(100))
///     var limit: Int?
///
///     // 列挙型の引数
///     @ToolArgument("並び順", .enum(["relevance", "price_asc", "price_desc"]))
///     var sortBy: String?
///
///     func call() async throws -> String {
///         // 検索ロジック
///     }
/// }
/// ```
///
/// ## 利用可能な制約
///
/// `@StructuredField` と同じ制約が使用できます：
///
/// ### 配列制約
/// - `.minItems(n)`: 最小要素数
/// - `.maxItems(n)`: 最大要素数
///
/// ### 数値制約
/// - `.minimum(n)`: 最小値（含む）
/// - `.maximum(n)`: 最大値（含む）
/// - `.exclusiveMinimum(n)`: 最小値（含まない）
/// - `.exclusiveMaximum(n)`: 最大値（含まない）
///
/// ### 文字列制約
/// - `.minLength(n)`: 最小文字数
/// - `.maxLength(n)`: 最大文字数
/// - `.pattern("regex")`: 正規表現パターン
///
/// ### 列挙・フォーマット
/// - `.enum(["a", "b", "c"])`: 許可される値
/// - `.format(.email)`: フォーマット指定
///
/// - Parameters:
///   - description: 引数の説明。LLM が適切な値を生成するために使用します。
///   - constraints: 引数に適用する制約（可変長引数）
@attached(peer)
public macro ToolArgument(
    _ description: String,
    _ constraints: FieldConstraint...
) = #externalMacro(module: "StructuredMacros", type: "ToolArgumentMacro")
