import Foundation

/// ファイルストレージ操作の抽象化
protocol FileStorageService: Sendable {
    /// データをファイルに保存
    func save(_ data: Data, to path: URL) throws

    /// ファイルからデータを読み込み
    func load(from path: URL) throws -> Data

    /// ファイルを削除
    func delete(at path: URL) throws

    /// ファイルの存在確認
    func exists(at path: URL) -> Bool

    /// ディレクトリ内のファイル一覧を取得
    func listFiles(in directory: URL, withExtension ext: String?) throws -> [URL]

    /// ディレクトリを作成（存在しない場合）
    func ensureDirectory(_ directory: URL) throws
}

enum FileStorageError: LocalizedError {
    case fileNotFound(URL)
    case readFailed(URL, Error)
    case writeFailed(URL, Error)
    case deleteFailed(URL, Error)
    case directoryCreationFailed(URL, Error)
    case listFailed(URL, Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "ファイルが見つかりません: \(url.lastPathComponent)"
        case .readFailed(let url, let error):
            return "読み込みに失敗しました (\(url.lastPathComponent)): \(error.localizedDescription)"
        case .writeFailed(let url, let error):
            return "書き込みに失敗しました (\(url.lastPathComponent)): \(error.localizedDescription)"
        case .deleteFailed(let url, let error):
            return "削除に失敗しました (\(url.lastPathComponent)): \(error.localizedDescription)"
        case .directoryCreationFailed(let url, let error):
            return "ディレクトリ作成に失敗しました (\(url.lastPathComponent)): \(error.localizedDescription)"
        case .listFailed(let url, let error):
            return "ファイル一覧取得に失敗しました (\(url.lastPathComponent)): \(error.localizedDescription)"
        }
    }
}

final class FileStorageServiceImpl: FileStorageService, @unchecked Sendable {

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func save(_ data: Data, to path: URL) throws {
        do {
            try data.write(to: path, options: .atomic)
        } catch {
            throw FileStorageError.writeFailed(path, error)
        }
    }

    func load(from path: URL) throws -> Data {
        guard exists(at: path) else {
            throw FileStorageError.fileNotFound(path)
        }

        do {
            return try Data(contentsOf: path)
        } catch {
            throw FileStorageError.readFailed(path, error)
        }
    }

    func delete(at path: URL) throws {
        guard exists(at: path) else {
            throw FileStorageError.fileNotFound(path)
        }

        do {
            try fileManager.removeItem(at: path)
        } catch {
            throw FileStorageError.deleteFailed(path, error)
        }
    }

    func exists(at path: URL) -> Bool {
        fileManager.fileExists(atPath: path.path)
    }

    func listFiles(in directory: URL, withExtension ext: String?) throws -> [URL] {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )

            if let ext = ext {
                return contents.filter { $0.pathExtension == ext }
            }
            return contents
        } catch {
            throw FileStorageError.listFailed(directory, error)
        }
    }

    func ensureDirectory(_ directory: URL) throws {
        guard !fileManager.fileExists(atPath: directory.path) else { return }

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw FileStorageError.directoryCreationFailed(directory, error)
        }
    }
}
