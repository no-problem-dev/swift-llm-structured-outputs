import Foundation
import LLMClient
import LLMTool
import MCP

/// MCP SDKのClientをラップし、自前の型に変換するアダプター
///
/// SDKの詳細をカプセル化し、LLMMCPモジュールの公開APIから
/// SDKの型を隠蔽します。
internal actor SDKClientAdapter {
    // MARK: - Properties

    private let client: MCP.Client
    private let transport: any Transport
    private var isConnected = false

    // MARK: - Initialization

    /// stdio接続用のアダプターを作成
    ///
    /// - Parameters:
    ///   - command: MCPサーバーのコマンドパス
    ///   - arguments: コマンド引数
    ///   - environment: 環境変数
    init(
        command: String,
        arguments: [String] = [],
        environment: [String: String] = [:]
    ) {
        self.transport = ProcessTransport(
            command: command,
            arguments: arguments,
            environment: environment
        )
        self.client = MCP.Client(
            name: "swift-llm-structured-outputs",
            version: "1.0.0"
        )
    }

    /// HTTP接続用のアダプターを作成
    ///
    /// - Parameter url: MCPサーバーのURL
    init(url: URL) {
        self.transport = HTTPClientTransport(endpoint: url)
        self.client = MCP.Client(
            name: "swift-llm-structured-outputs",
            version: "1.0.0"
        )
    }

    // MARK: - Connection Management

    /// MCPサーバーに接続
    func connect() async throws {
        guard !isConnected else { return }
        _ = try await client.connect(transport: transport)
        isConnected = true
    }

    /// 接続を切断
    func disconnect() async {
        guard isConnected else { return }
        await client.disconnect()
        isConnected = false
    }

    // MARK: - Tool Operations

    /// 利用可能なツール一覧を取得し、MCPTool型に変換
    ///
    /// - Returns: MCPツールの配列
    func listTools() async throws -> [MCPTool] {
        try await ensureConnected()

        var allTools: [MCP.Tool] = []
        var cursor: String? = nil

        // ページネーションを処理
        repeat {
            let result = try await client.listTools(cursor: cursor)
            allTools.append(contentsOf: result.tools)
            cursor = result.nextCursor
        } while cursor != nil

        // SDK型からMCPTool型に変換
        return allTools.map { sdkTool in
            convertToMCPTool(sdkTool)
        }
    }

    /// ツールを実行し、結果をToolResult型に変換
    ///
    /// - Parameters:
    ///   - name: ツール名
    ///   - arguments: 引数（JSON Data）
    /// - Returns: ツール実行結果
    func callTool(name: String, arguments: Data) async throws -> ToolResult {
        try await ensureConnected()

        // DataをMCP.Valueの辞書に変換
        let valueArguments = try convertDataToValueDict(arguments)

        // ツールを実行
        let result = try await client.callTool(name: name, arguments: valueArguments)

        // 結果をToolResultに変換
        return convertToToolResult(content: result.content, isError: result.isError)
    }

    // MARK: - Private Helpers

    /// 接続されていることを確認
    private func ensureConnected() async throws {
        if !isConnected {
            try await connect()
        }
    }

    /// MCP.ToolをMCPToolに変換
    private func convertToMCPTool(_ sdkTool: MCP.Tool) -> MCPTool {
        // inputSchemaを変換
        let inputSchema = convertValueToJSONSchema(sdkTool.inputSchema)

        // annotationsからcapabilitiesを推測
        let capabilities = MCPToolCapabilities(
            isReadOnly: sdkTool.annotations.readOnlyHint ?? false,
            isDangerous: sdkTool.annotations.destructiveHint ?? false
        )

        // ツール名をキャプチャ（Sendable対応）
        let toolName = sdkTool.name

        return MCPTool(
            name: sdkTool.name,
            description: sdkTool.description ?? "",
            inputSchema: inputSchema,
            capabilities: capabilities
        ) { [weak self] argumentsData in
            guard let self = self else {
                throw MCPError.toolExecutionFailed(toolName: toolName, underlying: NSError(
                    domain: "LLMMCP",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Adapter was deallocated"]
                ))
            }
            return try await self.callTool(name: toolName, arguments: argumentsData)
        }
    }

    /// MCP.ValueをJSONSchemaに変換
    private func convertValueToJSONSchema(_ value: MCP.Value) -> JSONSchema {
        guard case .object(let dict) = value else {
            return .object(properties: [:], required: [])
        }

        // typeを取得
        guard case .string(let typeStr) = dict["type"] else {
            return .object(properties: [:], required: [])
        }

        let description: String?
        if case .string(let desc) = dict["description"] {
            description = desc
        } else {
            description = nil
        }

        switch typeStr {
        case "object":
            var properties: [String: JSONSchema] = [:]
            if case .object(let propsDict) = dict["properties"] {
                for (key, propValue) in propsDict {
                    properties[key] = convertValueToJSONSchema(propValue)
                }
            }

            var required: [String] = []
            if case .array(let reqArray) = dict["required"] {
                for item in reqArray {
                    if case .string(let reqStr) = item {
                        required.append(reqStr)
                    }
                }
            }

            return .object(description: description, properties: properties, required: required)

        case "string":
            var enumValues: [String]? = nil
            if case .array(let enumArray) = dict["enum"] {
                enumValues = enumArray.compactMap { value in
                    if case .string(let str) = value { return str }
                    return nil
                }
            }
            return .string(description: description, enum: enumValues)

        case "integer":
            return .integer(description: description)

        case "number":
            return .number(description: description)

        case "boolean":
            return .boolean(description: description)

        case "array":
            var itemSchema: JSONSchema = .string()
            if let items = dict["items"] {
                itemSchema = convertValueToJSONSchema(items)
            }
            return .array(description: description, items: itemSchema)

        default:
            return .object(description: description, properties: [:], required: [])
        }
    }

    /// DataをMCP.Valueの辞書に変換
    private func convertDataToValueDict(_ data: Data) throws -> [String: MCP.Value]? {
        guard !data.isEmpty else { return nil }

        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard let dict = jsonObject as? [String: Any] else {
            return nil
        }

        return convertAnyToValueDict(dict)
    }

    /// Any型をMCP.Valueの辞書に変換
    private func convertAnyToValueDict(_ dict: [String: Any]) -> [String: MCP.Value] {
        var result: [String: MCP.Value] = [:]
        for (key, value) in dict {
            result[key] = convertAnyToValue(value)
        }
        return result
    }

    /// Any型をMCP.Valueに変換
    private func convertAnyToValue(_ any: Any) -> MCP.Value {
        switch any {
        case let string as String:
            return .string(string)
        case let int as Int:
            return .int(int)
        case let double as Double:
            return .double(double)
        case let bool as Bool:
            return .bool(bool)
        case let array as [Any]:
            return .array(array.map { convertAnyToValue($0) })
        case let dict as [String: Any]:
            return .object(convertAnyToValueDict(dict))
        case is NSNull:
            return .null
        default:
            return .string(String(describing: any))
        }
    }

    /// MCP.Tool.ContentをToolResultに変換
    private func convertToToolResult(content: [MCP.Tool.Content], isError: Bool?) -> ToolResult {
        // 複数のコンテンツを結合
        var textParts: [String] = []

        for item in content {
            switch item {
            case .text(let text):
                textParts.append(text)

            case .image(let data, let mimeType, _):
                // 画像はBase64文字列として含める（将来的にToolResultに画像サポートを追加可能）
                textParts.append("[Image: \(mimeType), \(data.prefix(50))...]")

            case .audio(let data, let mimeType):
                // オーディオはテキストとして表現
                textParts.append("[Audio: \(mimeType), \(data.count) bytes base64]")

            case .resource(let uri, let mimeType, let text):
                if let text = text {
                    textParts.append(text)
                } else {
                    textParts.append("[Resource: \(uri), \(mimeType)]")
                }
            }
        }

        // エラーの場合はエラー結果として返す
        if isError == true {
            return .error(textParts.joined(separator: "\n"))
        }

        return .text(textParts.joined(separator: "\n"))
    }
}
