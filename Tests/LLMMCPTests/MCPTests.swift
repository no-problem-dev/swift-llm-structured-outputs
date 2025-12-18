import XCTest
@testable import LLMMCP
import LLMClient
import LLMTool

final class MCPTests: XCTestCase {

    // MARK: - MCPServer Initialization Tests

    func testMCPServerStdioInitialization() {
        let server = MCPServer(
            command: "/usr/bin/echo",
            arguments: ["hello"],
            name: "test-server",
            environment: ["FOO": "bar"],
            timeout: 60
        )

        XCTAssertEqual(server.serverName, "test-server")
        XCTAssertEqual(server.configuration.timeout, 60)
        XCTAssertEqual(server.configuration.environment["FOO"], "bar")

        if case .stdio(let cmd, let args) = server.configuration.transport {
            XCTAssertEqual(cmd, "/usr/bin/echo")
            XCTAssertEqual(args, ["hello"])
        } else {
            XCTFail("Expected stdio transport")
        }
    }

    func testMCPServerStdioDefaultName() {
        let server = MCPServer(command: "/usr/bin/echo")

        XCTAssertEqual(server.serverName, "echo")
    }

    func testMCPServerHTTPInitialization() {
        let url = URL(string: "http://localhost:8080")!
        let server = MCPServer(url: url, name: "http-server", timeout: 45)

        XCTAssertEqual(server.serverName, "http-server")
        XCTAssertEqual(server.configuration.timeout, 45)

        if case .http(let serverUrl) = server.configuration.transport {
            XCTAssertEqual(serverUrl.absoluteString, "http://localhost:8080")
        } else {
            XCTFail("Expected http transport")
        }
    }

    func testMCPServerHTTPDefaultName() {
        let url = URL(string: "http://example.com:9000")!
        let server = MCPServer(url: url)

        XCTAssertEqual(server.serverName, "example.com")
    }

    // MARK: - Tool Selection Tests

    func testToolSelectionAll() {
        let selection = MCPToolSelection.all
        let capabilities = MCPToolCapabilities()

        XCTAssertTrue(selection.includes(toolName: "any_tool", capabilities: capabilities))
    }

    func testToolSelectionIncluding() {
        let selection = MCPToolSelection.including("tool1", "tool2")
        let capabilities = MCPToolCapabilities()

        XCTAssertTrue(selection.includes(toolName: "tool1", capabilities: capabilities))
        XCTAssertTrue(selection.includes(toolName: "tool2", capabilities: capabilities))
        XCTAssertFalse(selection.includes(toolName: "tool3", capabilities: capabilities))
    }

    func testToolSelectionExcluding() {
        let selection = MCPToolSelection.excluding("dangerous_tool")
        let capabilities = MCPToolCapabilities()

        XCTAssertTrue(selection.includes(toolName: "safe_tool", capabilities: capabilities))
        XCTAssertFalse(selection.includes(toolName: "dangerous_tool", capabilities: capabilities))
    }

    func testToolSelectionReadOnly() {
        let selection = MCPToolSelection.readOnly
        let readOnlyCaps = MCPToolCapabilities(isReadOnly: true)
        let writeCaps = MCPToolCapabilities(isReadOnly: false)

        XCTAssertTrue(selection.includes(toolName: "read_tool", capabilities: readOnlyCaps))
        XCTAssertFalse(selection.includes(toolName: "write_tool", capabilities: writeCaps))
    }

    func testToolSelectionWriteOnly() {
        let selection = MCPToolSelection.writeOnly
        let readOnlyCaps = MCPToolCapabilities(isReadOnly: true)
        let writeCaps = MCPToolCapabilities(isReadOnly: false)

        XCTAssertFalse(selection.includes(toolName: "read_tool", capabilities: readOnlyCaps))
        XCTAssertTrue(selection.includes(toolName: "write_tool", capabilities: writeCaps))
    }

    func testToolSelectionSafe() {
        let selection = MCPToolSelection.safe
        let safeCaps = MCPToolCapabilities(isDangerous: false)
        let dangerousCaps = MCPToolCapabilities(isDangerous: true)

        XCTAssertTrue(selection.includes(toolName: "safe_tool", capabilities: safeCaps))
        XCTAssertFalse(selection.includes(toolName: "dangerous_tool", capabilities: dangerousCaps))
    }

    // MARK: - Tool Capabilities Tests

    func testToolCapabilitiesDefault() {
        let caps = MCPToolCapabilities.default

        XCTAssertFalse(caps.isReadOnly)
        XCTAssertFalse(caps.isDangerous)
    }

    func testToolCapabilitiesReadOnly() {
        let caps = MCPToolCapabilities.readOnly

        XCTAssertTrue(caps.isReadOnly)
        XCTAssertFalse(caps.isDangerous)
    }

    func testToolCapabilitiesDangerous() {
        let caps = MCPToolCapabilities.dangerous

        XCTAssertFalse(caps.isReadOnly)
        XCTAssertTrue(caps.isDangerous)
    }

    // MARK: - Fluent API Tests

    func testMCPServerFluentReadOnly() {
        let server = MCPServer(command: "/usr/bin/echo").readOnly

        if case .preset(.readOnly) = server.toolSelection.mode {
            // Success
        } else {
            XCTFail("Expected readOnly selection")
        }
    }

    func testMCPServerFluentSafe() {
        let server = MCPServer(command: "/usr/bin/echo").safe

        if case .preset(.safe) = server.toolSelection.mode {
            // Success
        } else {
            XCTFail("Expected safe selection")
        }
    }

    func testMCPServerFluentIncluding() {
        let server = MCPServer(command: "/usr/bin/echo").including("tool1", "tool2")

        if case .including(let tools) = server.toolSelection.mode {
            XCTAssertEqual(tools, Set(["tool1", "tool2"]))
        } else {
            XCTFail("Expected including selection")
        }
    }

    func testMCPServerFluentExcluding() {
        let server = MCPServer(command: "/usr/bin/echo").excluding("bad_tool")

        if case .excluding(let tools) = server.toolSelection.mode {
            XCTAssertEqual(tools, Set(["bad_tool"]))
        } else {
            XCTFail("Expected excluding selection")
        }
    }

    // MARK: - MCPTool Tests

    func testMCPToolFromJSON() {
        let json: [String: Any] = [
            "name": "test_tool",
            "description": "A test tool",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "query": [
                        "type": "string",
                        "description": "Search query"
                    ]
                ],
                "required": ["query"]
            ]
        ]

        let tool = MCPTool.from(json: json) { _ in
            return .text("result")
        }

        XCTAssertNotNil(tool)
        XCTAssertEqual(tool?.toolName, "test_tool")
        XCTAssertEqual(tool?.toolDescription, "A test tool")
    }

    func testMCPToolFromJSONWithoutDescription() {
        let json: [String: Any] = [
            "name": "simple_tool"
        ]

        let tool = MCPTool.from(json: json) { _ in
            return .text("result")
        }

        XCTAssertNil(tool) // description is required
    }

    func testMCPToolCapabilitiesInference() {
        // Read-only tool names
        let getToolJson: [String: Any] = [
            "name": "get_data",
            "description": "Gets data"
        ]
        let getTool = MCPTool.from(json: getToolJson) { _ in .text("") }
        XCTAssertTrue(getTool?.capabilities.isReadOnly ?? false)

        // Write tool names
        let deleteToolJson: [String: Any] = [
            "name": "delete_file",
            "description": "Deletes a file"
        ]
        let deleteTool = MCPTool.from(json: deleteToolJson) { _ in .text("") }
        XCTAssertTrue(deleteTool?.capabilities.isDangerous ?? false)
    }

    // MARK: - MCPError Tests

    func testMCPErrorPlaceholderDescription() {
        let error = MCPError.placeholderCannotExecute(serverName: "test-server")

        XCTAssertTrue(error.errorDescription?.contains("test-server") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("resolvingMCPServers()") ?? false)
    }

    func testMCPErrorToolNotFound() {
        let error = MCPError.toolNotFound(toolName: "missing_tool", serverName: "test-server")

        XCTAssertTrue(error.errorDescription?.contains("missing_tool") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("test-server") ?? false)
    }

    // MARK: - ToolSet Extension Tests

    func testToolSetContainsMCPPlaceholders() {
        // 実際のToolSetにプレースホルダーを追加するテスト
        let server = MCPServer(command: "/usr/bin/echo")
        let placeholder = MCPServerPlaceholder(server: server)

        // ToolSetの内部tools配列にアクセスしてテスト
        let toolSet = ToolSet(tools: [placeholder])

        XCTAssertTrue(toolSet.containsMCPPlaceholders)
        XCTAssertEqual(toolSet.mcpPlaceholders.count, 1)
    }

    func testToolSetWithoutMCPPlaceholders() {
        let toolSet = ToolSet(tools: [])

        XCTAssertFalse(toolSet.containsMCPPlaceholders)
        XCTAssertTrue(toolSet.mcpPlaceholders.isEmpty)
    }

    // MARK: - Authorization Tests

    func testMCPAuthorizationBearer() {
        var request = URLRequest(url: URL(string: "https://example.com")!)
        let auth = MCPAuthorization.bearer("test-token-123")

        auth.apply(to: &request)

        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token-123")
    }

    func testMCPAuthorizationHeader() {
        var request = URLRequest(url: URL(string: "https://example.com")!)
        let auth = MCPAuthorization.header("X-API-Key", "my-api-key")

        auth.apply(to: &request)

        XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "my-api-key")
    }

    func testMCPAuthorizationHeaders() {
        var request = URLRequest(url: URL(string: "https://example.com")!)
        let auth = MCPAuthorization.headers([
            "X-API-Key": "key123",
            "X-Client-ID": "client456"
        ])

        auth.apply(to: &request)

        XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "key123")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Client-ID"), "client456")
    }

    func testMCPAuthorizationNone() {
        var request = URLRequest(url: URL(string: "https://example.com")!)
        let auth = MCPAuthorization.none

        auth.apply(to: &request)

        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testMCPServerHTTPWithBearerAuth() {
        let url = URL(string: "https://api.example.com/mcp")!
        let server = MCPServer(
            url: url,
            name: "auth-server",
            authorization: .bearer("my-token")
        )

        XCTAssertEqual(server.serverName, "auth-server")
        if case .bearer(let token) = server.configuration.authorization {
            XCTAssertEqual(token, "my-token")
        } else {
            XCTFail("Expected bearer authorization")
        }
    }

    func testMCPServerHTTPDefaultAuthorizationIsNone() {
        let url = URL(string: "https://api.example.com/mcp")!
        let server = MCPServer(url: url)

        if case .none = server.configuration.authorization {
            // Success
        } else {
            XCTFail("Expected no authorization by default")
        }
    }

    // MARK: - Preset Tests

    func testMCPServerNotionPreset() {
        let server = MCPServer.notion(token: "ntn_test_token_12345")

        XCTAssertEqual(server.serverName, "notion")

        if case .http(let url) = server.configuration.transport {
            XCTAssertEqual(url.absoluteString, "https://mcp.notion.com/mcp")
        } else {
            XCTFail("Expected HTTP transport")
        }

        if case .bearer(let token) = server.configuration.authorization {
            XCTAssertEqual(token, "ntn_test_token_12345")
        } else {
            XCTFail("Expected bearer authorization")
        }
    }

    // MARK: - Configuration Tests

    func testMCPConfigurationDefaults() {
        let config = MCPConfiguration(
            transport: .stdio(command: "test", arguments: [])
        )

        XCTAssertEqual(config.timeout, 30)
        XCTAssertTrue(config.environment.isEmpty)
        if case .none = config.authorization {
            // Success
        } else {
            XCTFail("Expected no authorization by default")
        }
    }

    func testMCPTransportStdio() {
        let transport = MCPTransport.stdio(command: "/bin/test", arguments: ["-v"])

        if case .stdio(let cmd, let args) = transport {
            XCTAssertEqual(cmd, "/bin/test")
            XCTAssertEqual(args, ["-v"])
        } else {
            XCTFail("Expected stdio transport")
        }
    }

    func testMCPTransportHTTP() {
        let url = URL(string: "https://api.example.com")!
        let transport = MCPTransport.http(url: url)

        if case .http(let transportUrl) = transport {
            XCTAssertEqual(transportUrl.absoluteString, "https://api.example.com")
        } else {
            XCTFail("Expected http transport")
        }
    }

    // MARK: - ToolKit Protocol Tests

    func testToolKitProtocol() {
        let toolkit = MockToolKit()

        XCTAssertEqual(toolkit.name, "mock-toolkit")
        XCTAssertEqual(toolkit.toolCount, 2)
        XCTAssertEqual(toolkit.toolNames, ["mock_tool_1", "mock_tool_2"])
    }

    func testToolKitToolLookup() {
        let toolkit = MockToolKit()

        let tool1 = toolkit.tool(named: "mock_tool_1")
        XCTAssertNotNil(tool1)
        XCTAssertEqual(tool1?.toolName, "mock_tool_1")

        let nonexistent = toolkit.tool(named: "nonexistent")
        XCTAssertNil(nonexistent)
    }

    func testToolKitInToolSet() {
        let toolkit = MockToolKit()

        let toolSet = ToolSet {
            toolkit
        }

        XCTAssertEqual(toolSet.count, 2)
        XCTAssertNotNil(toolSet.tool(named: "mock_tool_1"))
        XCTAssertNotNil(toolSet.tool(named: "mock_tool_2"))
    }

    func testToolKitMixedWithTools() {
        let toolkit = MockToolKit()

        let toolSet = ToolSet {
            toolkit
            MockSingleTool()
        }

        XCTAssertEqual(toolSet.count, 3)
        XCTAssertNotNil(toolSet.tool(named: "mock_tool_1"))
        XCTAssertNotNil(toolSet.tool(named: "mock_tool_2"))
        XCTAssertNotNil(toolSet.tool(named: "mock_single_tool"))
    }

    func testToolSetAppendingToolKit() {
        let toolSet = ToolSet {
            MockSingleTool()
        }
        let toolkit = MockToolKit()

        let extended = toolSet.appending(toolkit)

        XCTAssertEqual(extended.count, 3)
    }

    func testToolSetPlusToolKit() {
        let toolSet = ToolSet {
            MockSingleTool()
        }
        let toolkit = MockToolKit()

        let extended = toolSet + toolkit

        XCTAssertEqual(extended.count, 3)
    }

    // MARK: - ToolAnnotations Tests

    func testToolAnnotationsDefault() {
        let annotations = ToolAnnotations()

        XCTAssertNil(annotations.title)
        XCTAssertNil(annotations.readOnlyHint)
        XCTAssertNil(annotations.destructiveHint)
        XCTAssertNil(annotations.idempotentHint)
        XCTAssertNil(annotations.openWorldHint)
    }

    func testToolAnnotationsReadOnlyPreset() {
        let annotations = ToolAnnotations.readOnly

        XCTAssertEqual(annotations.readOnlyHint, true)
    }

    func testToolAnnotationsDestructivePreset() {
        let annotations = ToolAnnotations.destructive

        XCTAssertEqual(annotations.readOnlyHint, false)
        XCTAssertEqual(annotations.destructiveHint, true)
    }

    func testToolAnnotationsIdempotentWritePreset() {
        let annotations = ToolAnnotations.idempotentWrite

        XCTAssertEqual(annotations.readOnlyHint, false)
        XCTAssertEqual(annotations.destructiveHint, true)
        XCTAssertEqual(annotations.idempotentHint, true)
    }

    func testToolAnnotationsClosedWorldPreset() {
        let annotations = ToolAnnotations.closedWorld

        XCTAssertEqual(annotations.openWorldHint, false)
    }

    // MARK: - BuiltInTool Tests

    func testBuiltInToolCreation() {
        let tool = BuiltInTool(
            name: "test_tool",
            description: "A test tool",
            inputSchema: .object(properties: [:], required: []),
            annotations: .readOnly
        ) { _ in
            .text("result")
        }

        XCTAssertEqual(tool.toolName, "test_tool")
        XCTAssertEqual(tool.toolDescription, "A test tool")
        XCTAssertEqual(tool.annotations.readOnlyHint, true)
    }

    func testBuiltInToolCapabilitiesConversion() {
        let readOnlyTool = BuiltInTool(
            name: "read_tool",
            description: "Reads data",
            inputSchema: .object(properties: [:], required: []),
            annotations: .readOnly
        ) { _ in .text("") }

        XCTAssertTrue(readOnlyTool.capabilities.isReadOnly)
        XCTAssertFalse(readOnlyTool.capabilities.isDangerous)

        let destructiveTool = BuiltInTool(
            name: "delete_tool",
            description: "Deletes data",
            inputSchema: .object(properties: [:], required: []),
            annotations: .destructive
        ) { _ in .text("") }

        XCTAssertFalse(destructiveTool.capabilities.isReadOnly)
        XCTAssertTrue(destructiveTool.capabilities.isDangerous)
    }

    func testBuiltInToolExecution() async throws {
        let tool = BuiltInTool(
            name: "echo_tool",
            description: "Echoes input",
            inputSchema: .object(
                properties: ["message": .string()],
                required: ["message"]
            )
        ) { data in
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = json?["message"] as? String ?? ""
            return .text("Echo: \(message)")
        }

        let input = try JSONSerialization.data(withJSONObject: ["message": "Hello"])
        let result = try await tool.execute(with: input)

        if case .text(let text) = result {
            XCTAssertEqual(text, "Echo: Hello")
        } else {
            XCTFail("Expected text result")
        }
    }
}

// MARK: - Mock Types for Testing

/// テスト用のモックToolKit
private struct MockToolKit: ToolKit {
    var name: String { "mock-toolkit" }

    var tools: [any Tool] {
        [
            BuiltInTool(
                name: "mock_tool_1",
                description: "Mock tool 1",
                inputSchema: .object(properties: [:], required: [])
            ) { _ in .text("result1") },
            BuiltInTool(
                name: "mock_tool_2",
                description: "Mock tool 2",
                inputSchema: .object(properties: [:], required: [])
            ) { _ in .text("result2") }
        ]
    }
}

/// テスト用の単一ツール
private struct MockSingleTool: Tool {
    var toolName: String { "mock_single_tool" }
    var toolDescription: String { "A single mock tool" }
    var inputSchema: JSONSchema { .object(properties: [:], required: []) }

    func execute(with argumentsData: Data) async throws -> ToolResult {
        .text("single result")
    }
}
