import Foundation
import LLMClient

// MARK: - Tool Protocol

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
///     // 設定プロパティ（オプショナル）
///     var apiKey: String?
///
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
/// ## ToolSet での使用
///
/// ```swift
/// let tools = ToolSet {
///     GetWeather(apiKey: "xxx")
///     SearchWeb()
///     Calculator()
/// }
/// ```
public protocol Tool: Sendable {
    /// ツールの識別子
    ///
    /// API で使用される名前です。
    /// `^[a-zA-Z0-9_-]{1,64}$` のパターンに従う必要があります。
    var toolName: String { get }

    /// ツールの説明
    ///
    /// LLM がツールを選択する際に参照する説明文です。
    /// 詳細に記述することで、適切なタイミングでツールが呼び出されやすくなります。
    var toolDescription: String { get }

    /// 引数の JSON Schema
    ///
    /// ツールの入力パラメータを定義する JSON Schema です。
    var inputSchema: JSONSchema { get }

    /// ツールを実行
    ///
    /// LLM から呼び出された際に実行されるメソッドです。
    /// インスタンスメソッドとして実装することで、設定プロパティにアクセスできます。
    ///
    /// - Parameter argumentsData: 引数の JSON データ
    /// - Returns: ツールの実行結果
    /// - Throws: 引数のデコードエラーまたは実行エラー
    func execute(with argumentsData: Data) async throws -> ToolResult
}

// MARK: - Tool Convenience Properties

extension Tool {
    /// ツール名へのエイリアス
    public var name: String { toolName }

    /// ツールの説明へのエイリアス
    public var description: String { toolDescription }
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
