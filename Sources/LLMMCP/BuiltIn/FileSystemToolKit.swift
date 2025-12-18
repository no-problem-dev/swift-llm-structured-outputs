import Foundation
import LLMClient
import LLMTool

// MARK: - FileSystemToolKit

/// ファイルシステム操作ツールを提供するToolKit
///
/// 公式MCP Filesystem Serverに準拠した実装です。
/// セキュリティのため、許可されたパスのみにアクセスを制限します。
///
/// ## 使用例
///
/// ```swift
/// let tools = ToolSet {
///     FileSystemToolKit(allowedPaths: ["/Users/user/projects"])
/// }
/// ```
///
/// ## 提供されるツール
///
/// - `read_file`: ファイルの内容を読み取り
/// - `read_multiple_files`: 複数ファイルを一度に読み取り
/// - `write_file`: ファイルを作成または上書き
/// - `create_directory`: ディレクトリを作成
/// - `list_directory`: ディレクトリの内容一覧
/// - `directory_tree`: ディレクトリツリー表示
/// - `move_file`: ファイル/ディレクトリの移動・名前変更
/// - `search_files`: ファイル検索（パターンマッチング）
/// - `get_file_info`: ファイル情報取得
public final class FileSystemToolKit: ToolKit, @unchecked Sendable {
    // MARK: - Properties

    public let name: String = "filesystem"

    /// 許可されたパス（これらのパス以下のみアクセス可能）
    private let allowedPaths: [String]

    /// FileManager
    private let fileManager: FileManager

    // MARK: - Initialization

    /// FileSystemToolKitを作成
    ///
    /// - Parameter allowedPaths: アクセスを許可するパスの配列
    ///   チルダ（~）はホームディレクトリに展開されます
    public init(allowedPaths: [String]) {
        self.allowedPaths = allowedPaths.map { path in
            NSString(string: path).expandingTildeInPath
        }
        self.fileManager = FileManager.default
    }

    // MARK: - ToolKit Protocol

    public var tools: [any Tool] {
        [
            readFileTool,
            readMultipleFilesTool,
            writeFileTool,
            createDirectoryTool,
            listDirectoryTool,
            directoryTreeTool,
            moveFileTool,
            searchFilesTool,
            getFileInfoTool
        ]
    }

    // MARK: - Path Validation

    /// パスが許可されているかチェック
    private func validatePath(_ path: String) throws -> String {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let resolvedPath = URL(fileURLWithPath: expandedPath).standardizedFileURL.path

        // 許可されたパス内にあるかチェック
        let isAllowed = allowedPaths.contains { allowedPath in
            resolvedPath.hasPrefix(allowedPath)
        }

        guard isAllowed else {
            throw FileSystemToolKitError.accessDenied(path: resolvedPath, allowedPaths: allowedPaths)
        }

        return resolvedPath
    }

    // MARK: - Tool Definitions

    /// read_file ツール
    private var readFileTool: BuiltInTool {
        BuiltInTool(
            name: "read_file",
            description: "Read the complete contents of a file from the file system. Only works within allowed directories.",
            inputSchema: .object(
                properties: [
                    "path": .string(description: "Path to the file to read")
                ],
                required: ["path"]
            ),
            annotations: ToolAnnotations(
                title: "Read File",
                readOnlyHint: true,
                openWorldHint: false
            )
        ) { [self] data in
            let input = try JSONDecoder().decode(ReadFileInput.self, from: data)
            let validPath = try validatePath(input.path)

            guard let content = fileManager.contents(atPath: validPath) else {
                throw FileSystemToolKitError.fileNotFound(path: validPath)
            }

            guard let text = String(data: content, encoding: .utf8) else {
                throw FileSystemToolKitError.encodingError(path: validPath)
            }

            return .text(text)
        }
    }

    /// read_multiple_files ツール
    private var readMultipleFilesTool: BuiltInTool {
        BuiltInTool(
            name: "read_multiple_files",
            description: "Read the contents of multiple files simultaneously. Returns content with path labels.",
            inputSchema: .object(
                properties: [
                    "paths": .array(
                        description: "Array of file paths to read",
                        items: .string()
                    )
                ],
                required: ["paths"]
            ),
            annotations: ToolAnnotations(
                title: "Read Multiple Files",
                readOnlyHint: true,
                openWorldHint: false
            )
        ) { [self] data in
            let input = try JSONDecoder().decode(ReadMultipleFilesInput.self, from: data)
            var results: [FileReadResult] = []

            for path in input.paths {
                do {
                    let validPath = try validatePath(path)
                    guard let content = fileManager.contents(atPath: validPath),
                          let text = String(data: content, encoding: .utf8) else {
                        results.append(FileReadResult(path: path, content: nil, error: "Could not read file"))
                        continue
                    }
                    results.append(FileReadResult(path: path, content: text, error: nil))
                } catch {
                    results.append(FileReadResult(path: path, content: nil, error: error.localizedDescription))
                }
            }

            let output = try JSONEncoder().encode(results)
            return .json(output)
        }
    }

    /// write_file ツール
    private var writeFileTool: BuiltInTool {
        BuiltInTool(
            name: "write_file",
            description: "Create a new file or overwrite an existing file with new contents. Creates parent directories if needed.",
            inputSchema: .object(
                properties: [
                    "path": .string(description: "Path where to write the file"),
                    "content": .string(description: "Content to write to the file")
                ],
                required: ["path", "content"]
            ),
            annotations: ToolAnnotations(
                title: "Write File",
                readOnlyHint: false,
                destructiveHint: true,
                idempotentHint: true,
                openWorldHint: false
            )
        ) { [self] data in
            let input = try JSONDecoder().decode(WriteFileInput.self, from: data)
            let validPath = try validatePath(input.path)

            // 親ディレクトリを作成
            let parentDir = URL(fileURLWithPath: validPath).deletingLastPathComponent().path
            try fileManager.createDirectory(atPath: parentDir, withIntermediateDirectories: true)

            // ファイルを書き込み
            guard let data = input.content.data(using: .utf8) else {
                throw FileSystemToolKitError.encodingError(path: validPath)
            }
            try data.write(to: URL(fileURLWithPath: validPath))

            return .text("Successfully wrote to \(validPath)")
        }
    }

    /// create_directory ツール
    private var createDirectoryTool: BuiltInTool {
        BuiltInTool(
            name: "create_directory",
            description: "Create a new directory or ensure a directory exists. Creates parent directories if needed.",
            inputSchema: .object(
                properties: [
                    "path": .string(description: "Path of the directory to create")
                ],
                required: ["path"]
            ),
            annotations: ToolAnnotations(
                title: "Create Directory",
                readOnlyHint: false,
                idempotentHint: true,
                openWorldHint: false
            )
        ) { [self] data in
            let input = try JSONDecoder().decode(CreateDirectoryInput.self, from: data)
            let validPath = try validatePath(input.path)

            try fileManager.createDirectory(atPath: validPath, withIntermediateDirectories: true)

            return .text("Successfully created directory \(validPath)")
        }
    }

    /// list_directory ツール
    private var listDirectoryTool: BuiltInTool {
        BuiltInTool(
            name: "list_directory",
            description: "Get a detailed listing of all files and directories in a specified path.",
            inputSchema: .object(
                properties: [
                    "path": .string(description: "Path of the directory to list")
                ],
                required: ["path"]
            ),
            annotations: ToolAnnotations(
                title: "List Directory",
                readOnlyHint: true,
                openWorldHint: false
            )
        ) { [self] data in
            let input = try JSONDecoder().decode(ListDirectoryInput.self, from: data)
            let validPath = try validatePath(input.path)

            let contents = try fileManager.contentsOfDirectory(atPath: validPath)
            var entries: [DirectoryEntry] = []

            for item in contents.sorted() {
                let itemPath = (validPath as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory)
                entries.append(DirectoryEntry(
                    name: item,
                    type: isDirectory.boolValue ? "directory" : "file"
                ))
            }

            let output = try JSONEncoder().encode(entries)
            return .json(output)
        }
    }

    /// directory_tree ツール
    private var directoryTreeTool: BuiltInTool {
        BuiltInTool(
            name: "directory_tree",
            description: "Get a recursive tree view of files and directories. Useful for understanding project structure.",
            inputSchema: .object(
                properties: [
                    "path": .string(description: "Path of the directory to explore"),
                    "maxDepth": .integer(description: "Maximum depth to traverse (default: 3, max: 10)")
                ],
                required: ["path"]
            ),
            annotations: ToolAnnotations(
                title: "Directory Tree",
                readOnlyHint: true,
                openWorldHint: false
            )
        ) { [self] data in
            let input = try JSONDecoder().decode(DirectoryTreeInput.self, from: data)
            let validPath = try validatePath(input.path)
            let maxDepth = min(input.maxDepth ?? 3, 10)

            let tree = buildDirectoryTree(path: validPath, depth: 0, maxDepth: maxDepth)
            let output = try JSONEncoder().encode(tree)
            return .json(output)
        }
    }

    /// move_file ツール
    private var moveFileTool: BuiltInTool {
        BuiltInTool(
            name: "move_file",
            description: "Move or rename files and directories. Both source and destination must be within allowed paths.",
            inputSchema: .object(
                properties: [
                    "source": .string(description: "Source path of the file or directory"),
                    "destination": .string(description: "Destination path")
                ],
                required: ["source", "destination"]
            ),
            annotations: ToolAnnotations(
                title: "Move File",
                readOnlyHint: false,
                destructiveHint: true,
                openWorldHint: false
            )
        ) { [self] data in
            let input = try JSONDecoder().decode(MoveFileInput.self, from: data)
            let validSource = try validatePath(input.source)
            let validDest = try validatePath(input.destination)

            try fileManager.moveItem(atPath: validSource, toPath: validDest)

            return .text("Successfully moved \(validSource) to \(validDest)")
        }
    }

    /// search_files ツール
    private var searchFilesTool: BuiltInTool {
        BuiltInTool(
            name: "search_files",
            description: "Search for files matching a pattern. Supports glob patterns like *.swift or **/*.md",
            inputSchema: .object(
                properties: [
                    "path": .string(description: "Starting directory for search"),
                    "pattern": .string(description: "File name pattern to match (e.g., '*.swift', 'README*')"),
                    "recursive": .boolean(description: "Search subdirectories recursively (default: true)")
                ],
                required: ["path", "pattern"]
            ),
            annotations: ToolAnnotations(
                title: "Search Files",
                readOnlyHint: true,
                openWorldHint: false
            )
        ) { [self] data in
            let input = try JSONDecoder().decode(SearchFilesInput.self, from: data)
            let validPath = try validatePath(input.path)
            let recursive = input.recursive ?? true

            var matches: [String] = []
            let regex = globToRegex(input.pattern)

            if recursive {
                if let enumerator = fileManager.enumerator(atPath: validPath) {
                    while let item = enumerator.nextObject() as? String {
                        let fileName = (item as NSString).lastPathComponent
                        if fileName.range(of: regex, options: .regularExpression) != nil {
                            matches.append(item)
                        }
                    }
                }
            } else {
                let contents = try fileManager.contentsOfDirectory(atPath: validPath)
                for item in contents {
                    if item.range(of: regex, options: .regularExpression) != nil {
                        matches.append(item)
                    }
                }
            }

            let result = SearchResult(
                path: validPath,
                pattern: input.pattern,
                matches: matches.sorted()
            )
            let output = try JSONEncoder().encode(result)
            return .json(output)
        }
    }

    /// get_file_info ツール
    private var getFileInfoTool: BuiltInTool {
        BuiltInTool(
            name: "get_file_info",
            description: "Get detailed information about a file or directory including size, permissions, and timestamps.",
            inputSchema: .object(
                properties: [
                    "path": .string(description: "Path to the file or directory")
                ],
                required: ["path"]
            ),
            annotations: ToolAnnotations(
                title: "Get File Info",
                readOnlyHint: true,
                openWorldHint: false
            )
        ) { [self] data in
            let input = try JSONDecoder().decode(GetFileInfoInput.self, from: data)
            let validPath = try validatePath(input.path)

            let attributes = try fileManager.attributesOfItem(atPath: validPath)

            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: validPath, isDirectory: &isDirectory)

            let info = FileInfo(
                path: validPath,
                type: isDirectory.boolValue ? "directory" : "file",
                size: attributes[.size] as? Int64 ?? 0,
                created: (attributes[.creationDate] as? Date)?.iso8601String,
                modified: (attributes[.modificationDate] as? Date)?.iso8601String,
                permissions: String(format: "%o", (attributes[.posixPermissions] as? Int) ?? 0),
                isReadable: fileManager.isReadableFile(atPath: validPath),
                isWritable: fileManager.isWritableFile(atPath: validPath)
            )

            let output = try JSONEncoder().encode(info)
            return .json(output)
        }
    }

    // MARK: - Helper Methods

    /// ディレクトリツリーを構築
    private func buildDirectoryTree(path: String, depth: Int, maxDepth: Int) -> DirectoryTreeNode {
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: path, isDirectory: &isDirectory)

        let name = (path as NSString).lastPathComponent
        var children: [DirectoryTreeNode]?

        if isDirectory.boolValue && depth < maxDepth {
            if let contents = try? fileManager.contentsOfDirectory(atPath: path) {
                children = contents.sorted().compactMap { item in
                    let itemPath = (path as NSString).appendingPathComponent(item)
                    // 隠しファイルをスキップ
                    guard !item.hasPrefix(".") else { return nil }
                    return buildDirectoryTree(path: itemPath, depth: depth + 1, maxDepth: maxDepth)
                }
            }
        }

        return DirectoryTreeNode(
            name: name,
            type: isDirectory.boolValue ? "directory" : "file",
            children: children
        )
    }

    /// グロブパターンを正規表現に変換
    private func globToRegex(_ pattern: String) -> String {
        var regex = "^"
        for char in pattern {
            switch char {
            case "*":
                regex += ".*"
            case "?":
                regex += "."
            case ".":
                regex += "\\."
            case "[", "]", "(", ")", "{", "}", "+", "^", "$", "|", "\\":
                regex += "\\\(char)"
            default:
                regex += String(char)
            }
        }
        regex += "$"
        return regex
    }
}

// MARK: - Input Types

private struct ReadFileInput: Codable {
    var path: String
}

private struct ReadMultipleFilesInput: Codable {
    var paths: [String]
}

private struct WriteFileInput: Codable {
    var path: String
    var content: String
}

private struct CreateDirectoryInput: Codable {
    var path: String
}

private struct ListDirectoryInput: Codable {
    var path: String
}

private struct DirectoryTreeInput: Codable {
    var path: String
    var maxDepth: Int?
}

private struct MoveFileInput: Codable {
    var source: String
    var destination: String
}

private struct SearchFilesInput: Codable {
    var path: String
    var pattern: String
    var recursive: Bool?
}

private struct GetFileInfoInput: Codable {
    var path: String
}

// MARK: - Result Types

private struct FileReadResult: Codable {
    var path: String
    var content: String?
    var error: String?
}

private struct DirectoryEntry: Codable {
    var name: String
    var type: String
}

private struct DirectoryTreeNode: Codable {
    var name: String
    var type: String
    var children: [DirectoryTreeNode]?
}

private struct SearchResult: Codable {
    var path: String
    var pattern: String
    var matches: [String]
}

private struct FileInfo: Codable {
    var path: String
    var type: String
    var size: Int64
    var created: String?
    var modified: String?
    var permissions: String
    var isReadable: Bool
    var isWritable: Bool
}

// MARK: - Errors

/// FileSystemToolKitのエラー
public enum FileSystemToolKitError: Error, LocalizedError {
    case accessDenied(path: String, allowedPaths: [String])
    case fileNotFound(path: String)
    case encodingError(path: String)
    case operationFailed(message: String)

    public var errorDescription: String? {
        switch self {
        case .accessDenied(let path, let allowedPaths):
            return "Access denied to '\(path)'. Allowed paths: \(allowedPaths.joined(separator: ", "))"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .encodingError(let path):
            return "Could not read file as UTF-8: \(path)"
        case .operationFailed(let message):
            return message
        }
    }
}

// MARK: - Date Extension

private extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
