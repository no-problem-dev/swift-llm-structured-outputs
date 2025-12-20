// MediaSource.swift
// swift-llm-structured-outputs
//
// Created by Claude on 2025-12-20.

import Foundation

// MARK: - Media Source

/// メディアデータのソース
///
/// メディアコンテンツは以下の3つの方法で提供できます：
/// - Base64エンコードされたバイナリデータ
/// - アクセス可能なURL
/// - プロバイダーのFile API経由のファイル参照
///
/// ## 使用例
/// ```swift
/// // Base64データから
/// let imageData = try Data(contentsOf: imageFileURL)
/// let source = MediaSource.base64(imageData)
///
/// // URLから
/// let source = MediaSource.url(URL(string: "https://example.com/image.jpg")!)
///
/// // ファイル参照から（Gemini File API など）
/// let source = MediaSource.fileReference(id: "files/abc123")
/// ```
public enum MediaSource: Sendable, Equatable {
    /// Base64エンコードされたバイナリデータ
    case base64(Data)

    /// アクセス可能なURL（HTTP/HTTPS）
    case url(URL)

    /// ファイルAPI参照（Gemini File API, OpenAI Files API）
    case fileReference(id: String)

    // MARK: - Convenience Accessors

    /// Base64文字列を取得
    public var base64String: String? {
        guard case .base64(let data) = self else { return nil }
        return data.base64EncodedString()
    }

    /// URLを取得
    public var urlValue: URL? {
        guard case .url(let url) = self else { return nil }
        return url
    }

    /// ファイル参照IDを取得
    public var fileReferenceId: String? {
        guard case .fileReference(let id) = self else { return nil }
        return id
    }

    /// 生のDataを取得（base64の場合のみ）
    public var data: Data? {
        guard case .base64(let data) = self else { return nil }
        return data
    }

    // MARK: - Validation

    /// データサイズを取得（base64の場合のみ）
    public var dataSize: Int? {
        guard case .base64(let data) = self else { return nil }
        return data.count
    }

    /// 指定サイズ以下かチェック
    ///
    /// - Parameter maxBytes: 最大バイト数
    /// - Returns: 制限内の場合は true、それ以外（非base64含む）は true
    public func isWithinSizeLimit(_ maxBytes: Int) -> Bool {
        guard let size = dataSize else { return true }
        return size <= maxBytes
    }

    /// サイズバリデーションを実行
    ///
    /// - Parameter maxBytes: 最大バイト数
    /// - Throws: `MediaError.sizeLimitExceeded` サイズ超過時
    public func validateSize(maxBytes: Int) throws {
        guard let size = dataSize else { return }
        if size > maxBytes {
            throw MediaError.sizeLimitExceeded(size: size, maxSize: maxBytes)
        }
    }

    // MARK: - Source Type Info

    /// ソースタイプを表す文字列
    public var sourceType: String {
        switch self {
        case .base64: return "base64"
        case .url: return "url"
        case .fileReference: return "fileReference"
        }
    }

    /// Base64ソースかどうか
    public var isBase64: Bool {
        if case .base64 = self { return true }
        return false
    }

    /// URLソースかどうか
    public var isURL: Bool {
        if case .url = self { return true }
        return false
    }

    /// ファイル参照ソースかどうか
    public var isFileReference: Bool {
        if case .fileReference = self { return true }
        return false
    }
}

// MARK: - Codable Implementation

extension MediaSource: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case data
        case url
        case fileId
    }

    private enum SourceType: String, Codable {
        case base64
        case url
        case fileReference
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(SourceType.self, forKey: .type)

        switch type {
        case .base64:
            let data = try container.decode(Data.self, forKey: .data)
            self = .base64(data)
        case .url:
            let url = try container.decode(URL.self, forKey: .url)
            self = .url(url)
        case .fileReference:
            let id = try container.decode(String.self, forKey: .fileId)
            self = .fileReference(id: id)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .base64(let data):
            try container.encode(SourceType.base64, forKey: .type)
            try container.encode(data, forKey: .data)
        case .url(let url):
            try container.encode(SourceType.url, forKey: .type)
            try container.encode(url, forKey: .url)
        case .fileReference(let id):
            try container.encode(SourceType.fileReference, forKey: .type)
            try container.encode(id, forKey: .fileId)
        }
    }
}

// MARK: - Convenience Initializers

extension MediaSource {
    /// ローカルファイルからBase64ソースを作成
    ///
    /// - Parameter filePath: ファイルパス
    /// - Returns: Base64エンコードされたデータソース
    /// - Throws: ファイル読み込みエラー
    public static func fromFile(at filePath: String) throws -> MediaSource {
        let url = URL(fileURLWithPath: filePath)
        return try fromFile(at: url)
    }

    /// ローカルファイルからBase64ソースを作成
    ///
    /// - Parameter url: ファイルURL
    /// - Returns: Base64エンコードされたデータソース
    /// - Throws: ファイル読み込みエラー
    public static func fromFile(at url: URL) throws -> MediaSource {
        do {
            let data = try Data(contentsOf: url)
            return .base64(data)
        } catch {
            throw MediaError.fileReadError(error)
        }
    }

    /// Base64文字列からソースを作成
    ///
    /// - Parameter base64String: Base64エンコードされた文字列
    /// - Returns: デコードされたデータソース
    /// - Throws: `MediaError.invalidMediaData` デコード失敗時
    public static func fromBase64String(_ base64String: String) throws -> MediaSource {
        guard let data = Data(base64Encoded: base64String) else {
            throw MediaError.invalidMediaData("Invalid Base64 string")
        }
        return .base64(data)
    }
}

// MARK: - CustomStringConvertible

extension MediaSource: CustomStringConvertible {
    public var description: String {
        switch self {
        case .base64(let data):
            return "MediaSource.base64(\(data.count) bytes)"
        case .url(let url):
            return "MediaSource.url(\(url.absoluteString))"
        case .fileReference(let id):
            return "MediaSource.fileReference(\(id))"
        }
    }
}
