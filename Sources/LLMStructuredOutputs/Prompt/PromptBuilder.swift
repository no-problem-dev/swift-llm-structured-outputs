import Foundation

// MARK: - PromptBuilder

/// プロンプト構築用の Result Builder
///
/// Swift の Result Builder 機能を使用して、
/// 宣言的な DSL でプロンプトを構築できます。
///
/// ## 使用例
///
/// ```swift
/// let prompt = Prompt {
///     PromptComponent.role("データアナリスト")
///     PromptComponent.objective("情報抽出")
///
///     if needsExamples {
///         PromptComponent.example(input: "...", output: "...")
///     }
///
///     for step in thinkingSteps {
///         PromptComponent.thinkingStep(step)
///     }
/// }
/// ```
@resultBuilder
public struct PromptBuilder {

    /// 複数のコンポーネント配列をブロックとして構築
    ///
    /// - Parameter components: プロンプトコンポーネント配列の可変長引数
    /// - Returns: フラット化されたコンポーネントの配列
    public static func buildBlock(_ components: [PromptComponent]...) -> [PromptComponent] {
        components.flatMap { $0 }
    }

    /// オプショナルなコンポーネントを構築
    ///
    /// `if` 文の条件が `false` の場合に使用されます。
    ///
    /// - Parameter component: オプショナルなコンポーネント配列
    /// - Returns: コンポーネント配列、または空配列
    public static func buildOptional(_ component: [PromptComponent]?) -> [PromptComponent] {
        component ?? []
    }

    /// 条件分岐の最初の分岐を構築
    ///
    /// `if-else` 文の `if` 部分に使用されます。
    ///
    /// - Parameter component: コンポーネント配列
    /// - Returns: そのままのコンポーネント配列
    public static func buildEither(first component: [PromptComponent]) -> [PromptComponent] {
        component
    }

    /// 条件分岐の2番目の分岐を構築
    ///
    /// `if-else` 文の `else` 部分に使用されます。
    ///
    /// - Parameter component: コンポーネント配列
    /// - Returns: そのままのコンポーネント配列
    public static func buildEither(second component: [PromptComponent]) -> [PromptComponent] {
        component
    }

    /// 配列をフラット化して構築
    ///
    /// `for-in` ループで生成されたコンポーネントを結合します。
    ///
    /// - Parameter components: コンポーネント配列の配列
    /// - Returns: フラット化されたコンポーネント配列
    public static func buildArray(_ components: [[PromptComponent]]) -> [PromptComponent] {
        components.flatMap { $0 }
    }

    /// 単一のコンポーネントを配列として構築
    ///
    /// - Parameter expression: 単一のプロンプトコンポーネント
    /// - Returns: コンポーネントを含む配列
    public static func buildExpression(_ expression: PromptComponent) -> [PromptComponent] {
        [expression]
    }

    /// コンポーネント配列をそのまま返す
    ///
    /// ネストされた配列を扱う際に使用されます。
    ///
    /// - Parameter expression: コンポーネント配列
    /// - Returns: そのままのコンポーネント配列
    public static func buildExpression(_ expression: [PromptComponent]) -> [PromptComponent] {
        expression
    }

    /// 最終結果を構築
    ///
    /// - Parameter component: 最終的なコンポーネント配列
    /// - Returns: そのままのコンポーネント配列
    public static func buildFinalResult(_ component: [PromptComponent]) -> [PromptComponent] {
        component
    }

    /// 制限付きの利用可能性を処理
    ///
    /// `#available` チェックで使用されます。
    ///
    /// - Parameter component: コンポーネント配列
    /// - Returns: そのままのコンポーネント配列
    public static func buildLimitedAvailability(_ component: [PromptComponent]) -> [PromptComponent] {
        component
    }
}
