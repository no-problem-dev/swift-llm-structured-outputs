import Foundation

// MARK: - PromptComponent

/// プロンプトを構成する要素
///
/// DSL を使用して、様々なプロンプトエンジニアリング技法を
/// 自由に組み合わせてプロンプトを構築できます。
///
/// ## 使用例
///
/// ```swift
/// let prompt = Prompt {
///     PromptComponent.role("データ分析の専門家")
///     PromptComponent.objective("テキストから情報を抽出する")
///     PromptComponent.instruction("名前は敬称を除いて抽出")
///     PromptComponent.constraint("推測はしない")
/// }
/// ```
///
/// ## カテゴリ
///
/// - **ペルソナ系**: `role`, `expertise`, `behavior`
/// - **タスク定義系**: `objective`, `context`, `instruction`, `constraint`
/// - **思考誘導系 (Chain-of-Thought)**: `thinkingStep`, `reasoning`
/// - **例示系 (Few-shot)**: `example`
/// - **メタ指示系**: `important`, `note`
public enum PromptComponent: Sendable, Equatable {

    // MARK: - ペルソナ系

    /// 役割を定義
    ///
    /// LLM に特定の役割を与えることで、その視点からの回答を促します。
    ///
    /// - Parameter value: 役割の説明
    ///
    /// ## 使用例
    /// ```swift
    /// PromptComponent.role("経験豊富な Swift エンジニア")
    /// ```
    case role(String)

    /// 専門性を定義
    ///
    /// 役割に付随する専門知識やスキルを指定します。
    ///
    /// - Parameter value: 専門性の説明
    ///
    /// ## 使用例
    /// ```swift
    /// PromptComponent.expertise("iOS アプリ開発")
    /// PromptComponent.expertise("パフォーマンス最適化")
    /// ```
    case expertise(String)

    /// 振る舞いを定義
    ///
    /// 回答のスタイルや態度を指定します。
    ///
    /// - Parameter value: 振る舞いの説明
    ///
    /// ## 使用例
    /// ```swift
    /// PromptComponent.behavior("簡潔かつ実用的なアドバイスを提供する")
    /// ```
    case behavior(String)

    // MARK: - タスク定義系

    /// タスクの目的を定義
    ///
    /// プロンプトの主要な目的やゴールを明示します。
    ///
    /// - Parameter value: 目的の説明
    ///
    /// ## 使用例
    /// ```swift
    /// PromptComponent.objective("ユーザー情報をJSON形式で抽出する")
    /// ```
    case objective(String)

    /// コンテキストを提供
    ///
    /// タスクに関連する背景情報や状況を説明します。
    ///
    /// - Parameter value: コンテキストの説明
    ///
    /// ## 使用例
    /// ```swift
    /// PromptComponent.context("入力は日本語のSNS投稿文です")
    /// ```
    case context(String)

    /// 具体的な指示を追加
    ///
    /// タスクを遂行するための具体的な手順や方法を指定します。
    ///
    /// - Parameter value: 指示の内容
    ///
    /// ## 使用例
    /// ```swift
    /// PromptComponent.instruction("名前は敬称（さん、様など）を除いて抽出する")
    /// PromptComponent.instruction("年齢は数値のみ抽出する")
    /// ```
    case instruction(String)

    /// 制約条件を追加
    ///
    /// 回答に対する制限や禁止事項を指定します。
    ///
    /// - Parameter value: 制約の内容
    ///
    /// ## 使用例
    /// ```swift
    /// PromptComponent.constraint("推測はしない")
    /// PromptComponent.constraint("明示的に記載された情報のみ使用する")
    /// ```
    case constraint(String)

    // MARK: - 思考誘導系 (Chain-of-Thought)

    /// 思考ステップを定義
    ///
    /// Chain-of-Thought プロンプティングで、
    /// LLM に特定の思考プロセスを促します。
    ///
    /// - Parameter value: 思考ステップの説明
    ///
    /// ## 使用例
    /// ```swift
    /// PromptComponent.thinkingStep("まずテキスト内の人名を特定する")
    /// PromptComponent.thinkingStep("次に年齢に関する記述を探す")
    /// ```
    case thinkingStep(String)

    /// 推論の根拠を説明
    ///
    /// なぜそのような処理をするのかの理由を説明します。
    /// LLM の汎化能力を向上させます。
    ///
    /// - Parameter value: 推論の説明
    ///
    /// ## 使用例
    /// ```swift
    /// PromptComponent.reasoning("敬称を除くのは、データベースの正規化のためです")
    /// ```
    case reasoning(String)

    // MARK: - 例示系 (Few-shot)

    /// 入出力の例を提供
    ///
    /// Few-shot プロンプティングで、
    /// 期待する入出力パターンを例示します。
    ///
    /// - Parameters:
    ///   - input: 入力例
    ///   - output: 期待する出力例
    ///
    /// ## 使用例
    /// ```swift
    /// PromptComponent.example(
    ///     input: "佐藤花子さん（28）は東京在住",
    ///     output: #"{"name": "佐藤花子", "age": 28}"#
    /// )
    /// ```
    case example(input: String, output: String)

    // MARK: - メタ指示系

    /// 重要事項を強調
    ///
    /// 特に重要な指示や注意点を強調します。
    ///
    /// - Parameter value: 重要事項の内容
    ///
    /// ## 使用例
    /// ```swift
    /// PromptComponent.important("不明な情報は必ず null を返してください")
    /// ```
    case important(String)

    /// 補足情報を追加
    ///
    /// 補足的な情報やヒントを提供します。
    ///
    /// - Parameter value: 補足の内容
    ///
    /// ## 使用例
    /// ```swift
    /// PromptComponent.note("西暦と和暦が混在している場合があります")
    /// ```
    case note(String)
}

// MARK: - Rendering

extension PromptComponent {

    /// XML タグ名を取得
    var tagName: String {
        switch self {
        case .role: return "role"
        case .expertise: return "expertise"
        case .behavior: return "behavior"
        case .objective: return "objective"
        case .context: return "context"
        case .instruction: return "instruction"
        case .constraint: return "constraint"
        case .thinkingStep: return "thinking_step"
        case .reasoning: return "reasoning"
        case .example: return "example"
        case .important: return "important"
        case .note: return "note"
        }
    }

    /// プロンプトコンポーネントを XML 形式でレンダリング
    ///
    /// - Returns: XML タグで囲まれた文字列
    public func render() -> String {
        switch self {
        case .role(let value),
             .expertise(let value),
             .behavior(let value),
             .objective(let value),
             .context(let value),
             .instruction(let value),
             .constraint(let value),
             .thinkingStep(let value),
             .reasoning(let value),
             .important(let value),
             .note(let value):
            return "<\(tagName)>\n\(value)\n</\(tagName)>"

        case .example(let input, let output):
            return """
                <\(tagName)>
                Input: \(input)
                Output: \(output)
                </\(tagName)>
                """
        }
    }
}

// MARK: - CustomStringConvertible

extension PromptComponent: CustomStringConvertible {
    public var description: String {
        render()
    }
}


