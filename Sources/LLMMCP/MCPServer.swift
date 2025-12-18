import Foundation
import LLMClient
import LLMTool

// MARK: - MCPServerProtocol

/// MCPサーバーを表すプロトコル
///
/// MCPサーバーは複数のツールを提供し、それらを動的に取得・実行できます。
/// 外部プロセスやHTTPエンドポイントとの橋渡しを行います。
///
/// ## 使用例
///
/// ```swift
/// let tools = ToolSet {
///     MCPServer(command: "npx", arguments: ["-y", "@anthropic/mcp-server-filesystem", "/path"])
///         .readOnly
///
///     MCPServer(url: URL(string: "http://localhost:8080")!)
///         .including("tool1", "tool2")
/// }
/// ```
public protocol MCPServerProtocol: Sendable {
    /// サーバー名
    var serverName: String { get }

    /// サーバーへの接続設定
    var configuration: MCPConfiguration { get }

    /// ツール選択フィルター
    var toolSelection: MCPToolSelection { get }

    /// 利用可能なツールを取得
    ///
    /// MCPサーバーに接続し、提供されるツールの一覧を取得します。
    /// 取得されたツールは`toolSelection`に基づいてフィルタリングされます。
    ///
    /// - Returns: 利用可能なツールの配列
    /// - Throws: 接続エラーまたはツール取得エラー
    func fetchTools() async throws -> [MCPTool]

    /// ツールを実行
    ///
    /// - Parameters:
    ///   - toolName: 実行するツール名
    ///   - arguments: ツールの引数（JSON形式）
    /// - Returns: ツール実行結果
    /// - Throws: 実行エラー
    func executeTool(named toolName: String, arguments: Data) async throws -> ToolResult
}

// MARK: - MCPAuthorization

/// MCPサーバーへの認証方式
///
/// Streamable HTTP トランスポートで使用される認証設定です。
/// OAuth 2.1 の Bearer トークンが標準的な認証方式です。
///
/// ## 使用例
///
/// ```swift
/// // Bearer トークン認証
/// MCPServer(url: url, authorization: .bearer("your-access-token"))
///
/// // カスタムヘッダー認証
/// MCPServer(url: url, authorization: .header("X-API-Key", "your-api-key"))
/// ```
public enum MCPAuthorization: Sendable {
    /// Bearer トークン認証（OAuth 2.1 標準）
    ///
    /// `Authorization: Bearer <token>` ヘッダーを追加します。
    case bearer(String)

    /// カスタムヘッダー認証
    ///
    /// 指定したヘッダー名と値を追加します。
    case header(String, String)

    /// 複数のカスタムヘッダー
    ///
    /// 複数のヘッダーを追加します。
    case headers([String: String])

    /// 認証なし
    case none

    /// URLRequestに認証ヘッダーを適用
    internal func apply(to request: inout URLRequest) {
        switch self {
        case .bearer(let token):
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .header(let name, let value):
            request.setValue(value, forHTTPHeaderField: name)
        case .headers(let headers):
            for (name, value) in headers {
                request.setValue(value, forHTTPHeaderField: name)
            }
        case .none:
            break
        }
    }
}

// MARK: - MCPConfiguration

/// MCPサーバーの接続設定
public struct MCPConfiguration: Sendable {
    /// トランスポート種別
    public let transport: MCPTransport

    /// 接続タイムアウト（秒）
    public let timeout: TimeInterval

    /// 環境変数
    public let environment: [String: String]

    /// 認証設定（HTTP接続用）
    public let authorization: MCPAuthorization

    public init(
        transport: MCPTransport,
        timeout: TimeInterval = 30,
        environment: [String: String] = [:],
        authorization: MCPAuthorization = .none
    ) {
        self.transport = transport
        self.timeout = timeout
        self.environment = environment
        self.authorization = authorization
    }
}

// MARK: - MCPTransport

/// MCPサーバーへのトランスポート種別
public enum MCPTransport: Sendable {
    /// 標準入出力（stdio）経由
    case stdio(command: String, arguments: [String])

    /// HTTP/SSE 経由
    case http(url: URL)
}

// MARK: - MCPToolSelection

/// MCPサーバーから取得するツールの選択フィルター
public struct MCPToolSelection: Sendable {
    /// 選択モード
    public let mode: Mode

    public enum Mode: Sendable {
        /// すべてのツールを含める
        case all

        /// 指定したツールのみを含める
        case including(Set<String>)

        /// 指定したツールを除外
        case excluding(Set<String>)

        /// プリセット
        case preset(Preset)
    }

    /// プリセット選択
    public enum Preset: Sendable {
        /// 読み取り専用ツールのみ
        case readOnly

        /// 書き込み可能ツールのみ
        case writeOnly

        /// 危険な操作を除外
        case safe
    }

    /// すべてのツールを含める
    public static let all = MCPToolSelection(mode: .all)

    public init(mode: Mode) {
        self.mode = mode
    }

    /// 指定したツールのみを含める
    public static func including(_ toolNames: String...) -> MCPToolSelection {
        MCPToolSelection(mode: .including(Set(toolNames)))
    }

    /// 指定したツールのみを含める
    public static func including(_ toolNames: Set<String>) -> MCPToolSelection {
        MCPToolSelection(mode: .including(toolNames))
    }

    /// 指定したツールを除外
    public static func excluding(_ toolNames: String...) -> MCPToolSelection {
        MCPToolSelection(mode: .excluding(Set(toolNames)))
    }

    /// 指定したツールを除外
    public static func excluding(_ toolNames: Set<String>) -> MCPToolSelection {
        MCPToolSelection(mode: .excluding(toolNames))
    }

    /// 読み取り専用
    public static let readOnly = MCPToolSelection(mode: .preset(.readOnly))

    /// 書き込み可能のみ
    public static let writeOnly = MCPToolSelection(mode: .preset(.writeOnly))

    /// 安全な操作のみ
    public static let safe = MCPToolSelection(mode: .preset(.safe))

    /// ツール名がこの選択に含まれるかどうか
    func includes(toolName: String, capabilities: MCPToolCapabilities) -> Bool {
        switch mode {
        case .all:
            return true
        case .including(let names):
            return names.contains(toolName)
        case .excluding(let names):
            return !names.contains(toolName)
        case .preset(let preset):
            switch preset {
            case .readOnly:
                return capabilities.isReadOnly
            case .writeOnly:
                return !capabilities.isReadOnly
            case .safe:
                return !capabilities.isDangerous
            }
        }
    }
}

// MARK: - MCPToolCapabilities

/// MCPツールの能力フラグ
public struct MCPToolCapabilities: Sendable {
    /// 読み取り専用かどうか
    public let isReadOnly: Bool

    /// 危険な操作かどうか
    public let isDangerous: Bool

    public init(isReadOnly: Bool = false, isDangerous: Bool = false) {
        self.isReadOnly = isReadOnly
        self.isDangerous = isDangerous
    }

    /// デフォルト（読み取り・書き込み可能、安全）
    public static let `default` = MCPToolCapabilities()

    /// 読み取り専用
    public static let readOnly = MCPToolCapabilities(isReadOnly: true)

    /// 危険な操作
    public static let dangerous = MCPToolCapabilities(isDangerous: true)
}

// MARK: - MCPServerProtocol Default Extensions

extension MCPServerProtocol {
    /// フィルタリングされたツールを取得
    public func getFilteredTools() async throws -> [MCPTool] {
        let allTools = try await fetchTools()
        return allTools.filter { tool in
            toolSelection.includes(toolName: tool.toolName, capabilities: tool.capabilities)
        }
    }
}

// MARK: - MCPServer

/// MCPサーバーへの接続を表す具象型
///
/// 外部MCPサーバーに接続し、ツールを取得・実行します。
/// stdioまたはHTTP経由での接続をサポートします。
///
/// ## stdio接続の例
///
/// ```swift
/// let tools = ToolSet {
///     MCPServer(command: "npx", arguments: ["-y", "@anthropic/mcp-server-filesystem", "/path"])
///         .readOnly
/// }
/// ```
///
/// ## HTTP接続の例
///
/// ```swift
/// let tools = ToolSet {
///     MCPServer(url: URL(string: "http://localhost:8080")!)
///         .excluding("dangerous_tool")
/// }
/// ```
public struct MCPServer: MCPServerProtocol {
    // MARK: - Properties

    public let serverName: String
    public let configuration: MCPConfiguration
    public var toolSelection: MCPToolSelection

    /// アダプター作成用のパラメータ
    private enum AdapterConfig: @unchecked Sendable {
        case stdio(command: String, arguments: [String], environment: [String: String])
        case http(url: URL, authorization: MCPAuthorization)
    }

    private let adapterConfig: AdapterConfig

    // MARK: - Initialization (stdio)

    /// stdioトランスポートでMCPサーバーに接続
    ///
    /// - Parameters:
    ///   - command: MCPサーバーのコマンドパス
    ///   - arguments: コマンド引数
    ///   - name: サーバー名（デフォルトはコマンド名）
    ///   - environment: 環境変数
    ///   - timeout: タイムアウト（秒）
    public init(
        command: String,
        arguments: [String] = [],
        name: String? = nil,
        environment: [String: String] = [:],
        timeout: TimeInterval = 30
    ) {
        self.serverName = name ?? URL(fileURLWithPath: command).lastPathComponent
        self.configuration = MCPConfiguration(
            transport: .stdio(command: command, arguments: arguments),
            timeout: timeout,
            environment: environment
        )
        self.toolSelection = .all
        self.adapterConfig = .stdio(command: command, arguments: arguments, environment: environment)
    }

    // MARK: - Initialization (HTTP)

    /// HTTPトランスポート（Streamable HTTP）でMCPサーバーに接続
    ///
    /// リモートMCPサーバーに接続するための標準的な方法です。
    /// OAuth 2.1 Bearer トークン認証をサポートしています。
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// // 認証なし（公開サーバー）
    /// MCPServer(url: URL(string: "https://example.com/mcp")!)
    ///
    /// // Bearer トークン認証
    /// MCPServer(
    ///     url: URL(string: "https://mcp.notion.com/mcp")!,
    ///     authorization: .bearer("ntn_xxxxx")
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - url: MCPサーバーのURL
    ///   - name: サーバー名（デフォルトはホスト名）
    ///   - authorization: 認証設定（デフォルト: なし）
    ///   - timeout: タイムアウト（秒）
    public init(
        url: URL,
        name: String? = nil,
        authorization: MCPAuthorization = .none,
        timeout: TimeInterval = 30
    ) {
        self.serverName = name ?? url.host ?? "http-mcp"
        self.configuration = MCPConfiguration(
            transport: .http(url: url),
            timeout: timeout,
            authorization: authorization
        )
        self.toolSelection = .all
        self.adapterConfig = .http(url: url, authorization: authorization)
    }

    // MARK: - MCPServerProtocol

    public func fetchTools() async throws -> [MCPTool] {
        let adapter = createAdapter()
        defer { Task { await adapter.disconnect() } }

        return try await adapter.listTools()
    }

    public func executeTool(named toolName: String, arguments: Data) async throws -> ToolResult {
        let adapter = createAdapter()
        defer { Task { await adapter.disconnect() } }

        return try await adapter.callTool(name: toolName, arguments: arguments)
    }

    // MARK: - Private

    private func createAdapter() -> SDKClientAdapter {
        switch adapterConfig {
        case .stdio(let command, let arguments, let environment):
            return SDKClientAdapter(command: command, arguments: arguments, environment: environment)
        case .http(let url, let authorization):
            return SDKClientAdapter(url: url, authorization: authorization)
        }
    }
}

// MARK: - MCPServer Fluent API

extension MCPServer {
    /// すべてのツールを含める
    public var all: MCPServer {
        var copy = self
        copy.toolSelection = .all
        return copy
    }

    /// 読み取り専用ツールのみ
    public var readOnly: MCPServer {
        var copy = self
        copy.toolSelection = .readOnly
        return copy
    }

    /// 安全なツールのみ
    public var safe: MCPServer {
        var copy = self
        copy.toolSelection = .safe
        return copy
    }

    /// 指定したツールのみを含める
    public func including(_ toolNames: String...) -> MCPServer {
        var copy = self
        copy.toolSelection = .including(Set(toolNames))
        return copy
    }

    /// 指定したツールのみを含める
    public func including(_ toolNames: Set<String>) -> MCPServer {
        var copy = self
        copy.toolSelection = .including(toolNames)
        return copy
    }

    /// 指定したツールを除外
    public func excluding(_ toolNames: String...) -> MCPServer {
        var copy = self
        copy.toolSelection = .excluding(Set(toolNames))
        return copy
    }

    /// 指定したツールを除外
    public func excluding(_ toolNames: Set<String>) -> MCPServer {
        var copy = self
        copy.toolSelection = .excluding(toolNames)
        return copy
    }
}

// MARK: - MCPServer Presets

extension MCPServer {
    /// Notion MCPサーバーに接続
    ///
    /// Notionの公式ホステッドMCPサーバーに接続します。
    /// Streamable HTTP トランスポートを使用し、Bearer トークン認証を行います。
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// let notion = MCPServer.notion(token: "ntn_xxxxx")
    ///
    /// let tools = ToolSet {
    ///     notion
    /// }
    /// ```
    ///
    /// ## 事前準備
    ///
    /// 1. https://www.notion.so/profile/integrations でインテグレーションを作成
    /// 2. インテグレーションシークレット（`ntn_`で始まる）を取得
    /// 3. 対象のページ/データベースにインテグレーションを接続
    ///
    /// - Parameter token: Notionインテグレーショントークン（`ntn_`で始まる）
    /// - Returns: Notion MCPサーバー
    ///
    /// - SeeAlso: [Notion MCP Documentation](https://developers.notion.com/docs/mcp)
    public static func notion(token: String) -> MCPServer {
        MCPServer(
            url: URL(string: "https://mcp.notion.com/mcp")!,
            name: "notion",
            authorization: .bearer(token)
        )
    }
}

