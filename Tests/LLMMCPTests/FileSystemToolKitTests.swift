import XCTest
@testable import LLMMCP
import LLMTool

final class FileSystemToolKitTests: XCTestCase {
    // MARK: - Properties

    var tempDir: String!
    var toolkit: FileSystemToolKit!

    // MARK: - Setup/Teardown

    override func setUp() async throws {
        // 一時ディレクトリを作成
        tempDir = NSTemporaryDirectory() + "FileSystemToolKitTests-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

        // テスト用のToolKitを作成（一時ディレクトリのみ許可）
        toolkit = FileSystemToolKit(allowedPaths: [tempDir])
    }

    override func tearDown() async throws {
        // 一時ディレクトリを削除
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
        tempDir = nil
        toolkit = nil
    }

    // MARK: - ToolKit Protocol Tests

    func testFileSystemToolKitName() {
        XCTAssertEqual(toolkit.name, "filesystem")
    }

    func testFileSystemToolKitToolCount() {
        XCTAssertEqual(toolkit.toolCount, 9)
    }

    func testFileSystemToolKitToolNames() {
        let expectedNames = [
            "read_file", "read_multiple_files", "write_file", "create_directory",
            "list_directory", "directory_tree", "move_file", "search_files", "get_file_info"
        ]
        XCTAssertEqual(toolkit.toolNames, expectedNames)
    }

    func testFileSystemToolKitInToolSet() {
        let toolSet = ToolSet {
            toolkit!
        }

        XCTAssertEqual(toolSet.count, 9)
        XCTAssertNotNil(toolSet.tool(named: "read_file"))
        XCTAssertNotNil(toolSet.tool(named: "write_file"))
    }

    // MARK: - write_file Tests

    func testWriteFile() async throws {
        let tool = toolkit.tool(named: "write_file")!

        let input = try JSONSerialization.data(withJSONObject: [
            "path": tempDir + "/test.txt",
            "content": "Hello, World!"
        ])
        let result = try await tool.execute(with: input)

        if case .text(let text) = result {
            XCTAssertTrue(text.contains("Successfully"))
        } else {
            XCTFail("Expected text result")
        }

        // ファイルが作成されたことを確認
        let fileContent = FileManager.default.contents(atPath: tempDir + "/test.txt")
        XCTAssertNotNil(fileContent)
        XCTAssertEqual(String(data: fileContent!, encoding: .utf8), "Hello, World!")
    }

    func testWriteFileCreatesParentDirectories() async throws {
        let tool = toolkit.tool(named: "write_file")!

        let input = try JSONSerialization.data(withJSONObject: [
            "path": tempDir + "/nested/dir/test.txt",
            "content": "Nested content"
        ])
        let result = try await tool.execute(with: input)

        if case .text(let text) = result {
            XCTAssertTrue(text.contains("Successfully"))
        } else {
            XCTFail("Expected text result")
        }

        // ネストされたファイルが作成されたことを確認
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir + "/nested/dir/test.txt"))
    }

    // MARK: - read_file Tests

    func testReadFile() async throws {
        // テストファイルを作成
        let testContent = "Test file content"
        let testPath = tempDir + "/readable.txt"
        try testContent.write(toFile: testPath, atomically: true, encoding: .utf8)

        let tool = toolkit.tool(named: "read_file")!

        let input = try JSONSerialization.data(withJSONObject: ["path": testPath])
        let result = try await tool.execute(with: input)

        if case .text(let text) = result {
            XCTAssertEqual(text, testContent)
        } else {
            XCTFail("Expected text result")
        }
    }

    func testReadFileNotFound() async throws {
        let tool = toolkit.tool(named: "read_file")!

        let input = try JSONSerialization.data(withJSONObject: ["path": tempDir + "/nonexistent.txt"])

        do {
            _ = try await tool.execute(with: input)
            XCTFail("Expected file not found error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("not found"))
        }
    }

    // MARK: - read_multiple_files Tests

    func testReadMultipleFiles() async throws {
        // テストファイルを作成
        let file1 = tempDir + "/file1.txt"
        let file2 = tempDir + "/file2.txt"
        try "Content 1".write(toFile: file1, atomically: true, encoding: .utf8)
        try "Content 2".write(toFile: file2, atomically: true, encoding: .utf8)

        let tool = toolkit.tool(named: "read_multiple_files")!

        let input = try JSONSerialization.data(withJSONObject: ["paths": [file1, file2]])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let results = try JSONDecoder().decode([FileReadResultDTO].self, from: data)
            XCTAssertEqual(results.count, 2)
            XCTAssertEqual(results[0].content, "Content 1")
            XCTAssertEqual(results[1].content, "Content 2")
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testReadMultipleFilesWithError() async throws {
        // 1つは存在するファイル、1つは存在しないファイル
        let existingFile = tempDir + "/existing.txt"
        try "Existing content".write(toFile: existingFile, atomically: true, encoding: .utf8)

        let tool = toolkit.tool(named: "read_multiple_files")!

        let input = try JSONSerialization.data(withJSONObject: [
            "paths": [existingFile, tempDir + "/nonexistent.txt"]
        ])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let results = try JSONDecoder().decode([FileReadResultDTO].self, from: data)
            XCTAssertEqual(results.count, 2)
            XCTAssertEqual(results[0].content, "Existing content")
            XCTAssertNil(results[0].error)
            XCTAssertNil(results[1].content)
            XCTAssertNotNil(results[1].error)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    // MARK: - create_directory Tests

    func testCreateDirectory() async throws {
        let tool = toolkit.tool(named: "create_directory")!

        let input = try JSONSerialization.data(withJSONObject: ["path": tempDir + "/new_dir"])
        let result = try await tool.execute(with: input)

        if case .text(let text) = result {
            XCTAssertTrue(text.contains("Successfully"))
        } else {
            XCTFail("Expected text result")
        }

        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir + "/new_dir", isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }

    func testCreateNestedDirectory() async throws {
        let tool = toolkit.tool(named: "create_directory")!

        let input = try JSONSerialization.data(withJSONObject: ["path": tempDir + "/a/b/c"])
        let result = try await tool.execute(with: input)

        if case .text(let text) = result {
            XCTAssertTrue(text.contains("Successfully"))
        } else {
            XCTFail("Expected text result")
        }

        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir + "/a/b/c", isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }

    // MARK: - list_directory Tests

    func testListDirectory() async throws {
        // テストファイルとディレクトリを作成
        try "".write(toFile: tempDir + "/file1.txt", atomically: true, encoding: .utf8)
        try "".write(toFile: tempDir + "/file2.txt", atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(atPath: tempDir + "/subdir", withIntermediateDirectories: true)

        let tool = toolkit.tool(named: "list_directory")!

        let input = try JSONSerialization.data(withJSONObject: ["path": tempDir])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let entries = try JSONDecoder().decode([DirectoryEntryDTO].self, from: data)
            XCTAssertEqual(entries.count, 3)
            XCTAssertTrue(entries.contains { $0.name == "file1.txt" && $0.type == "file" })
            XCTAssertTrue(entries.contains { $0.name == "file2.txt" && $0.type == "file" })
            XCTAssertTrue(entries.contains { $0.name == "subdir" && $0.type == "directory" })
        } else {
            XCTFail("Expected JSON result")
        }
    }

    // MARK: - directory_tree Tests

    func testDirectoryTree() async throws {
        // ツリー構造を作成
        try FileManager.default.createDirectory(atPath: tempDir + "/src", withIntermediateDirectories: true)
        try "".write(toFile: tempDir + "/src/main.swift", atomically: true, encoding: .utf8)
        try "".write(toFile: tempDir + "/README.md", atomically: true, encoding: .utf8)

        let tool = toolkit.tool(named: "directory_tree")!

        let input = try JSONSerialization.data(withJSONObject: ["path": tempDir, "maxDepth": 2])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let tree = try JSONDecoder().decode(DirectoryTreeNodeDTO.self, from: data)
            XCTAssertEqual(tree.type, "directory")
            XCTAssertNotNil(tree.children)
            XCTAssertTrue(tree.children?.contains { $0.name == "README.md" } ?? false)
            XCTAssertTrue(tree.children?.contains { $0.name == "src" && $0.type == "directory" } ?? false)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    // MARK: - move_file Tests

    func testMoveFile() async throws {
        // テストファイルを作成
        let source = tempDir + "/source.txt"
        let dest = tempDir + "/destination.txt"
        try "Move me".write(toFile: source, atomically: true, encoding: .utf8)

        let tool = toolkit.tool(named: "move_file")!

        let input = try JSONSerialization.data(withJSONObject: [
            "source": source,
            "destination": dest
        ])
        let result = try await tool.execute(with: input)

        if case .text(let text) = result {
            XCTAssertTrue(text.contains("Successfully"))
        } else {
            XCTFail("Expected text result")
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: source))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest))
        XCTAssertEqual(try String(contentsOfFile: dest), "Move me")
    }

    // MARK: - search_files Tests

    func testSearchFiles() async throws {
        // テストファイルを作成
        try "".write(toFile: tempDir + "/test.swift", atomically: true, encoding: .utf8)
        try "".write(toFile: tempDir + "/main.swift", atomically: true, encoding: .utf8)
        try "".write(toFile: tempDir + "/readme.md", atomically: true, encoding: .utf8)

        let tool = toolkit.tool(named: "search_files")!

        let input = try JSONSerialization.data(withJSONObject: [
            "path": tempDir,
            "pattern": "*.swift"
        ])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let searchResult = try JSONDecoder().decode(SearchResultDTO.self, from: data)
            XCTAssertEqual(searchResult.matches.count, 2)
            XCTAssertTrue(searchResult.matches.contains("main.swift"))
            XCTAssertTrue(searchResult.matches.contains("test.swift"))
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testSearchFilesRecursive() async throws {
        // ネストされたファイルを作成
        try FileManager.default.createDirectory(atPath: tempDir + "/src", withIntermediateDirectories: true)
        try "".write(toFile: tempDir + "/root.swift", atomically: true, encoding: .utf8)
        try "".write(toFile: tempDir + "/src/nested.swift", atomically: true, encoding: .utf8)

        let tool = toolkit.tool(named: "search_files")!

        let input = try JSONSerialization.data(withJSONObject: [
            "path": tempDir,
            "pattern": "*.swift",
            "recursive": true
        ])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let searchResult = try JSONDecoder().decode(SearchResultDTO.self, from: data)
            XCTAssertEqual(searchResult.matches.count, 2)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    // MARK: - get_file_info Tests

    func testGetFileInfo() async throws {
        let testFile = tempDir + "/info_test.txt"
        try "Test content".write(toFile: testFile, atomically: true, encoding: .utf8)

        let tool = toolkit.tool(named: "get_file_info")!

        let input = try JSONSerialization.data(withJSONObject: ["path": testFile])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let info = try JSONDecoder().decode(FileInfoDTO.self, from: data)
            XCTAssertEqual(info.type, "file")
            XCTAssertEqual(info.size, 12) // "Test content" = 12 bytes
            XCTAssertTrue(info.isReadable)
            XCTAssertNotNil(info.created)
            XCTAssertNotNil(info.modified)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testGetDirectoryInfo() async throws {
        let testDir = tempDir + "/info_dir"
        try FileManager.default.createDirectory(atPath: testDir, withIntermediateDirectories: true)

        let tool = toolkit.tool(named: "get_file_info")!

        let input = try JSONSerialization.data(withJSONObject: ["path": testDir])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let info = try JSONDecoder().decode(FileInfoDTO.self, from: data)
            XCTAssertEqual(info.type, "directory")
        } else {
            XCTFail("Expected JSON result")
        }
    }

    // MARK: - Access Control Tests

    func testAccessDenied() async throws {
        let tool = toolkit.tool(named: "read_file")!

        // 許可されていないパスにアクセス
        let input = try JSONSerialization.data(withJSONObject: ["path": "/etc/passwd"])

        do {
            _ = try await tool.execute(with: input)
            XCTFail("Expected access denied error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Access denied"))
        }
    }

    func testPathTraversalPrevention() async throws {
        let tool = toolkit.tool(named: "read_file")!

        // パストラバーサル攻撃をシミュレート
        let input = try JSONSerialization.data(withJSONObject: ["path": tempDir + "/../../../etc/passwd"])

        do {
            _ = try await tool.execute(with: input)
            XCTFail("Expected access denied error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Access denied"))
        }
    }

    // MARK: - Annotations Tests

    func testReadOnlyToolAnnotations() {
        let readOnlyTools = ["read_file", "read_multiple_files", "list_directory", "directory_tree", "search_files", "get_file_info"]

        for toolName in readOnlyTools {
            let tool = toolkit.tool(named: toolName) as? BuiltInTool
            XCTAssertNotNil(tool, "Tool \(toolName) should exist")
            XCTAssertEqual(tool?.annotations.readOnlyHint, true, "Tool \(toolName) should be read-only")
            XCTAssertTrue(tool?.capabilities.isReadOnly ?? false, "Tool \(toolName) capabilities should be read-only")
        }
    }

    func testWriteToolAnnotations() {
        let writeTools = ["write_file", "create_directory", "move_file"]

        for toolName in writeTools {
            let tool = toolkit.tool(named: toolName) as? BuiltInTool
            XCTAssertNotNil(tool, "Tool \(toolName) should exist")
            XCTAssertEqual(tool?.annotations.readOnlyHint, false, "Tool \(toolName) should not be read-only")
            XCTAssertFalse(tool?.capabilities.isReadOnly ?? true, "Tool \(toolName) capabilities should not be read-only")
        }
    }

    func testClosedWorldAnnotations() {
        for tool in toolkit.tools {
            if let builtInTool = tool as? BuiltInTool {
                XCTAssertEqual(builtInTool.annotations.openWorldHint, false)
            }
        }
    }
}

// MARK: - DTO Types for Decoding Test Results

private struct FileReadResultDTO: Codable {
    var path: String
    var content: String?
    var error: String?
}

private struct DirectoryEntryDTO: Codable {
    var name: String
    var type: String
}

private struct DirectoryTreeNodeDTO: Codable {
    var name: String
    var type: String
    var children: [DirectoryTreeNodeDTO]?
}

private struct SearchResultDTO: Codable {
    var path: String
    var pattern: String
    var matches: [String]
}

private struct FileInfoDTO: Codable {
    var path: String
    var type: String
    var size: Int64
    var created: String?
    var modified: String?
    var permissions: String
    var isReadable: Bool
    var isWritable: Bool
}
