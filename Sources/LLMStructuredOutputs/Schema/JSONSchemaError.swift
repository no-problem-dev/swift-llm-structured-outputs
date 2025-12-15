import Foundation

// MARK: - JSONSchemaError

/// JSON Schema に関連するエラー
///
/// JSON Schema の処理中に発生する可能性のあるエラーを表します。
public enum JSONSchemaError: Error, Sendable {
    /// JSON エンコーディングに失敗
    ///
    /// スキーマを JSON 文字列に変換する際に、
    /// UTF-8 エンコーディングに失敗した場合に発生します。
    case encodingFailed
}

// MARK: - LocalizedError

extension JSONSchemaError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "JSON Schema のエンコードに失敗しました"
        }
    }
}
