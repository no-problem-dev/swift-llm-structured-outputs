import Foundation
import LLMClient

// MARK: - LLMTool Protocol

/// LLM が呼び出し可能なツールを定義するプロトコル
///
/// このプロトコルに準拠した型は、LLM からの関数呼び出しを処理できます。
/// 通常は `@Tool` マクロを使用することで自動的に準拠されます。
///
/// ## 使用例（マクロ使用）
///
/// ```swift
/// @Tool("指定された都市の天気を取得します")
/// struct GetWeather {
///     @ToolArgument("都市名")
///     var location: String
///
///     @ToolArgument("温度の単位", .enum(["celsius", "fahrenheit"]))
///     var unit: String?
///
///     func call() async throws -> String {
///         // 天気 API を呼び出す
///         return "東京: 晴れ、25°C"
///     }
/// }
/// ```
///
/// ## 使用例（手動実装）
///
/// ```swift
/// struct GetWeather: LLMTool {
///     static let toolName = "get_weather"
///     static let toolDescription = "指定された都市の天気を取得します"
///
///     @Structured
///     struct Arguments {
///         @StructuredField("都市名")
///         var location: String
///     }
///
///     let arguments: Arguments
///
///     func call() async throws -> ToolResult {
///         return .text("東京: 晴れ、25°C")
///     }
/// }
/// ```
public protocol LLMTool: Sendable {
    /// ツールの識別子
    ///
    /// API で使用される名前です。
    /// `^[a-zA-Z0-9_-]{1,64}$` のパターンに従う必要があります。
    static var toolName: String { get }

    /// ツールの説明
    ///
    /// LLM がツールを選択する際に参照する説明文です。
    /// 詳細に記述することで、適切なタイミングでツールが呼び出されやすくなります。
    static var toolDescription: String { get }

    /// 引数の型
    ///
    /// `StructuredProtocol` に準拠した型で、ツールの入力パラメータを定義します。
    /// `@Structured` マクロで定義された型、または `EmptyArguments` を使用します。
    associatedtype Arguments: StructuredProtocol

    /// 戻り値の型
    ///
    /// `ToolResultConvertible` に準拠した型です。
    /// `String`, `Int`, `Bool`, `ToolResult` などが使用できます。
    associatedtype Result: ToolResultConvertible

    /// ツールに渡された引数
    var arguments: Arguments { get }

    /// ツールを実行
    ///
    /// LLM から呼び出された際に実行されるメソッドです。
    ///
    /// - Returns: ツールの実行結果（`ToolResultConvertible` に準拠した型）
    /// - Throws: 実行中のエラー
    func call() async throws -> Result
}

// MARK: - Default Implementations

extension LLMTool {
    /// 引数の JSON Schema を取得
    public static var argumentsSchema: JSONSchema {
        Arguments.jsonSchema
    }
}

// MARK: - EmptyArguments

/// 引数を持たないツール用の空の引数型
///
/// ツールがパラメータを必要としない場合に使用します。
///
/// ```swift
/// @Tool("現在時刻を取得します")
/// struct GetCurrentTime {
///     // 引数なし - EmptyArguments が自動的に使用される
///
///     func call() async throws -> String {
///         return ISO8601DateFormatter().string(from: Date())
///     }
/// }
/// ```
@Structured
public struct EmptyArguments {
    public init() {}
}
