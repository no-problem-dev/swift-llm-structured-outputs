import Foundation

// MARK: - ToolSetBuilder

/// ツールセット構築用の Result Builder
///
/// Swift の Result Builder 機能を使用して、
/// SwiftUI のような宣言的な DSL でツールセットを構築できます。
///
/// ## 使用例
///
/// ```swift
/// let tools = ToolSet {
///     GetWeatherTool(apiKey: apiKey)
///     SearchTool()
///
///     if needsCalculator {
///         CalculatorTool()
///     }
///
///     for tool in additionalTools {
///         tool
///     }
/// }
/// ```
@resultBuilder
public struct ToolSetBuilder {

    // MARK: - Block Building

    /// 複数のツール配列をブロックとして構築
    ///
    /// - Parameter tools: ツール配列の可変長引数
    /// - Returns: フラット化されたツールの配列
    public static func buildBlock(_ tools: [any Tool]...) -> [any Tool] {
        tools.flatMap { $0 }
    }

    // MARK: - Expression Building

    /// ツールインスタンスを配列として構築
    ///
    /// - Parameter tool: Tool に準拠したツールインスタンス
    /// - Returns: ツールを含む配列
    public static func buildExpression(_ tool: some Tool) -> [any Tool] {
        [tool]
    }

    /// ツール配列をそのまま返す
    ///
    /// ネストされた配列を扱う際に使用されます。
    ///
    /// - Parameter tools: ツール配列
    /// - Returns: そのままのツール配列
    public static func buildExpression(_ tools: [any Tool]) -> [any Tool] {
        tools
    }

    // MARK: - Conditional Building

    /// オプショナルなツールを構築
    ///
    /// `if` 文の条件が `false` の場合に使用されます。
    ///
    /// - Parameter tools: オプショナルなツール配列
    /// - Returns: ツール配列、または空配列
    public static func buildOptional(_ tools: [any Tool]?) -> [any Tool] {
        tools ?? []
    }

    /// 条件分岐の最初の分岐を構築
    ///
    /// `if-else` 文の `if` 部分に使用されます。
    ///
    /// - Parameter tools: ツール配列
    /// - Returns: そのままのツール配列
    public static func buildEither(first tools: [any Tool]) -> [any Tool] {
        tools
    }

    /// 条件分岐の2番目の分岐を構築
    ///
    /// `if-else` 文の `else` 部分に使用されます。
    ///
    /// - Parameter tools: ツール配列
    /// - Returns: そのままのツール配列
    public static func buildEither(second tools: [any Tool]) -> [any Tool] {
        tools
    }

    // MARK: - Array Building

    /// 配列をフラット化して構築
    ///
    /// `for-in` ループで生成されたツールを結合します。
    ///
    /// - Parameter tools: ツール配列の配列
    /// - Returns: フラット化されたツール配列
    public static func buildArray(_ tools: [[any Tool]]) -> [any Tool] {
        tools.flatMap { $0 }
    }

    // MARK: - Final Result

    /// 最終結果を構築
    ///
    /// - Parameter tools: 最終的なツール配列
    /// - Returns: そのままのツール配列
    public static func buildFinalResult(_ tools: [any Tool]) -> [any Tool] {
        tools
    }

    // MARK: - Availability

    /// 制限付きの利用可能性を処理
    ///
    /// `#available` チェックで使用されます。
    ///
    /// - Parameter tools: ツール配列
    /// - Returns: そのままのツール配列
    public static func buildLimitedAvailability(_ tools: [any Tool]) -> [any Tool] {
        tools
    }
}
