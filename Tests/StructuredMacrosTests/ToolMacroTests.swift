import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(StructuredMacros)
import StructuredMacros

// @Tool マクロのみを展開（ネストされた @Structured/@StructuredField は展開しない）
// swiftlint:disable:next identifier_name
nonisolated(unsafe) let toolTestMacros: [String: Macro.Type] = [
    "Tool": ToolMacro.self,
    "ToolArgument": ToolArgumentMacro.self,
]
#endif

final class ToolMacroTests: XCTestCase {

    // MARK: - Basic @Tool Tests

    func testBasicToolWithDescription() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Tool("指定された都市の天気を取得します")
            struct GetWeather {
                @ToolArgument("都市名")
                var location: String

                func call() async throws -> String {
                    return "晴れ"
                }
            }
            """,
            expandedSource: """
            struct GetWeather {
                var location: String

                func call() async throws -> String {
                    return "晴れ"
                }

                public static let toolName: String = "get_weather"

                public static let toolDescription: String = "指定された都市の天気を取得します"

                @Structured
                public struct Arguments {
                    @StructuredField("都市名")
                    public var location: String = ""
                }

                public static var inputSchema: JSONSchema {
                    Arguments.jsonSchema
                }

                public var arguments: Arguments

                public init() {
                    // ToolSet 登録時のデフォルト初期化
                    // 実際の引数は execute(with:) で設定される
                    self.location = ""
                    // arguments は execute 時に設定されるため、空の Arguments で初期化
                    self.arguments = Arguments()
                }

                public init(arguments: Arguments) {
                    self.arguments = arguments
                    self.location = arguments.location
                }

                public func execute(with argumentsData: Data) async throws -> ToolResult {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let args = try decoder.decode(Arguments.self, from: argumentsData)
                    var copy = self
                    copy.arguments = args
                    copy.location = args.location
                    let result = try await copy.call()
                    return try result.toToolResult()
                }
            }

            extension GetWeather: Tool, Sendable {
            }
            """,
            macros: toolTestMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testToolWithCustomName() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Tool("計算を実行します", name: "calculator")
            struct CalculatorTool {
                @ToolArgument("計算式")
                var expression: String

                func call() async throws -> String {
                    return "42"
                }
            }
            """,
            expandedSource: """
            struct CalculatorTool {
                var expression: String

                func call() async throws -> String {
                    return "42"
                }

                public static let toolName: String = "calculator"

                public static let toolDescription: String = "計算を実行します"

                @Structured
                public struct Arguments {
                    @StructuredField("計算式")
                    public var expression: String = ""
                }

                public static var inputSchema: JSONSchema {
                    Arguments.jsonSchema
                }

                public var arguments: Arguments

                public init() {
                    // ToolSet 登録時のデフォルト初期化
                    // 実際の引数は execute(with:) で設定される
                    self.expression = ""
                    // arguments は execute 時に設定されるため、空の Arguments で初期化
                    self.arguments = Arguments()
                }

                public init(arguments: Arguments) {
                    self.arguments = arguments
                    self.expression = arguments.expression
                }

                public func execute(with argumentsData: Data) async throws -> ToolResult {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let args = try decoder.decode(Arguments.self, from: argumentsData)
                    var copy = self
                    copy.arguments = args
                    copy.expression = args.expression
                    let result = try await copy.call()
                    return try result.toToolResult()
                }
            }

            extension CalculatorTool: Tool, Sendable {
            }
            """,
            macros: toolTestMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Tool Without Arguments Tests

    func testToolWithoutArguments() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Tool("現在の日時を取得します")
            struct GetCurrentTime {
                func call() async throws -> String {
                    return "2024-01-01T00:00:00Z"
                }
            }
            """,
            expandedSource: """
            struct GetCurrentTime {
                func call() async throws -> String {
                    return "2024-01-01T00:00:00Z"
                }

                public static let toolName: String = "get_current_time"

                public static let toolDescription: String = "現在の日時を取得します"

                public typealias Arguments = EmptyArguments

                public static var inputSchema: JSONSchema {
                    Arguments.jsonSchema
                }

                public var arguments: Arguments

                public init(arguments: Arguments = EmptyArguments()) {
                    self.arguments = arguments
                }

                public func execute(with argumentsData: Data) async throws -> ToolResult {
                    let result = try await self.call()
                    return try result.toToolResult()
                }
            }

            extension GetCurrentTime: Tool, Sendable {
            }
            """,
            macros: toolTestMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Multiple Arguments Tests

    func testToolWithMultipleArguments() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Tool("商品を検索します")
            struct SearchProducts {
                @ToolArgument("検索キーワード")
                var query: String

                @ToolArgument("最大件数")
                var limit: Int

                @ToolArgument("カテゴリ")
                var category: String?

                func call() async throws -> String {
                    return "結果"
                }
            }
            """,
            expandedSource: """
            struct SearchProducts {
                var query: String
                var limit: Int
                var category: String?

                func call() async throws -> String {
                    return "結果"
                }

                public static let toolName: String = "search_products"

                public static let toolDescription: String = "商品を検索します"

                @Structured
                public struct Arguments {
                    @StructuredField("検索キーワード")
                    public var query: String = ""
                    @StructuredField("最大件数")
                    public var limit: Int = 0
                    @StructuredField("カテゴリ")
                    public var category: String? = nil
                }

                public static var inputSchema: JSONSchema {
                    Arguments.jsonSchema
                }

                public var arguments: Arguments

                public init() {
                    // ToolSet 登録時のデフォルト初期化
                    // 実際の引数は execute(with:) で設定される
                    self.query = ""
                    self.limit = 0
                    self.category = nil
                    // arguments は execute 時に設定されるため、空の Arguments で初期化
                    self.arguments = Arguments()
                }

                public init(arguments: Arguments) {
                    self.arguments = arguments
                    self.query = arguments.query
                    self.limit = arguments.limit
                    self.category = arguments.category
                }

                public func execute(with argumentsData: Data) async throws -> ToolResult {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let args = try decoder.decode(Arguments.self, from: argumentsData)
                    var copy = self
                    copy.arguments = args
                    copy.query = args.query
                    copy.limit = args.limit
                    copy.category = args.category
                    let result = try await copy.call()
                    return try result.toToolResult()
                }
            }

            extension SearchProducts: Tool, Sendable {
            }
            """,
            macros: toolTestMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Tool Name Snake Case Conversion Tests

    func testToolNameSnakeCaseConversion() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Tool("ユーザーデータを取得")
            struct GetUserData {
                @ToolArgument("ユーザーID")
                var userId: String

                func call() async throws -> String {
                    return "data"
                }
            }
            """,
            expandedSource: """
            struct GetUserData {
                var userId: String

                func call() async throws -> String {
                    return "data"
                }

                public static let toolName: String = "get_user_data"

                public static let toolDescription: String = "ユーザーデータを取得"

                @Structured
                public struct Arguments {
                    @StructuredField("ユーザーID")
                    public var userId: String = ""
                }

                public static var inputSchema: JSONSchema {
                    Arguments.jsonSchema
                }

                public var arguments: Arguments

                public init() {
                    // ToolSet 登録時のデフォルト初期化
                    // 実際の引数は execute(with:) で設定される
                    self.userId = ""
                    // arguments は execute 時に設定されるため、空の Arguments で初期化
                    self.arguments = Arguments()
                }

                public init(arguments: Arguments) {
                    self.arguments = arguments
                    self.userId = arguments.userId
                }

                public func execute(with argumentsData: Data) async throws -> ToolResult {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let args = try decoder.decode(Arguments.self, from: argumentsData)
                    var copy = self
                    copy.arguments = args
                    copy.userId = args.userId
                    let result = try await copy.call()
                    return try result.toToolResult()
                }
            }

            extension GetUserData: Tool, Sendable {
            }
            """,
            macros: toolTestMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Error Tests

    func testToolErrorOnNonStruct() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Tool("クラスには使えません")
            class NotAStruct {
                func call() async throws -> String {
                    return ""
                }
            }
            """,
            expandedSource: """
            class NotAStruct {
                func call() async throws -> String {
                    return ""
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Tool can only be applied to structs", line: 1, column: 1)
            ],
            macros: toolTestMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Array Argument Tests

    func testToolWithArrayArgument() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Tool("ファイルを処理します")
            struct ProcessFiles {
                @ToolArgument("ファイルパスのリスト")
                var filePaths: [String]

                func call() async throws -> String {
                    return "処理完了"
                }
            }
            """,
            expandedSource: """
            struct ProcessFiles {
                var filePaths: [String]

                func call() async throws -> String {
                    return "処理完了"
                }

                public static let toolName: String = "process_files"

                public static let toolDescription: String = "ファイルを処理します"

                @Structured
                public struct Arguments {
                    @StructuredField("ファイルパスのリスト")
                    public var filePaths: [String] = []
                }

                public static var inputSchema: JSONSchema {
                    Arguments.jsonSchema
                }

                public var arguments: Arguments

                public init() {
                    // ToolSet 登録時のデフォルト初期化
                    // 実際の引数は execute(with:) で設定される
                    self.filePaths = []
                    // arguments は execute 時に設定されるため、空の Arguments で初期化
                    self.arguments = Arguments()
                }

                public init(arguments: Arguments) {
                    self.arguments = arguments
                    self.filePaths = arguments.filePaths
                }

                public func execute(with argumentsData: Data) async throws -> ToolResult {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let args = try decoder.decode(Arguments.self, from: argumentsData)
                    var copy = self
                    copy.arguments = args
                    copy.filePaths = args.filePaths
                    let result = try await copy.call()
                    return try result.toToolResult()
                }
            }

            extension ProcessFiles: Tool, Sendable {
            }
            """,
            macros: toolTestMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Complex Tool Tests

    func testComplexToolWithAllFeatures() throws {
        #if canImport(StructuredMacros)
        assertMacroExpansion(
            """
            @Tool("Web検索を実行します", name: "web_search")
            struct WebSearchTool {
                @ToolArgument("検索クエリ")
                var query: String

                @ToolArgument("検索結果の最大件数")
                var maxResults: Int?

                @ToolArgument("検索対象のドメイン")
                var domains: [String]?

                @ToolArgument("安全検索を有効にするか")
                var safeSearch: Bool

                func call() async throws -> String {
                    return "検索結果"
                }
            }
            """,
            expandedSource: """
            struct WebSearchTool {
                var query: String
                var maxResults: Int?
                var domains: [String]?
                var safeSearch: Bool

                func call() async throws -> String {
                    return "検索結果"
                }

                public static let toolName: String = "web_search"

                public static let toolDescription: String = "Web検索を実行します"

                @Structured
                public struct Arguments {
                    @StructuredField("検索クエリ")
                    public var query: String = ""
                    @StructuredField("検索結果の最大件数")
                    public var maxResults: Int? = nil
                    @StructuredField("検索対象のドメイン")
                    public var domains: [String]? = nil
                    @StructuredField("安全検索を有効にするか")
                    public var safeSearch: Bool = false
                }

                public static var inputSchema: JSONSchema {
                    Arguments.jsonSchema
                }

                public var arguments: Arguments

                public init() {
                    // ToolSet 登録時のデフォルト初期化
                    // 実際の引数は execute(with:) で設定される
                    self.query = ""
                    self.maxResults = nil
                    self.domains = nil
                    self.safeSearch = false
                    // arguments は execute 時に設定されるため、空の Arguments で初期化
                    self.arguments = Arguments()
                }

                public init(arguments: Arguments) {
                    self.arguments = arguments
                    self.query = arguments.query
                    self.maxResults = arguments.maxResults
                    self.domains = arguments.domains
                    self.safeSearch = arguments.safeSearch
                }

                public func execute(with argumentsData: Data) async throws -> ToolResult {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let args = try decoder.decode(Arguments.self, from: argumentsData)
                    var copy = self
                    copy.arguments = args
                    copy.query = args.query
                    copy.maxResults = args.maxResults
                    copy.domains = args.domains
                    copy.safeSearch = args.safeSearch
                    let result = try await copy.call()
                    return try result.toToolResult()
                }
            }

            extension WebSearchTool: Tool, Sendable {
            }
            """,
            macros: toolTestMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
