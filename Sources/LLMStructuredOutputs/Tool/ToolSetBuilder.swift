import Foundation

// MARK: - ToolSetBuilder

/// ツールセット構築用の Result Builder
///
/// Swift の Result Builder 機能を使用して、
/// 宣言的な DSL でツールセットを構築できます。
///
/// ## 使用例
///
/// ```swift
/// let tools = ToolSet {
///     GetWeatherTool.self
///     SearchTool.self
///
///     if needsCalculator {
///         CalculatorTool.self
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
    /// - Parameter toolTypes: ツール型配列の可変長引数
    /// - Returns: フラット化されたツール型の配列
    public static func buildBlock(_ toolTypes: [any LLMToolRegistrable.Type]...) -> [any LLMToolRegistrable.Type] {
        toolTypes.flatMap { $0 }
    }

    // MARK: - Expression Building

    /// ツールタイプを配列として構築
    ///
    /// - Parameter toolType: LLMToolRegistrable に準拠したツールタイプ
    /// - Returns: ツール型を含む配列
    public static func buildExpression<T: LLMToolRegistrable>(_ toolType: T.Type) -> [any LLMToolRegistrable.Type] {
        [toolType]
    }

    /// ツール型配列をそのまま返す
    ///
    /// ネストされた配列を扱う際に使用されます。
    ///
    /// - Parameter toolTypes: ツール型配列
    /// - Returns: そのままのツール型配列
    public static func buildExpression(_ toolTypes: [any LLMToolRegistrable.Type]) -> [any LLMToolRegistrable.Type] {
        toolTypes
    }

    // MARK: - Conditional Building

    /// オプショナルなツールを構築
    ///
    /// `if` 文の条件が `false` の場合に使用されます。
    ///
    /// - Parameter toolTypes: オプショナルなツール型配列
    /// - Returns: ツール型配列、または空配列
    public static func buildOptional(_ toolTypes: [any LLMToolRegistrable.Type]?) -> [any LLMToolRegistrable.Type] {
        toolTypes ?? []
    }

    /// 条件分岐の最初の分岐を構築
    ///
    /// `if-else` 文の `if` 部分に使用されます。
    ///
    /// - Parameter toolTypes: ツール型配列
    /// - Returns: そのままのツール型配列
    public static func buildEither(first toolTypes: [any LLMToolRegistrable.Type]) -> [any LLMToolRegistrable.Type] {
        toolTypes
    }

    /// 条件分岐の2番目の分岐を構築
    ///
    /// `if-else` 文の `else` 部分に使用されます。
    ///
    /// - Parameter toolTypes: ツール型配列
    /// - Returns: そのままのツール型配列
    public static func buildEither(second toolTypes: [any LLMToolRegistrable.Type]) -> [any LLMToolRegistrable.Type] {
        toolTypes
    }

    // MARK: - Array Building

    /// 配列をフラット化して構築
    ///
    /// `for-in` ループで生成されたツールを結合します。
    ///
    /// - Parameter toolTypes: ツール型配列の配列
    /// - Returns: フラット化されたツール型配列
    public static func buildArray(_ toolTypes: [[any LLMToolRegistrable.Type]]) -> [any LLMToolRegistrable.Type] {
        toolTypes.flatMap { $0 }
    }

    // MARK: - Final Result

    /// 最終結果を構築
    ///
    /// - Parameter toolTypes: 最終的なツール型配列
    /// - Returns: そのままのツール型配列
    public static func buildFinalResult(_ toolTypes: [any LLMToolRegistrable.Type]) -> [any LLMToolRegistrable.Type] {
        toolTypes
    }

    // MARK: - Availability

    /// 制限付きの利用可能性を処理
    ///
    /// `#available` チェックで使用されます。
    ///
    /// - Parameter toolTypes: ツール型配列
    /// - Returns: そのままのツール型配列
    public static func buildLimitedAvailability(_ toolTypes: [any LLMToolRegistrable.Type]) -> [any LLMToolRegistrable.Type] {
        toolTypes
    }
}
