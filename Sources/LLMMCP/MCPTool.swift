import Foundation
import LLMClient
import LLMTool

// MARK: - MCPTool

/// MCPサーバーから取得したツール
///
/// Toolプロトコルに準拠しており、通常のツールと同様に使用できます。
/// MCPサーバーへの実行リクエストの転送を担当します。
///
/// ## 内部実装詳細
///
/// このクラスはMCPサーバーから取得したツール定義を保持し、
/// `execute(with:)` 呼び出し時にMCPサーバーへリクエストを転送します。
public final class MCPTool: Tool, @unchecked Sendable {
    // MARK: - Properties

    /// ツール名
    public let toolName: String

    /// ツールの説明
    public let toolDescription: String

    /// 入力スキーマ
    public let inputSchema: JSONSchema

    /// ツールの能力フラグ
    public let capabilities: MCPToolCapabilities

    /// 実行ハンドラー
    private let executeHandler: @Sendable (Data) async throws -> ToolResult

    // MARK: - Initialization

    /// MCPToolを作成
    ///
    /// - Parameters:
    ///   - name: ツール名
    ///   - description: ツールの説明
    ///   - inputSchema: 入力スキーマ
    ///   - capabilities: ツールの能力フラグ
    ///   - executeHandler: 実行ハンドラー
    public init(
        name: String,
        description: String,
        inputSchema: JSONSchema,
        capabilities: MCPToolCapabilities = .default,
        executeHandler: @escaping @Sendable (Data) async throws -> ToolResult
    ) {
        self.toolName = name
        self.toolDescription = description
        self.inputSchema = inputSchema
        self.capabilities = capabilities
        self.executeHandler = executeHandler
    }

    // MARK: - Tool Protocol

    /// ツールを実行
    ///
    /// MCPサーバーへリクエストを転送し、結果を返します。
    ///
    /// - Parameter argumentsData: 引数のJSONデータ
    /// - Returns: ツール実行結果
    /// - Throws: 実行エラー
    public func execute(with argumentsData: Data) async throws -> ToolResult {
        try await executeHandler(argumentsData)
    }
}

// MARK: - MCPTool Creation Helpers

extension MCPTool {
    /// JSON定義からMCPToolを作成
    ///
    /// MCPサーバーから返されたツール定義JSONからMCPToolを生成します。
    ///
    /// - Parameters:
    ///   - json: ツール定義JSON
    ///   - executeHandler: 実行ハンドラー
    /// - Returns: MCPTool、またはパース失敗時はnil
    public static func from(
        json: [String: Any],
        executeHandler: @escaping @Sendable (Data) async throws -> ToolResult
    ) -> MCPTool? {
        guard let name = json["name"] as? String,
              let description = json["description"] as? String else {
            return nil
        }

        // inputSchemaをパース
        let inputSchema: JSONSchema
        if let schemaDict = json["inputSchema"] as? [String: Any] {
            inputSchema = parseJSONSchema(from: schemaDict)
        } else {
            // スキーマがない場合は空のオブジェクト
            inputSchema = .object(properties: [:], required: [])
        }

        // 能力フラグをヒューリスティックに推測
        let capabilities = inferCapabilities(from: name, description: description)

        return MCPTool(
            name: name,
            description: description,
            inputSchema: inputSchema,
            capabilities: capabilities,
            executeHandler: executeHandler
        )
    }

    /// ツール名と説明から能力フラグを推測
    private static func inferCapabilities(from name: String, description: String) -> MCPToolCapabilities {
        let lowercaseName = name.lowercased()
        let lowercaseDesc = description.lowercased()

        // 読み取り専用の判定
        let readOnlyKeywords = ["get", "read", "list", "search", "find", "fetch", "query", "show", "view"]
        let isReadOnly = readOnlyKeywords.contains { lowercaseName.contains($0) || lowercaseName.hasPrefix($0) }

        // 危険な操作の判定
        let dangerousKeywords = ["delete", "remove", "drop", "destroy", "force", "admin", "sudo", "root"]
        let isDangerous = dangerousKeywords.contains { lowercaseName.contains($0) || lowercaseDesc.contains($0) }

        return MCPToolCapabilities(isReadOnly: isReadOnly, isDangerous: isDangerous)
    }

    /// JSON辞書からJSONSchemaを構築
    private static func parseJSONSchema(from dict: [String: Any]) -> JSONSchema {
        guard let type = dict["type"] as? String else {
            return .object(description: nil, properties: [:], required: [])
        }

        switch type {
        case "object":
            var properties: [String: JSONSchema] = [:]
            if let props = dict["properties"] as? [String: [String: Any]] {
                for (key, value) in props {
                    properties[key] = parseJSONSchema(from: value)
                }
            }
            let required = dict["required"] as? [String] ?? []
            let description = dict["description"] as? String
            return .object(description: description, properties: properties, required: required)

        case "string":
            let description = dict["description"] as? String
            if let enumValues = dict["enum"] as? [String] {
                return .string(description: description, enum: enumValues)
            }
            return .string(description: description)

        case "integer":
            let description = dict["description"] as? String
            return .integer(description: description)

        case "number":
            let description = dict["description"] as? String
            return .number(description: description)

        case "boolean":
            let description = dict["description"] as? String
            return .boolean(description: description)

        case "array":
            let description = dict["description"] as? String
            if let items = dict["items"] as? [String: Any] {
                let itemSchema = parseJSONSchema(from: items)
                return .array(description: description, items: itemSchema)
            }
            return .array(description: description, items: .string())

        default:
            return .object(description: nil, properties: [:], required: [])
        }
    }
}
