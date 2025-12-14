import Foundation

// MARK: - Prompt

/// 構造化されたプロンプト
///
/// DSL を使用して構築された、複数のプロンプトコンポーネントから成る
/// 構造化されたプロンプトです。記述順序がそのまま最終的なプロンプトの
/// 順序となります。
///
/// ## 使用例
///
/// ```swift
/// let prompt = Prompt {
///     PromptComponent.role("データ分析の専門家")
///     PromptComponent.objective("テキストからユーザー情報を抽出する")
///     PromptComponent.context("日本語の SNS 投稿が入力される")
///
///     PromptComponent.instruction("名前は敬称を除いて抽出する")
///     PromptComponent.instruction("年齢は数値のみ抽出する")
///
///     PromptComponent.constraint("推測はしない")
///     PromptComponent.important("不明な場合は null を返す")
///
///     PromptComponent.example(
///         input: "佐藤花子さん（28）は東京在住",
///         output: #"{"name": "佐藤花子", "age": 28}"#
///     )
/// }
///
/// let result: UserInfo = try await client.generate(
///     prompt: prompt,
///     model: .sonnet
/// )
/// ```
///
/// ## レンダリング
///
/// `render()` メソッドを呼び出すと、各コンポーネントが XML タグ形式で
/// レンダリングされ、記述順に結合されます。
///
/// ```xml
/// <role>
/// データ分析の専門家
/// </role>
///
/// <objective>
/// テキストからユーザー情報を抽出する
/// </objective>
///
/// <context>
/// 日本語の SNS 投稿が入力される
/// </context>
///
/// ...
/// ```
public struct Prompt: Sendable, Equatable {

    // MARK: - Properties

    /// プロンプトを構成するコンポーネントの配列（記述順）
    public let components: [PromptComponent]

    // MARK: - Initializers

    /// DSL を使用してプロンプトを構築
    ///
    /// Result Builder を使用して、宣言的にプロンプトを構築します。
    /// コンポーネントの記述順序がそのままプロンプトの順序になります。
    ///
    /// - Parameter builder: プロンプトコンポーネントを構築するクロージャ
    ///
    /// ## 使用例
    /// ```swift
    /// let prompt = Prompt {
    ///     PromptComponent.role("データ分析の専門家")
    ///     PromptComponent.objective("情報抽出")
    ///     PromptComponent.instruction("名前を抽出する")
    /// }
    /// ```
    public init(@PromptBuilder _ builder: () -> [PromptComponent]) {
        self.components = builder()
    }

    /// コンポーネント配列から直接初期化
    ///
    /// プログラマティックにプロンプトを構築する場合に使用します。
    ///
    /// - Parameter components: プロンプトコンポーネントの配列
    ///
    /// ## 使用例
    /// ```swift
    /// let components: [PromptComponent] = [
    ///     .objective("情報抽出"),
    ///     .instruction("名前を抽出する")
    /// ]
    /// let prompt = Prompt(components: components)
    /// ```
    public init(components: [PromptComponent]) {
        self.components = components
    }

    // MARK: - Rendering

    /// プロンプトを文字列としてレンダリング
    ///
    /// 各コンポーネントを XML タグ形式でレンダリングし、
    /// 空行で区切って結合します。コンポーネントの記述順序が保持されます。
    ///
    /// - Returns: レンダリングされたプロンプト文字列
    public func render() -> String {
        components
            .map { $0.render() }
            .joined(separator: "\n\n")
    }

    // MARK: - Computed Properties

    /// プロンプトが空かどうか
    public var isEmpty: Bool {
        components.isEmpty
    }

    /// コンポーネントの数
    public var count: Int {
        components.count
    }
}

// MARK: - CustomStringConvertible

extension Prompt: CustomStringConvertible {
    public var description: String {
        render()
    }
}

// MARK: - ExpressibleByStringLiteral

extension Prompt: ExpressibleByStringLiteral {
    /// 文字列リテラルからプロンプトを作成
    ///
    /// 単純な文字列をプロンプトとして使用する場合の後方互換性のために提供されます。
    /// 文字列は `context` コンポーネントとして扱われます。
    ///
    /// - Parameter value: プロンプト文字列
    ///
    /// ## 使用例
    /// ```swift
    /// let prompt: Prompt = "山田太郎さんは35歳です"
    /// ```
    public init(stringLiteral value: String) {
        self.components = [.context(value)]
    }
}

// MARK: - Prompt Combination

extension Prompt {
    /// 2つのプロンプトを結合
    ///
    /// - Parameters:
    ///   - lhs: 最初のプロンプト
    ///   - rhs: 追加するプロンプト
    /// - Returns: 結合されたプロンプト
    public static func + (lhs: Prompt, rhs: Prompt) -> Prompt {
        Prompt(components: lhs.components + rhs.components)
    }

    /// プロンプトにコンポーネントを追加
    ///
    /// - Parameters:
    ///   - lhs: プロンプト
    ///   - rhs: 追加するコンポーネント
    /// - Returns: コンポーネントが追加されたプロンプト
    public static func + (lhs: Prompt, rhs: PromptComponent) -> Prompt {
        Prompt(components: lhs.components + [rhs])
    }

    /// 別のプロンプトを追加した新しいプロンプトを返す
    ///
    /// - Parameter other: 追加するプロンプト
    /// - Returns: 結合されたプロンプト
    public func appending(_ other: Prompt) -> Prompt {
        self + other
    }

    /// コンポーネントを追加した新しいプロンプトを返す
    ///
    /// - Parameter component: 追加するコンポーネント
    /// - Returns: コンポーネントが追加されたプロンプト
    public func appending(_ component: PromptComponent) -> Prompt {
        self + component
    }
}

// MARK: - Filtering and Transformation

extension Prompt {
    /// 特定のタイプのコンポーネントのみを抽出
    ///
    /// - Parameter predicate: フィルタ条件
    /// - Returns: フィルタされたプロンプト
    public func filter(_ predicate: (PromptComponent) -> Bool) -> Prompt {
        Prompt(components: components.filter(predicate))
    }

    /// 特定のタグ名を持つコンポーネントのみを抽出
    ///
    /// - Parameter tagName: 抽出するタグ名
    /// - Returns: フィルタされたプロンプト
    ///
    /// ## 使用例
    /// ```swift
    /// let instructions = prompt.components(withTag: "instruction")
    /// ```
    public func components(withTag tagName: String) -> Prompt {
        filter { $0.tagName == tagName }
    }
}
