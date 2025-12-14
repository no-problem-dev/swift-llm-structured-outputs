// MARK: - Macro Declarations

/// 構造化出力に対応した型であることを宣言するマクロ
///
/// このマクロを適用することで、型は自動的に以下の機能を持ちます：
/// - `StructuredProtocol` への準拠
/// - `Codable` と `Sendable` への準拠
/// - `jsonSchema` 静的プロパティの自動生成
///
/// ## 使用例
///
/// ```swift
/// @Structured("ユーザー情報")
/// struct UserInfo {
///     @StructuredField("ユーザー名")
///     var name: String
///
///     @StructuredField("年齢", .minimum(0), .maximum(150))
///     var age: Int
///
///     @StructuredField("メールアドレス", .format(.email))
///     var email: String?
/// }
/// ```
///
/// ## 生成されるJSON Schema
///
/// ```json
/// {
///   "type": "object",
///   "description": "ユーザー情報",
///   "properties": {
///     "name": { "type": "string", "description": "ユーザー名" },
///     "age": { "type": "integer", "description": "年齢", "minimum": 0, "maximum": 150 },
///     "email": { "type": "string", "description": "メールアドレス", "format": "email" }
///   },
///   "required": ["name", "age"],
///   "additionalProperties": false
/// }
/// ```
///
/// - Parameter description: この型の説明（JSON Schemaの description に使用）
@attached(member, names: named(jsonSchema))
@attached(extension, conformances: StructuredProtocol, Codable, Sendable)
public macro Structured(
    _ description: String? = nil
) = #externalMacro(module: "StructuredMacros", type: "StructuredMacro")

/// 構造化出力のフィールドに説明と制約を付与するマクロ
///
/// `@Structured` マクロが適用された型のプロパティに使用します。
/// フィールドの説明と、オプションで制約を指定できます。
///
/// ## 使用例
///
/// ```swift
/// @Structured("商品情報")
/// struct Product {
///     // 説明のみ
///     @StructuredField("商品名")
///     var name: String
///
///     // 説明 + 単一の制約
///     @StructuredField("価格", .minimum(0))
///     var price: Int
///
///     // 説明 + 複数の制約
///     @StructuredField("タグ", .minItems(1), .maxItems(10))
///     var tags: [String]
///
///     // 列挙制約
///     @StructuredField("カテゴリ", .enum(["electronics", "clothing", "food"]))
///     var category: String
///
///     // フォーマット制約
///     @StructuredField("ウェブサイト", .format(.uri))
///     var website: String?
/// }
/// ```
///
/// ## 利用可能な制約
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
///   - description: フィールドの説明
///   - constraints: フィールドに適用する制約（可変長引数）
@attached(peer)
public macro StructuredField(
    _ description: String,
    _ constraints: FieldConstraint...
) = #externalMacro(module: "StructuredMacros", type: "StructuredFieldMacro")

/// String RawValue を持つ enum を構造化出力に対応させるマクロ
///
/// このマクロを適用することで、enum は自動的に以下の機能を持ちます：
/// - `StructuredProtocol` への準拠
/// - `Sendable` への準拠
/// - `jsonSchema` 静的プロパティの自動生成（enum 制約付き string スキーマ）
///
/// ## 使用例
///
/// ```swift
/// @StructuredEnum("ステータス")
/// enum Status: String {
///     case active
///     case inactive
///     case pending
/// }
///
/// // カスタム rawValue を使用
/// @StructuredEnum("優先度")
/// enum Priority: String {
///     case low = "low"
///     case medium = "medium"
///     case high = "high"
///     case critical = "critical"
/// }
/// ```
///
/// ## 生成されるJSON Schema
///
/// ```json
/// {
///   "type": "string",
///   "description": "ステータス",
///   "enum": ["active", "inactive", "pending"]
/// }
/// ```
///
/// ## @Structured との連携
///
/// ```swift
/// @StructuredEnum
/// enum Status: String {
///     case active, inactive
/// }
///
/// @Structured("タスク")
/// struct Task {
///     var title: String
///     var status: Status  // ← 自動的に enum スキーマが展開される
/// }
/// ```
///
/// - Parameter description: この enum の説明（JSON Schemaの description に使用）
@attached(member, names: named(jsonSchema), named(enumDescription))
@attached(extension, conformances: StructuredProtocol, Sendable)
public macro StructuredEnum(
    _ description: String? = nil
) = #externalMacro(module: "StructuredMacros", type: "StructuredEnumMacro")

/// enum のケースに説明を付与するマクロ
///
/// `@StructuredEnum` マクロが適用された enum のケースに使用します。
/// ケースの説明は、LLM へのプロンプト生成時に使用されます。
///
/// ## 使用例
///
/// ```swift
/// @StructuredEnum("タスクの優先度")
/// enum Priority: String {
///     @StructuredCase("緊急ではない、後回しにできるタスク")
///     case low
///
///     @StructuredCase("通常の優先度のタスク")
///     case medium
///
///     @StructuredCase("すぐに対応が必要な緊急タスク")
///     case high
/// }
/// ```
///
/// ## 生成される enumDescription
///
/// ```
/// タスクの優先度:
/// - low: 緊急ではない、後回しにできるタスク
/// - medium: 通常の優先度のタスク
/// - high: すぐに対応が必要な緊急タスク
/// ```
///
/// - Parameter description: ケースの説明（プロンプト生成時に使用）
@attached(peer)
public macro StructuredCase(
    _ description: String
) = #externalMacro(module: "StructuredMacros", type: "StructuredCaseMacro")

// MARK: - Tool Macros

/// LLM から呼び出し可能なツールを定義するマクロ
///
/// このマクロを適用することで、構造体は自動的に以下の機能を持ちます：
/// - `LLMTool` への準拠
/// - `LLMToolRegistrable` への準拠
/// - `toolName` と `toolDescription` の自動生成
/// - `Arguments` 型の自動生成（`@ToolArgument` を持つプロパティから）
/// - `asAnyTool()` メソッドの生成
///
/// ## 使用例
///
/// ```swift
/// @Tool("指定された都市の現在の天気を取得します")
/// struct GetWeather {
///     @ToolArgument("都市名（例: 東京、大阪）")
///     var location: String
///
///     @ToolArgument("温度の単位", .enum(["celsius", "fahrenheit"]))
///     var unit: String?
///
///     func call() async throws -> String {
///         // 天気 API を呼び出す
///         let weather = try await WeatherAPI.fetch(location: location, unit: unit ?? "celsius")
///         return "\(location): \(weather.condition), \(weather.temperature)°"
///     }
/// }
/// ```
///
/// ## ToolSet での使用
///
/// ```swift
/// let tools = ToolSet {
///     GetWeather.self
///     SearchWeb.self
///     Calculator.self
/// }
///
/// let result = try await client.generate(
///     prompt: "東京の天気は？",
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
@attached(extension, conformances: LLMTool, LLMToolRegistrable, Sendable)
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
