import Foundation
import LLMClient
import LLMTool
import LLMAgent

// MARK: - AgentPreset

/// エージェント設定のプリセットを表すプロトコル
///
/// システムプロンプト、ツールセット、設定を組み合わせた
/// 再利用可能なエージェント構成を定義します。
///
/// ## 適用されたベストプラクティス
/// - **GPT-4.1 エージェント要素**: 永続性、ツール呼び出し、計画立案を含む
/// - **モジュラー設計**: 各要素を独立してカスタマイズ可能
/// - **型安全**: Swiftの型システムを活用した安全な構成
public protocol AgentPreset: Sendable {
    /// プリセットのシステムプロンプト
    static var systemPrompt: Prompt { get }

    /// プリセットのデフォルトツールセット
    static var defaultTools: ToolSet { get }

    /// プリセットのエージェント設定
    static var configuration: AgentConfiguration { get }
}

// MARK: - Default Implementation

extension AgentPreset {
    /// デフォルトのエージェント設定
    public static var configuration: AgentConfiguration {
        .default
    }

    /// カスタムツールを追加したツールセットを取得
    ///
    /// - Parameter additionalTools: 追加するツール
    /// - Returns: デフォルトツールと追加ツールを含むツールセット
    public static func toolsWithAdditions(_ additionalTools: ToolSet) -> ToolSet {
        defaultTools.appending(additionalTools)
    }
}

// MARK: - ResearcherPreset

/// リサーチャーエージェントのプリセット
///
/// 情報収集、分析、統合タスク向けに最適化されています。
/// CalculatorとDateTimeツールを含み、データの計算や日時処理が可能です。
///
/// ## 使用例
///
/// ```swift
/// let stream: some AgentStepStream<AnalysisResult> = client.runAgent(
///     input: "Analyze the market trends for AI products in 2024",
///     model: .sonnet,
///     tools: ResearcherPreset.defaultTools,
///     systemPrompt: ResearcherPreset.systemPrompt,
///     configuration: ResearcherPreset.configuration
/// )
/// ```
public enum ResearcherPreset: AgentPreset {
    /// リサーチャー向けシステムプロンプト
    public static let systemPrompt = SystemPrompts.researcher

    /// リサーチャー向けデフォルトツールセット
    public static var defaultTools: ToolSet {
        ToolSet {
            CalculatorTool()
            DateTimeTool()
            TextAnalysisTool()
        }
    }

    /// リサーチタスク向け設定（多めのステップ数を許容）
    public static let configuration = AgentConfiguration(
        maxSteps: 15,
        autoExecuteTools: true,
        maxDuplicateToolCalls: 2,
        maxToolCallsPerTool: 8
    )
}

// MARK: - DataAnalystPreset

/// データアナリストエージェントのプリセット
///
/// 数値分析、統計処理、データ解釈タスク向けに最適化されています。
/// Calculator、DateTime、TextAnalysisツールを含みます。
///
/// ## 使用例
///
/// ```swift
/// let stream: some AgentStepStream<AnalysisResult> = client.runAgent(
///     input: "Calculate the growth rate from these figures: Q1: 100, Q2: 120, Q3: 150",
///     model: .sonnet,
///     tools: DataAnalystPreset.defaultTools,
///     systemPrompt: DataAnalystPreset.systemPrompt
/// )
/// ```
public enum DataAnalystPreset: AgentPreset {
    /// データアナリスト向けシステムプロンプト
    public static let systemPrompt = SystemPrompts.dataAnalyst

    /// データアナリスト向けデフォルトツールセット
    public static var defaultTools: ToolSet {
        ToolSet {
            CalculatorTool()
            DateTimeTool()
            TextAnalysisTool()
        }
    }

    /// データ分析タスク向け設定
    public static let configuration = AgentConfiguration(
        maxSteps: 12,
        autoExecuteTools: true,
        maxDuplicateToolCalls: 3,
        maxToolCallsPerTool: 10
    )
}

// MARK: - CodingAssistantPreset

/// コーディングアシスタントエージェントのプリセット
///
/// コード生成、デバッグ、リファクタリングタスク向けに最適化されています。
/// TextAnalysisツールによるコード分析をサポートします。
///
/// ## 使用例
///
/// ```swift
/// let stream: some AgentStepStream<CodeReview> = client.runAgent(
///     input: "Review this Swift code and identify potential issues",
///     model: .sonnet,
///     tools: CodingAssistantPreset.defaultTools,
///     systemPrompt: CodingAssistantPreset.systemPrompt
/// )
/// ```
public enum CodingAssistantPreset: AgentPreset {
    /// コーディングアシスタント向けシステムプロンプト
    public static let systemPrompt = SystemPrompts.codingAssistant

    /// コーディングアシスタント向けデフォルトツールセット
    public static var defaultTools: ToolSet {
        ToolSet {
            TextAnalysisTool()
            CalculatorTool()
        }
    }

    /// コーディングタスク向け設定
    public static let configuration = AgentConfiguration(
        maxSteps: 10,
        autoExecuteTools: true,
        maxDuplicateToolCalls: 2,
        maxToolCallsPerTool: 5
    )
}

// MARK: - WriterPreset

/// ライターエージェントのプリセット
///
/// コンテンツ作成、編集、推敲タスク向けに最適化されています。
/// TextAnalysisツールによる文章分析をサポートします。
///
/// ## 使用例
///
/// ```swift
/// let stream: some AgentStepStream<Summary> = client.runAgent(
///     input: "Summarize this article and highlight the key points",
///     model: .sonnet,
///     tools: WriterPreset.defaultTools,
///     systemPrompt: WriterPreset.systemPrompt
/// )
/// ```
public enum WriterPreset: AgentPreset {
    /// ライター向けシステムプロンプト
    public static let systemPrompt = SystemPrompts.writer

    /// ライター向けデフォルトツールセット
    public static var defaultTools: ToolSet {
        ToolSet {
            TextAnalysisTool()
        }
    }

    /// ライティングタスク向け設定
    public static let configuration = AgentConfiguration(
        maxSteps: 8,
        autoExecuteTools: true,
        maxDuplicateToolCalls: 2,
        maxToolCallsPerTool: 4
    )
}

// MARK: - PlannerPreset

/// プランナーエージェントのプリセット
///
/// タスク計画、プロジェクト管理、作業分解タスク向けに最適化されています。
/// DateTimeツールによるスケジュール計算をサポートします。
///
/// ## 使用例
///
/// ```swift
/// let stream: some AgentStepStream<TaskPlan> = client.runAgent(
///     input: "Create a plan to launch a new mobile app",
///     model: .sonnet,
///     tools: PlannerPreset.defaultTools,
///     systemPrompt: PlannerPreset.systemPrompt
/// )
/// ```
public enum PlannerPreset: AgentPreset {
    /// プランナー向けシステムプロンプト
    public static let systemPrompt = SystemPrompts.planner

    /// プランナー向けデフォルトツールセット
    public static var defaultTools: ToolSet {
        ToolSet {
            DateTimeTool()
            CalculatorTool()
        }
    }

    /// 計画タスク向け設定（複雑な計画に対応）
    public static let configuration = AgentConfiguration(
        maxSteps: 12,
        autoExecuteTools: true,
        maxDuplicateToolCalls: 2,
        maxToolCallsPerTool: 6
    )
}

// MARK: - MinimalPreset

/// 最小構成のエージェントプリセット
///
/// ツールを使用せず、純粋な会話・生成タスク向けに最適化されています。
/// AgentBehaviorsのみを含む軽量なプリセットです。
///
/// ## 使用例
///
/// ```swift
/// let stream: some AgentStepStream<Summary> = client.runAgent(
///     input: "Explain the concept of machine learning",
///     model: .sonnet,
///     tools: MinimalPreset.defaultTools,
///     systemPrompt: MinimalPreset.systemPrompt
/// )
/// ```
public enum MinimalPreset: AgentPreset {
    /// 最小構成のシステムプロンプト（エージェント行動指示のみ）
    public static let systemPrompt = AgentBehaviors.allBehaviors

    /// 空のツールセット
    public static var defaultTools: ToolSet {
        ToolSet { }
    }

    /// 最小構成向け設定（少ないステップ数）
    public static let configuration = AgentConfiguration(
        maxSteps: 5,
        autoExecuteTools: true,
        maxDuplicateToolCalls: 1,
        maxToolCallsPerTool: nil
    )
}

// MARK: - CustomPresetBuilder

/// カスタムプリセットを構築するためのビルダー
///
/// 既存のプリセットをベースに、カスタマイズしたプリセットを作成できます。
///
/// ## 使用例
///
/// ```swift
/// let customPreset = CustomPresetBuilder()
///     .withSystemPrompt(SystemPrompts.researcher)
///     .addingVerbosity(.detailed)
///     .addingLanguage("Japanese")
///     .withTools {
///         CalculatorTool()
///         DateTimeTool()
///         MyCustomTool()
///     }
///     .withConfiguration(maxSteps: 20)
///     .build()
/// ```
public struct CustomPresetBuilder: Sendable {
    private var systemPrompt: Prompt
    private var tools: ToolSet
    private var configuration: AgentConfiguration

    /// 新しいビルダーを初期化
    public init() {
        self.systemPrompt = AgentBehaviors.allBehaviors
        self.tools = ToolSet { }
        self.configuration = .default
    }

    /// 既存のプリセットをベースに初期化
    public init<P: AgentPreset>(basedOn preset: P.Type) {
        self.systemPrompt = P.systemPrompt
        self.tools = P.defaultTools
        self.configuration = P.configuration
    }

    /// システムプロンプトを設定
    public func withSystemPrompt(_ prompt: Prompt) -> CustomPresetBuilder {
        var builder = self
        builder.systemPrompt = prompt
        return builder
    }

    /// 詳細度修飾子を追加
    public func addingVerbosity(_ verbosity: PromptModifiers.Verbosity) -> CustomPresetBuilder {
        var builder = self
        builder.systemPrompt = Prompt.customized(
            base: systemPrompt,
            modifiers: [verbosity.instruction]
        )
        return builder
    }

    /// 応答言語を指定
    public func addingLanguage(_ language: String) -> CustomPresetBuilder {
        var builder = self
        builder.systemPrompt = Prompt.customized(
            base: systemPrompt,
            modifiers: [PromptModifiers.responseLanguage(language)]
        )
        return builder
    }

    /// 専門レベルを指定
    public func addingExpertiseLevel(_ level: PromptModifiers.ExpertiseLevel) -> CustomPresetBuilder {
        var builder = self
        builder.systemPrompt = Prompt.customized(
            base: systemPrompt,
            modifiers: [level.instruction]
        )
        return builder
    }

    /// ツールセットを設定
    public func withTools(@ToolSetBuilder _ builder: () -> ToolSet) -> CustomPresetBuilder {
        var preset = self
        preset.tools = builder()
        return preset
    }

    /// エージェント設定を設定
    public func withConfiguration(
        maxSteps: Int? = nil,
        autoExecuteTools: Bool? = nil,
        maxDuplicateToolCalls: Int? = nil,
        maxToolCallsPerTool: Int? = nil
    ) -> CustomPresetBuilder {
        var builder = self
        builder.configuration = AgentConfiguration(
            maxSteps: maxSteps ?? configuration.maxSteps,
            autoExecuteTools: autoExecuteTools ?? configuration.autoExecuteTools,
            maxDuplicateToolCalls: maxDuplicateToolCalls ?? configuration.maxDuplicateToolCalls,
            maxToolCallsPerTool: maxToolCallsPerTool ?? configuration.maxToolCallsPerTool
        )
        return builder
    }

    /// カスタムプリセットをビルド
    public func build() -> BuiltCustomPreset {
        BuiltCustomPreset(
            systemPrompt: systemPrompt,
            tools: tools,
            configuration: configuration
        )
    }
}

// MARK: - BuiltCustomPreset

/// CustomPresetBuilderによって構築されたプリセット
public struct BuiltCustomPreset: Sendable {
    /// システムプロンプト
    public let systemPrompt: Prompt

    /// ツールセット
    public let tools: ToolSet

    /// エージェント設定
    public let configuration: AgentConfiguration
}
