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

    // MARK: - Configuration Tests

    func testMCPConfigurationDefaults() {
        let config = MCPConfiguration(
            transport: .stdio(command: "test", arguments: [])
        )

        XCTAssertEqual(config.timeout, 30)
        XCTAssertTrue(config.environment.isEmpty)
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
}
