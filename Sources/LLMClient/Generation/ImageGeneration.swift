// ImageGeneration.swift
// swift-llm-structured-outputs
//
// 画像生成機能のプロトコルと関連型

import Foundation

// MARK: - ImageGenerationCapable Protocol

/// 画像生成機能を持つクライアントのプロトコル
///
/// このプロトコルを実装するクライアントは、テキストから画像を生成できます。
///
/// ## 使用例
/// ```swift
/// // OpenAI クライアントで画像生成
/// let client = OpenAIClient(apiKey: "sk-...")
/// let image = try await client.generateImage(
///     input: "A cat sitting on a windowsill at sunset",
///     model: .gptImage,
///     size: .square1024
/// )
/// try image.save(to: URL(fileURLWithPath: "cat.png"))
/// ```
public protocol ImageGenerationCapable<ImageModel>: Sendable {
    /// 画像生成で使用可能なモデル型
    associatedtype ImageModel: Sendable

    /// 入力から画像を生成
    ///
    /// - Parameters:
    ///   - input: LLM 入力（プロンプトテキスト）
    ///   - model: 使用する画像生成モデル
    ///   - size: 出力画像のサイズ
    ///   - quality: 画像品質（サポートされる場合）
    ///   - format: 出力フォーマット
    ///   - n: 生成する画像の数（デフォルト: 1）
    /// - Returns: 生成された画像
    /// - Throws: `LLMError` または `ImageGenerationError`
    func generateImage(
        input: LLMInput,
        model: ImageModel,
        size: ImageSize?,
        quality: ImageQuality?,
        format: ImageOutputFormat?,
        n: Int
    ) async throws -> GeneratedImage

    /// 複数の画像を生成
    ///
    /// - Parameters:
    ///   - input: LLM 入力（プロンプトテキスト）
    ///   - model: 使用する画像生成モデル
    ///   - size: 出力画像のサイズ
    ///   - quality: 画像品質
    ///   - format: 出力フォーマット
    ///   - n: 生成する画像の数
    /// - Returns: 生成された画像の配列
    func generateImages(
        input: LLMInput,
        model: ImageModel,
        size: ImageSize?,
        quality: ImageQuality?,
        format: ImageOutputFormat?,
        n: Int
    ) async throws -> [GeneratedImage]
}

// MARK: - Default Implementations

extension ImageGenerationCapable {
    /// 単一の画像を生成（デフォルト引数付き）
    public func generateImage(
        input: LLMInput,
        model: ImageModel,
        size: ImageSize? = nil,
        quality: ImageQuality? = nil,
        format: ImageOutputFormat? = nil,
        n: Int = 1
    ) async throws -> GeneratedImage {
        try await generateImage(
            input: input,
            model: model,
            size: size,
            quality: quality,
            format: format,
            n: n
        )
    }

    /// 複数の画像を生成（デフォルト引数付き）
    public func generateImages(
        input: LLMInput,
        model: ImageModel,
        size: ImageSize? = nil,
        quality: ImageQuality? = nil,
        format: ImageOutputFormat? = nil,
        n: Int = 1
    ) async throws -> [GeneratedImage] {
        try await generateImages(
            input: input,
            model: model,
            size: size,
            quality: quality,
            format: format,
            n: n
        )
    }
}

// MARK: - ImageSize

/// 画像サイズ
///
/// 生成する画像のサイズを指定します。
/// 利用可能なサイズはモデルによって異なります。
public enum ImageSize: String, Sendable, Codable, CaseIterable, Equatable {
    // MARK: - Square Sizes

    /// 256x256 ピクセル
    case square256 = "256x256"

    /// 512x512 ピクセル
    case square512 = "512x512"

    /// 1024x1024 ピクセル（標準）
    case square1024 = "1024x1024"

    // MARK: - Landscape Sizes

    /// 1792x1024 ピクセル（横長）
    case landscape1792x1024 = "1792x1024"

    /// 1536x1024 ピクセル（横長）
    case landscape1536x1024 = "1536x1024"

    // MARK: - Portrait Sizes

    /// 1024x1792 ピクセル（縦長）
    case portrait1024x1792 = "1024x1792"

    /// 1024x1536 ピクセル（縦長）
    case portrait1024x1536 = "1024x1536"

    // MARK: - Properties

    /// 幅（ピクセル）
    public var width: Int {
        switch self {
        case .square256: return 256
        case .square512: return 512
        case .square1024: return 1024
        case .landscape1792x1024: return 1792
        case .landscape1536x1024: return 1536
        case .portrait1024x1792: return 1024
        case .portrait1024x1536: return 1024
        }
    }

    /// 高さ（ピクセル）
    public var height: Int {
        switch self {
        case .square256: return 256
        case .square512: return 512
        case .square1024: return 1024
        case .landscape1792x1024: return 1024
        case .landscape1536x1024: return 1024
        case .portrait1024x1792: return 1792
        case .portrait1024x1536: return 1536
        }
    }

    /// 正方形かどうか
    public var isSquare: Bool { width == height }

    /// 横長かどうか
    public var isLandscape: Bool { width > height }

    /// 縦長かどうか
    public var isPortrait: Bool { height > width }

    // MARK: - Provider Compatibility

    /// OpenAI DALL-E 3 でサポートされるサイズ
    public static var dalle3Sizes: [ImageSize] {
        [.square1024, .landscape1792x1024, .portrait1024x1792]
    }

    /// OpenAI GPT-Image でサポートされるサイズ
    public static var gptImageSizes: [ImageSize] {
        [.square1024, .landscape1536x1024, .portrait1024x1536, .square256, .square512]
    }

    /// Gemini Imagen でサポートされるサイズ（Imagen 3/4 共通）
    public static var imagen3Sizes: [ImageSize] {
        [.square1024, .landscape1536x1024, .portrait1024x1536]
    }
}

// MARK: - ImageQuality

/// 画像品質
public enum ImageQuality: String, Sendable, Codable, CaseIterable, Equatable {
    /// 標準品質（高速）
    case standard
    /// 高品質（HD）
    case hd
}

// MARK: - ImageStyle

/// 画像スタイル（OpenAI DALL-E 3 専用）
public enum ImageStyle: String, Sendable, Codable, CaseIterable, Equatable {
    /// 写実的なスタイル
    case vivid
    /// より自然なスタイル
    case natural
}

// MARK: - OpenAI Image Models

/// OpenAI 画像生成モデル
public enum OpenAIImageModel: String, Sendable, Codable, CaseIterable, Equatable {
    /// DALL-E 3（高品質画像生成）
    case dalle3 = "dall-e-3"
    /// DALL-E 2（従来モデル）
    case dalle2 = "dall-e-2"
    /// GPT-Image（GPT-4oベースの画像生成）
    case gptImage = "gpt-image-1"

    /// モデル ID
    public var id: String { rawValue }

    /// 表示名
    public var displayName: String {
        switch self {
        case .dalle3: return "DALL-E 3"
        case .dalle2: return "DALL-E 2"
        case .gptImage: return "GPT-Image"
        }
    }

    /// サポートされる画像サイズ
    public var supportedSizes: [ImageSize] {
        switch self {
        case .dalle3: return ImageSize.dalle3Sizes
        case .dalle2: return [.square256, .square512, .square1024]
        case .gptImage: return ImageSize.gptImageSizes
        }
    }

    /// 最大生成枚数
    public var maxImages: Int {
        switch self {
        case .dalle3: return 1
        case .dalle2: return 10
        case .gptImage: return 4
        }
    }
}

// MARK: - Gemini Image Models

/// Gemini 画像生成モデル
///
/// 注意: Imagen 3 は Gemini API (generativelanguage.googleapis.com) では
/// まだ公開されていません（Vertex AI のみ）。
/// 利用可能なモデルは Imagen 4 および Gemini Image モデルです。
public enum GeminiImageModel: String, Sendable, Codable, CaseIterable, Equatable {
    // MARK: - Imagen 4 Models
    /// Imagen 4（最新・高品質画像生成）
    case imagen4 = "imagen-4.0-generate-001"
    /// Imagen 4 Ultra（最高品質）
    case imagen4Ultra = "imagen-4.0-ultra-generate-001"
    /// Imagen 4 Fast（高速画像生成）
    case imagen4Fast = "imagen-4.0-fast-generate-001"

    // MARK: - Gemini Image Models（マルチモーダル画像生成）
    /// Gemini 2.0 Flash Image（高速・効率的、1024px）
    case gemini20FlashImage = "gemini-2.0-flash-exp-image-generation"

    /// モデル ID
    public var id: String { rawValue }

    /// 表示名
    public var displayName: String {
        switch self {
        case .imagen4: return "Imagen 4"
        case .imagen4Ultra: return "Imagen 4 Ultra"
        case .imagen4Fast: return "Imagen 4 Fast"
        case .gemini20FlashImage: return "Gemini 2.0 Flash Image"
        }
    }

    /// Imagen モデルかどうか
    public var isImagenModel: Bool {
        switch self {
        case .imagen4, .imagen4Ultra, .imagen4Fast:
            return true
        case .gemini20FlashImage:
            return false
        }
    }

    /// サポートされる画像サイズ
    public var supportedSizes: [ImageSize] {
        switch self {
        case .imagen4, .imagen4Ultra, .imagen4Fast:
            return ImageSize.imagen3Sizes
        case .gemini20FlashImage:
            // Gemini Image モデルは固定サイズ
            return [.square1024]
        }
    }

    /// 最大生成枚数
    public var maxImages: Int {
        switch self {
        case .imagen4, .imagen4Ultra, .imagen4Fast:
            return 4
        case .gemini20FlashImage:
            return 1  // Gemini Image は1枚ずつ
        }
    }
}

// MARK: - ImageGenerationError

/// 画像生成固有のエラー
public enum ImageGenerationError: Error, Sendable, LocalizedError {
    /// プロンプトが安全性ポリシーに違反
    case contentPolicyViolation(String?)
    /// サイズがモデルでサポートされていない
    case unsupportedSize(ImageSize, model: String)
    /// フォーマットがモデルでサポートされていない
    case unsupportedFormat(ImageOutputFormat, model: String)
    /// 生成枚数が上限を超えている
    case exceedsMaxImages(requested: Int, maximum: Int)
    /// 画像生成がこのプロバイダーでサポートされていない
    case notSupportedByProvider(String)

    public var errorDescription: String? {
        switch self {
        case .contentPolicyViolation(let reason):
            return "Content policy violation\(reason.map { ": \($0)" } ?? "")"
        case .unsupportedSize(let size, let model):
            return "Size \(size.rawValue) is not supported by \(model)"
        case .unsupportedFormat(let format, let model):
            return "Format \(format.rawValue) is not supported by \(model)"
        case .exceedsMaxImages(let requested, let maximum):
            return "Requested \(requested) images, but maximum is \(maximum)"
        case .notSupportedByProvider(let provider):
            return "Image generation is not supported by \(provider)"
        }
    }
}
