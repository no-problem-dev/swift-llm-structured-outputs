// GeneratedImage.swift
// swift-llm-structured-outputs
//
// 生成された画像コンテンツの定義

import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - GeneratedMediaProtocol

/// 生成メディアコンテンツ共通プロトコル
///
/// LLM によって生成されたメディア（画像、音声など）が準拠するプロトコルです。
/// 入力側の `MediaContentProtocol` に対応する出力側のプロトコルです。
///
/// ## 準拠する型
/// - `GeneratedImage` - 生成された画像
/// - `GeneratedAudio` - 生成された音声
public protocol GeneratedMediaProtocol: Sendable, Codable, Equatable {
    /// 生成されたデータ
    var data: Data { get }

    /// MIME タイプ文字列
    var mimeType: String { get }

    /// ファイル保存用の拡張子
    var fileExtension: String { get }
}

// MARK: - GeneratedMediaProtocol Default Implementation

extension GeneratedMediaProtocol {
    /// ファイルに保存
    ///
    /// - Parameter url: 保存先のファイルURL
    /// - Throws: ファイル書き込みエラー
    public func save(to url: URL) throws {
        try data.write(to: url)
    }

    /// 推奨されるファイル名を生成
    ///
    /// - Parameter baseName: ベース名（拡張子なし）
    /// - Returns: 拡張子付きのファイル名
    public func suggestedFileName(baseName: String = "generated") -> String {
        "\(baseName).\(fileExtension)"
    }
}

// MARK: - GeneratedImage

/// 生成された画像
///
/// LLM によって生成された画像データを表現します。
/// OpenAI DALL-E/GPT-Image や Gemini による画像生成の結果として返されます。
///
/// ## プロバイダー別の特性
/// - **OpenAI**: `revisedPrompt` が含まれる場合があります（プロンプトの自動修正）
/// - **Gemini**: テキストと画像が混在したレスポンスの一部として返されます
///
/// ## 使用例
/// ```swift
/// // 画像を生成
/// let image = try await client.generateImage(
///     prompt: "A cat sitting on a window sill",
///     model: .gptImage
/// )
///
/// // ファイルに保存
/// try image.save(to: URL(fileURLWithPath: "cat.png"))
///
/// // UIImage に変換（iOS）
/// if let uiImage = image.uiImage {
///     imageView.image = uiImage
/// }
/// ```
public struct GeneratedImage: GeneratedMediaProtocol {
    // MARK: - Properties

    /// 生成された画像データ（Base64デコード済み）
    public let data: Data

    /// 画像フォーマット
    public let format: ImageOutputFormat

    /// 修正されたプロンプト（OpenAI DALL-E/GPT-Image）
    ///
    /// OpenAI の画像生成 API は、安全性やクオリティのためにプロンプトを
    /// 自動的に修正することがあります。その場合、修正後のプロンプトがここに格納されます。
    public let revisedPrompt: String?

    // MARK: - GeneratedMediaProtocol

    /// MIME タイプ文字列
    public var mimeType: String { format.mimeType }

    /// ファイル拡張子
    public var fileExtension: String { format.fileExtension }

    // MARK: - Initializers

    /// 初期化
    ///
    /// - Parameters:
    ///   - data: 画像データ
    ///   - format: 画像フォーマット
    ///   - revisedPrompt: 修正されたプロンプト（オプション）
    public init(
        data: Data,
        format: ImageOutputFormat,
        revisedPrompt: String? = nil
    ) {
        self.data = data
        self.format = format
        self.revisedPrompt = revisedPrompt
    }

    /// Base64 文字列から初期化
    ///
    /// - Parameters:
    ///   - base64String: Base64 エンコードされた画像データ
    ///   - format: 画像フォーマット
    ///   - revisedPrompt: 修正されたプロンプト（オプション）
    /// - Throws: Base64 デコードに失敗した場合
    public init(
        base64String: String,
        format: ImageOutputFormat,
        revisedPrompt: String? = nil
    ) throws {
        guard let data = Data(base64Encoded: base64String) else {
            throw GeneratedMediaError.invalidBase64Data
        }
        self.data = data
        self.format = format
        self.revisedPrompt = revisedPrompt
    }

    // MARK: - Image Conversion

    #if canImport(UIKit)
    /// UIImage に変換（iOS/tvOS/watchOS/visionOS）
    ///
    /// - Returns: 変換された UIImage、変換に失敗した場合は nil
    public var uiImage: UIImage? {
        UIImage(data: data)
    }
    #endif

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// NSImage に変換（macOS）
    ///
    /// - Returns: 変換された NSImage、変換に失敗した場合は nil
    public var nsImage: NSImage? {
        NSImage(data: data)
    }
    #endif

    #if canImport(CoreGraphics)
    /// CGImage に変換
    ///
    /// - Returns: 変換された CGImage、変換に失敗した場合は nil
    public var cgImage: CGImage? {
        #if canImport(UIKit)
        return uiImage?.cgImage
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        return nsImage?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        return nil
        #endif
    }
    #endif

    // MARK: - Metadata

    /// 画像のサイズ（ピクセル）
    ///
    /// - Returns: 画像サイズ、取得に失敗した場合は nil
    public var imageSize: (width: Int, height: Int)? {
        #if canImport(CoreGraphics)
        guard let cgImage = cgImage else { return nil }
        return (width: cgImage.width, height: cgImage.height)
        #else
        return nil
        #endif
    }

    /// データサイズ（バイト）
    public var dataSize: Int {
        data.count
    }

    /// Base64 エンコードされた文字列
    public var base64String: String {
        data.base64EncodedString()
    }

    /// Data URL 形式の文字列
    ///
    /// HTML や CSS で使用可能な形式です。
    /// 例: `data:image/png;base64,iVBORw0KGgo...`
    public var dataURL: String {
        "data:\(mimeType);base64,\(base64String)"
    }
}

// MARK: - GeneratedMediaError

/// 生成メディア関連エラー
public enum GeneratedMediaError: Error, Sendable, LocalizedError {
    /// 無効な Base64 データ
    case invalidBase64Data

    /// 無効な画像データ
    case invalidImageData

    /// ファイル保存エラー
    case saveError(Error)

    /// ダウンロードエラー
    case downloadError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidBase64Data:
            return "Invalid Base64 encoded data"
        case .invalidImageData:
            return "Invalid image data"
        case .saveError(let error):
            return "Failed to save file: \(error.localizedDescription)"
        case .downloadError(let error):
            return "Failed to download: \(error.localizedDescription)"
        }
    }
}

// MARK: - Codable

extension GeneratedImage {
    private enum CodingKeys: String, CodingKey {
        case data
        case format
        case revisedPrompt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.data = try container.decode(Data.self, forKey: .data)
        self.format = try container.decode(ImageOutputFormat.self, forKey: .format)
        self.revisedPrompt = try container.decodeIfPresent(String.self, forKey: .revisedPrompt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
        try container.encode(format, forKey: .format)
        try container.encodeIfPresent(revisedPrompt, forKey: .revisedPrompt)
    }
}
