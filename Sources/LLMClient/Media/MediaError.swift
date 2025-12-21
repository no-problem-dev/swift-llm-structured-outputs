// MediaError.swift
// swift-llm-structured-outputs
//
// Created by Claude on 2025-12-20.

import Foundation

// MARK: - Media Error

/// メディア関連エラー
///
/// メディアコンテンツの処理中に発生するエラーを表現します。
///
/// ## エラーカテゴリ
/// - **フォーマット関連**: サポートされていない形式
/// - **サイズ関連**: 制限超過
/// - **プロバイダー関連**: 機能非対応
/// - **ファイル関連**: 読み込みエラー
/// - **データ関連**: 無効なデータ
///
/// ## 使用例
/// ```swift
/// do {
///     let image = try ImageContent.file(at: "/path/to/image.xyz")
/// } catch MediaError.unsupportedFormat(let format) {
///     print("Unsupported format: \(format)")
/// } catch MediaError.fileReadError(let error) {
///     print("File read error: \(error)")
/// }
/// ```
public enum MediaError: Error, Sendable, Equatable {
    /// サポートされていないフォーマット
    case unsupportedFormat(String)

    /// サイズ制限超過
    case sizeLimitExceeded(size: Int, maxSize: Int)

    /// プロバイダーが機能をサポートしていない
    case notSupportedByProvider(feature: String, provider: ProviderType)

    /// ファイル読み込みエラー
    case fileReadError(Error)

    /// 無効なメディアデータ
    case invalidMediaData(String)

    /// メディアタイプ不一致
    case mediaTypeMismatch(expected: String, actual: String)

    /// 必須パラメータの欠如
    case missingRequiredParameter(String)

    /// 無効なURL
    case invalidURL(String)

    // MARK: - Equatable

    public static func == (lhs: MediaError, rhs: MediaError) -> Bool {
        switch (lhs, rhs) {
        case (.unsupportedFormat(let l), .unsupportedFormat(let r)):
            return l == r
        case (.sizeLimitExceeded(let ls, let lm), .sizeLimitExceeded(let rs, let rm)):
            return ls == rs && lm == rm
        case (.notSupportedByProvider(let lf, let lp), .notSupportedByProvider(let rf, let rp)):
            return lf == rf && lp == rp
        case (.fileReadError(let l), .fileReadError(let r)):
            return l.localizedDescription == r.localizedDescription
        case (.invalidMediaData(let l), .invalidMediaData(let r)):
            return l == r
        case (.mediaTypeMismatch(let le, let la), .mediaTypeMismatch(let re, let ra)):
            return le == re && la == ra
        case (.missingRequiredParameter(let l), .missingRequiredParameter(let r)):
            return l == r
        case (.invalidURL(let l), .invalidURL(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - LocalizedError

extension MediaError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "Unsupported media format: \(format)"

        case .sizeLimitExceeded(let size, let maxSize):
            let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .binary)
            let maxStr = ByteCountFormatter.string(fromByteCount: Int64(maxSize), countStyle: .binary)
            return "Media size (\(sizeStr)) exceeds limit (\(maxStr))"

        case .notSupportedByProvider(let feature, let provider):
            return "\(feature) is not supported by \(provider.displayName)"

        case .fileReadError(let error):
            return "Failed to read file: \(error.localizedDescription)"

        case .invalidMediaData(let reason):
            return "Invalid media data: \(reason)"

        case .mediaTypeMismatch(let expected, let actual):
            return "Media type mismatch: expected \(expected), got \(actual)"

        case .missingRequiredParameter(let param):
            return "Missing required parameter: \(param)"

        case .invalidURL(let urlString):
            return "Invalid URL: \(urlString)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .unsupportedFormat:
            return "The media format is not supported by any provider"
        case .sizeLimitExceeded:
            return "The media file is too large for the provider's limits"
        case .notSupportedByProvider:
            return "This feature is not available for the selected provider"
        case .fileReadError:
            return "The file could not be read from disk"
        case .invalidMediaData:
            return "The media data is corrupted or in an invalid format"
        case .mediaTypeMismatch:
            return "The media type does not match the expected type"
        case .missingRequiredParameter:
            return "A required parameter was not provided"
        case .invalidURL:
            return "The URL string could not be parsed"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "Convert the file to a supported format. Format '\(format)' is not supported."
        case .sizeLimitExceeded(_, let maxSize):
            let maxStr = ByteCountFormatter.string(fromByteCount: Int64(maxSize), countStyle: .binary)
            return "Reduce the file size to under \(maxStr) or use the File API for larger files."
        case .notSupportedByProvider(let feature, let provider):
            return "Use a different provider that supports \(feature), or remove the \(feature) from your request. \(provider.displayName) does not support this feature."
        case .fileReadError:
            return "Check that the file exists and you have permission to read it."
        case .invalidMediaData:
            return "Ensure the media data is valid and not corrupted."
        case .mediaTypeMismatch:
            return "Provide media content with the correct type."
        case .missingRequiredParameter(let param):
            return "Provide a value for '\(param)'."
        case .invalidURL:
            return "Provide a valid URL string."
        }
    }
}

// MARK: - CustomNSError

extension MediaError: CustomNSError {
    public static var errorDomain: String {
        "LLMStructuredOutputs.MediaError"
    }

    public var errorCode: Int {
        switch self {
        case .unsupportedFormat: return 1001
        case .sizeLimitExceeded: return 1002
        case .notSupportedByProvider: return 1003
        case .fileReadError: return 1004
        case .invalidMediaData: return 1005
        case .mediaTypeMismatch: return 1006
        case .missingRequiredParameter: return 1007
        case .invalidURL: return 1008
        }
    }

    public var errorUserInfo: [String: Any] {
        var info: [String: Any] = [
            NSLocalizedDescriptionKey: errorDescription ?? "Unknown error"
        ]
        if let reason = failureReason {
            info[NSLocalizedFailureReasonErrorKey] = reason
        }
        if let suggestion = recoverySuggestion {
            info[NSLocalizedRecoverySuggestionErrorKey] = suggestion
        }
        return info
    }
}

// MARK: - Convenience

extension MediaError {
    /// プロバイダーのサイズ制限に対してバリデーション
    ///
    /// - Parameters:
    ///   - size: 実際のサイズ
    ///   - maxSize: 最大許容サイズ
    /// - Throws: `MediaError.sizeLimitExceeded` サイズ超過時
    public static func validateSize(_ size: Int, maxSize: Int) throws {
        if size > maxSize {
            throw MediaError.sizeLimitExceeded(size: size, maxSize: maxSize)
        }
    }

    /// プロバイダーのメディアタイプサポートをバリデーション
    ///
    /// - Parameters:
    ///   - mediaType: バリデーションするメディアタイプ
    ///   - provider: ターゲットプロバイダー
    /// - Throws: `MediaError.notSupportedByProvider` 未サポート時
    public static func validateSupport<T: MediaType>(
        _ mediaType: T,
        for provider: ProviderType
    ) throws {
        if !mediaType.isSupported(by: provider) {
            throw MediaError.notSupportedByProvider(
                feature: "Media type '\(mediaType.mimeType)'",
                provider: provider
            )
        }
    }
}
