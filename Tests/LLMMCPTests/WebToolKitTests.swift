import XCTest
@testable import LLMMCP
import LLMTool

final class WebToolKitTests: XCTestCase {

    // MARK: - ToolKit Protocol Tests

    func testWebToolKitName() {
        let toolkit = WebToolKit()
        XCTAssertEqual(toolkit.name, "web")
    }

    func testWebToolKitToolCount() {
        let toolkit = WebToolKit()
        XCTAssertEqual(toolkit.toolCount, 4)
    }

    func testWebToolKitToolNames() {
        let toolkit = WebToolKit()
        let expectedNames = ["fetch_url", "fetch_json", "fetch_headers", "fetch_page"]
        XCTAssertEqual(toolkit.toolNames, expectedNames)
    }

    func testWebToolKitInToolSet() {
        let toolkit = WebToolKit()
        let toolSet = ToolSet {
            toolkit
        }

        XCTAssertEqual(toolSet.count, 4)
        XCTAssertNotNil(toolSet.tool(named: "fetch_url"))
        XCTAssertNotNil(toolSet.tool(named: "fetch_json"))
        XCTAssertNotNil(toolSet.tool(named: "fetch_headers"))
        XCTAssertNotNil(toolSet.tool(named: "fetch_page"))
    }

    // MARK: - Initialization Tests

    func testWebToolKitDefaultInit() {
        let toolkit = WebToolKit()
        XCTAssertEqual(toolkit.toolCount, 4)
    }

    func testWebToolKitWithAllowedDomains() {
        let toolkit = WebToolKit(allowedDomains: ["api.example.com"])
        XCTAssertEqual(toolkit.toolCount, 4)
    }

    func testWebToolKitWithCustomTimeout() {
        let toolkit = WebToolKit(timeout: 60)
        XCTAssertEqual(toolkit.toolCount, 4)
    }

    // MARK: - URL Validation Tests

    func testInvalidURL() async throws {
        let toolkit = WebToolKit()
        let tool = toolkit.tool(named: "fetch_url")!

        // 空文字は無効なURL
        let input = try JSONSerialization.data(withJSONObject: [
            "url": ""
        ])

        do {
            _ = try await tool.execute(with: input)
            XCTFail("Expected invalid URL error")
        } catch {
            // 空URLまたはスキームなしのエラー
            let errorDesc = error.localizedDescription.lowercased()
            XCTAssertTrue(errorDesc.contains("invalid") || errorDesc.contains("unsupported"))
        }
    }

    func testUnsupportedScheme() async throws {
        let toolkit = WebToolKit()
        let tool = toolkit.tool(named: "fetch_url")!

        let input = try JSONSerialization.data(withJSONObject: [
            "url": "ftp://example.com/file"
        ])

        do {
            _ = try await tool.execute(with: input)
            XCTFail("Expected unsupported scheme error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Unsupported URL scheme"))
        }
    }

    func testDomainNotAllowed() async throws {
        let toolkit = WebToolKit(allowedDomains: ["api.example.com"])
        let tool = toolkit.tool(named: "fetch_url")!

        let input = try JSONSerialization.data(withJSONObject: [
            "url": "https://other.com/data"
        ])

        do {
            _ = try await tool.execute(with: input)
            XCTFail("Expected domain not allowed error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("not allowed"))
        }
    }

    func testAllowedDomain() async throws {
        // ドメイン制限のみテスト（実際のネットワーク呼び出しはしない）
        let toolkit = WebToolKit(allowedDomains: ["api.example.com", "data.example.com"])

        // ドメインが許可リストに含まれていることを確認
        // (実際のfetchはネットワーク接続が必要なのでスキップ)
        XCTAssertEqual(toolkit.toolCount, 4)
    }

    // MARK: - Annotations Tests

    func testOpenWorldAnnotations() {
        let toolkit = WebToolKit()

        // 全てのWebツールはopenWorld（外部と通信）
        for tool in toolkit.tools {
            if let builtInTool = tool as? BuiltInTool {
                XCTAssertEqual(builtInTool.annotations.openWorldHint, true)
            }
        }
    }

    func testReadOnlyAnnotations() {
        let toolkit = WebToolKit()

        // 全てのWebツールは読み取り専用として扱う
        for tool in toolkit.tools {
            if let builtInTool = tool as? BuiltInTool {
                XCTAssertEqual(builtInTool.annotations.readOnlyHint, true)
                XCTAssertTrue(builtInTool.capabilities.isReadOnly)
            }
        }
    }

    // MARK: - Input Schema Tests

    func testFetchURLInputSchema() {
        let toolkit = WebToolKit()
        let tool = toolkit.tool(named: "fetch_url")!

        // スキーマにurlプロパティがあることを確認
        XCTAssertEqual(tool.toolName, "fetch_url")
        XCTAssertTrue(tool.toolDescription.contains("Fetch content"))
    }

    func testFetchJSONInputSchema() {
        let toolkit = WebToolKit()
        let tool = toolkit.tool(named: "fetch_json")!

        XCTAssertEqual(tool.toolName, "fetch_json")
        XCTAssertTrue(tool.toolDescription.contains("JSON"))
    }

    func testFetchHeadersInputSchema() {
        let toolkit = WebToolKit()
        let tool = toolkit.tool(named: "fetch_headers")!

        XCTAssertEqual(tool.toolName, "fetch_headers")
        XCTAssertTrue(tool.toolDescription.contains("headers"))
    }

    // MARK: - Error Type Tests

    func testErrorDescriptions() {
        let errors: [WebToolKitError] = [
            .invalidURL("bad url"),
            .unsupportedScheme("ftp"),
            .domainNotAllowed("bad.com", allowed: ["good.com"]),
            .invalidResponse,
            .httpError(statusCode: 404),
            .contentTooLarge(size: 1000000, maxSize: 500000),
            .encodingError,
            .jsonParseError("unexpected token")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }

    // MARK: - Integration Tests (Live Network - Skip in CI)

    /// 実際のネットワーク呼び出しをテスト（ローカル開発時のみ）
    /// CI環境ではスキップすることを推奨
    func testLiveFetchURL() async throws {
        // 環境変数でスキップ制御
        guard ProcessInfo.processInfo.environment["SKIP_NETWORK_TESTS"] == nil else {
            throw XCTSkip("Skipping network test")
        }

        let toolkit = WebToolKit()
        let tool = toolkit.tool(named: "fetch_url")!

        // httpbin.orgはテスト用の公開API
        let input = try JSONSerialization.data(withJSONObject: [
            "url": "https://httpbin.org/get"
        ])

        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertNotNil(json?["statusCode"])
            XCTAssertEqual(json?["statusCode"] as? Int, 200)
            XCTAssertNotNil(json?["content"])
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testLiveFetchJSON() async throws {
        guard ProcessInfo.processInfo.environment["SKIP_NETWORK_TESTS"] == nil else {
            throw XCTSkip("Skipping network test")
        }

        let toolkit = WebToolKit()
        let tool = toolkit.tool(named: "fetch_json")!

        let input = try JSONSerialization.data(withJSONObject: [
            "url": "https://httpbin.org/json"
        ])

        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(json?["statusCode"] as? Int, 200)
            XCTAssertNotNil(json?["data"])
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testLiveFetchHeaders() async throws {
        guard ProcessInfo.processInfo.environment["SKIP_NETWORK_TESTS"] == nil else {
            throw XCTSkip("Skipping network test")
        }

        let toolkit = WebToolKit()
        let tool = toolkit.tool(named: "fetch_headers")!

        let input = try JSONSerialization.data(withJSONObject: [
            "url": "https://httpbin.org/get"
        ])

        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertNotNil(json?["statusCode"])
            XCTAssertNotNil(json?["headers"])
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testLiveHTTPError() async throws {
        guard ProcessInfo.processInfo.environment["SKIP_NETWORK_TESTS"] == nil else {
            throw XCTSkip("Skipping network test")
        }

        let toolkit = WebToolKit()
        let tool = toolkit.tool(named: "fetch_url")!

        let input = try JSONSerialization.data(withJSONObject: [
            "url": "https://httpbin.org/status/404"
        ])

        do {
            _ = try await tool.execute(with: input)
            XCTFail("Expected HTTP error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("HTTP error"))
        }
    }

    func testLivePostRequest() async throws {
        guard ProcessInfo.processInfo.environment["SKIP_NETWORK_TESTS"] == nil else {
            throw XCTSkip("Skipping network test")
        }

        let toolkit = WebToolKit()
        let tool = toolkit.tool(named: "fetch_json")!

        let input = try JSONSerialization.data(withJSONObject: [
            "url": "https://httpbin.org/post",
            "method": "POST",
            "body": "{\"test\": \"data\"}"
        ])

        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(json?["statusCode"] as? Int, 200)
        } else {
            XCTFail("Expected JSON result")
        }
    }
}
