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
                    public var location: String
                }

                public static var inputSchema: JSONSchema {
                    Arguments.jsonSchema
                }

                public let arguments: Arguments

                public init(arguments: Arguments) {
                    self.arguments = arguments
                    self.location = arguments.location
                }

                public static func execute(with argumentsData: Data) async throws -> ToolResult {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let args = try decoder.decode(Arguments.self, from: argumentsData)
                    let tool = GetWeather(arguments: args)
                    let result = try await tool.call()
                    return try result.toToolResult()
                }
            }

            extension GetWeather: LLMTool, LLMToolRegistrable, Sendable {
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
                    public var expression: String
                }

                public static var inputSchema: JSONSchema {
                    Arguments.jsonSchema
                }

                public let arguments: Arguments

                public init(arguments: Arguments) {
                    self.arguments = arguments
                    self.expression = arguments.expression
                }

                public static func execute(with argumentsData: Data) async throws -> ToolResult {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let args = try decoder.decode(Arguments.self, from: argumentsData)
                    let tool = CalculatorTool(arguments: args)
                    let result = try await tool.call()
                    return try result.toToolResult()
                }
            }

            extension CalculatorTool: LLMTool, LLMToolRegistrable, Sendable {
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

                public let arguments: Arguments

                public init(arguments: Arguments = EmptyArguments()) {
                    self.arguments = arguments
                }

                public static func execute(with argumentsData: Data) async throws -> ToolResult {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let args = try decoder.decode(Arguments.self, from: argumentsData)
                    let tool = GetCurrentTime(arguments: args)
                    let result = try await tool.call()
                    return try result.toToolResult()
                }
            }

            extension GetCurrentTime: LLMTool, LLMToolRegistrable, Sendable {
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
                    public var query: String
                    @StructuredField("最大件数")
                    public var limit: Int
                    @StructuredField("カテゴリ")
                    public var category: String?
                }

                public static var inputSchema: JSONSchema {
                    Arguments.jsonSchema
                }

                public let arguments: Arguments

                public init(arguments: Arguments) {
                    self.arguments = arguments
                    self.query = arguments.query
                    self.limit = arguments.limit
                    self.category = arguments.category
                }

                public static func execute(with argumentsData: Data) async throws -> ToolResult {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let args = try decoder.decode(Arguments.self, from: argumentsData)
                    let tool = SearchProducts(arguments: args)
                    let result = try await tool.call()
                    return try result.toToolResult()
                }
            }

            extension SearchProducts: LLMTool, LLMToolRegistrable, Sendable {
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
                    public var userId: String
                }

                public static var inputSchema: JSONSchema {
                    Arguments.jsonSchema
                }

                public let arguments: Arguments

                public init(arguments: Arguments) {
                    self.arguments = arguments
                    self.userId = arguments.userId
                }

                public static func execute(with argumentsData: Data) async throws -> ToolResult {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let args = try decoder.decode(Arguments.self, from: argumentsData)
                    let tool = GetUserData(arguments: args)
                    let result = try await tool.call()
                    return try result.toToolResult()
                }
            }

            extension GetUserData: LLMTool, LLMToolRegistrable, Sendable {
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
                    public var filePaths: [String]
                }

                public static var inputSchema: JSONSchema {
                    Arguments.jsonSchema
                }

                public let arguments: Arguments

                public init(arguments: Arguments) {
                    self.arguments = arguments
                    self.filePaths = arguments.filePaths
                }

                public static func execute(with argumentsData: Data) async throws -> ToolResult {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let args = try decoder.decode(Arguments.self, from: argumentsData)
                    let tool = ProcessFiles(arguments: args)
                    let result = try await tool.call()
                    return try result.toToolResult()
                }
            }

            extension ProcessFiles: LLMTool, LLMToolRegistrable, Sendable {
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
                    public var query: String
                    @StructuredField("検索結果の最大件数")
                    public var maxResults: Int?
                    @StructuredField("検索対象のドメイン")
                    public var domains: [String]?
                    @StructuredField("安全検索を有効にするか")
                    public var safeSearch: Bool
                }

                public static var inputSchema: JSONSchema {
                    Arguments.jsonSchema
                }

                public let arguments: Arguments

                public init(arguments: Arguments) {
                    self.arguments = arguments
                    self.query = arguments.query
                    self.maxResults = arguments.maxResults
                    self.domains = arguments.domains
                    self.safeSearch = arguments.safeSearch
                }

                public static func execute(with argumentsData: Data) async throws -> ToolResult {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let args = try decoder.decode(Arguments.self, from: argumentsData)
                    let tool = WebSearchTool(arguments: args)
                    let result = try await tool.call()
                    return try result.toToolResult()
                }
            }

            extension WebSearchTool: LLMTool, LLMToolRegistrable, Sendable {
            }
            """,
            macros: toolTestMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
