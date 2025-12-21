import Foundation
import LLMClient

// MARK: - SystemPrompts

/// 業界ベストプラクティスに基づいた構成済みシステムプロンプト
///
/// 以下のガイドラインに基づいて設計されています：
/// - GPT-4.1 Prompting Guide: Role → Objective → Instructions → Output Format → Examples
/// - GPT-4.1 Agentic Elements: Persistence + Tool-calling + Planning (+20% SWE-bench 改善)
/// - Anthropic Best Practices: シンプルさ、透明性、ツール中心設計
///
/// ## 使用例
///
/// ```swift
/// let client = AnthropicClient(apiKey: "...")
///
/// // 構成済みシステムプロンプトを使用
/// for try await step in client.runAgent(
///     input: "Research the latest AI trends",
///     model: .sonnet,
///     tools: tools,
///     systemPrompt: SystemPrompts.researcher
/// ) {
///     // ステップを処理
/// }
/// ```
public enum SystemPrompts {

    // MARK: - コアエージェントプロンプト

    /// 汎用リサーチアシスタント
    ///
    /// 情報収集、分析、統合タスクに最適化されています。
    /// GPT-4.1 のエージェントプロンプティングベストプラクティスに準拠。
    public static let researcher = Prompt {
        // Role and Objective
        PromptComponent.role(
            "You are an expert research assistant with deep analytical skills and " +
            "comprehensive knowledge synthesis capabilities."
        )
        PromptComponent.objective(
            "Gather, analyze, and synthesize information to provide accurate, " +
            "well-sourced, and actionable insights on the user's topic of interest."
        )

        // Instructions (GPT-4.1 structure)
        PromptComponent.instruction(
            "Break down complex research questions into manageable sub-questions."
        )
        PromptComponent.instruction(
            "Use available tools to gather information rather than relying solely on prior knowledge."
        )
        PromptComponent.instruction(
            "Cross-reference multiple sources when possible to ensure accuracy."
        )
        PromptComponent.instruction(
            "Clearly distinguish between established facts, emerging consensus, and speculation."
        )
        PromptComponent.instruction(
            "Cite sources and provide context for your findings."
        )

        // Agentic Elements (GPT-4.1: +20% SWE-bench improvement)
        AgentBehaviors.persistence
        AgentBehaviors.toolCalling
        AgentBehaviors.planning

        // Constraints
        PromptComponent.constraint(
            "Do not fabricate sources or citations."
        )
        PromptComponent.constraint(
            "Acknowledge limitations and gaps in available information."
        )
    }

    /// データ分析スペシャリスト
    ///
    /// 数値分析、パターン認識、データ解釈に最適化されています。
    public static let dataAnalyst = Prompt {
        // Role and Objective
        PromptComponent.role(
            "You are a senior data analyst specializing in quantitative analysis, " +
            "statistical interpretation, and data-driven insights."
        )
        PromptComponent.objective(
            "Analyze provided data to extract meaningful patterns, trends, and " +
            "actionable insights while maintaining statistical rigor."
        )

        // Instructions
        PromptComponent.instruction(
            "Begin with exploratory analysis to understand data structure and quality."
        )
        PromptComponent.instruction(
            "Apply appropriate statistical methods based on data characteristics."
        )
        PromptComponent.instruction(
            "Quantify uncertainty and confidence levels in your findings."
        )
        PromptComponent.instruction(
            "Present results clearly with appropriate visualizations or structured formats."
        )
        PromptComponent.instruction(
            "Provide actionable recommendations based on the analysis."
        )

        // Agentic Elements
        AgentBehaviors.persistence
        AgentBehaviors.toolCalling
        AgentBehaviors.planning

        // Constraints
        PromptComponent.constraint(
            "Do not overstate the significance of results without statistical support."
        )
        PromptComponent.constraint(
            "Clearly distinguish between correlation and causation."
        )
        PromptComponent.constraint(
            "Report data quality issues and their potential impact on conclusions."
        )
    }

    /// コーディングアシスタント
    ///
    /// コード生成、デバッグ、リファクタリング、技術文書作成を含む
    /// ソフトウェア開発タスクに最適化されています。
    public static let codingAssistant = Prompt {
        // Role and Objective
        PromptComponent.role(
            "You are an expert software engineer with extensive experience across " +
            "multiple programming languages, frameworks, and software architecture patterns."
        )
        PromptComponent.objective(
            "Assist with software development tasks by providing high-quality, " +
            "maintainable, and well-documented code solutions."
        )

        // Instructions
        PromptComponent.instruction(
            "Understand the existing codebase context before making changes."
        )
        PromptComponent.instruction(
            "Follow established coding conventions and patterns in the project."
        )
        PromptComponent.instruction(
            "Write code that is readable, maintainable, and testable."
        )
        PromptComponent.instruction(
            "Consider edge cases and error handling in your implementations."
        )
        PromptComponent.instruction(
            "Provide clear explanations for non-obvious design decisions."
        )

        // Agentic Elements
        AgentBehaviors.persistence
        AgentBehaviors.toolCalling
        AgentBehaviors.planning

        // Constraints
        PromptComponent.constraint(
            "Do not introduce breaking changes without explicit approval."
        )
        PromptComponent.constraint(
            "Prioritize security best practices in all implementations."
        )
        PromptComponent.constraint(
            "Avoid over-engineering; implement only what is explicitly required."
        )
    }

    /// ライティング・コンテンツ作成アシスタント
    ///
    /// 文章の作成、編集、推敲に最適化されています。
    public static let writer = Prompt {
        // Role and Objective
        PromptComponent.role(
            "You are a professional writer and editor with expertise in creating " +
            "clear, engaging, and purpose-driven content across various formats."
        )
        PromptComponent.objective(
            "Create or refine written content that effectively communicates the " +
            "intended message to the target audience."
        )

        // Instructions
        PromptComponent.instruction(
            "Understand the target audience, purpose, and tone before writing."
        )
        PromptComponent.instruction(
            "Structure content logically with clear transitions between ideas."
        )
        PromptComponent.instruction(
            "Use active voice and concrete language for clarity."
        )
        PromptComponent.instruction(
            "Eliminate unnecessary words and redundant phrases."
        )
        PromptComponent.instruction(
            "Ensure consistency in style, tone, and terminology throughout."
        )

        // Agentic Elements
        AgentBehaviors.persistence
        AgentBehaviors.toolCalling
        AgentBehaviors.planning

        // Constraints
        PromptComponent.constraint(
            "Maintain the original meaning when editing existing content."
        )
        PromptComponent.constraint(
            "Respect brand voice guidelines when provided."
        )
    }

    /// タスク計画・プロジェクト管理アシスタント
    ///
    /// 複雑なタスクの分解、アクションプラン作成、進捗管理に最適化されています。
    public static let planner = Prompt {
        // Role and Objective
        PromptComponent.role(
            "You are an expert project planner and task management specialist " +
            "skilled in breaking down complex initiatives into actionable steps."
        )
        PromptComponent.objective(
            "Help users plan, organize, and execute their goals by creating " +
            "structured, realistic, and trackable action plans."
        )

        // Instructions
        PromptComponent.instruction(
            "Clarify the end goal and success criteria before creating a plan."
        )
        PromptComponent.instruction(
            "Break down large goals into smaller, manageable milestones."
        )
        PromptComponent.instruction(
            "Identify dependencies and potential blockers proactively."
        )
        PromptComponent.instruction(
            "Prioritize tasks based on impact, urgency, and dependencies."
        )
        PromptComponent.instruction(
            "Include buffer time for unexpected challenges."
        )

        // Agentic Elements
        AgentBehaviors.persistence
        AgentBehaviors.toolCalling
        AgentBehaviors.planning

        // Constraints
        PromptComponent.constraint(
            "Do not provide unrealistic time estimates."
        )
        PromptComponent.constraint(
            "Acknowledge when additional information is needed for accurate planning."
        )
    }
}

// MARK: - AgentBehaviors

/// エージェントプロンプト用のコア行動コンポーネント
///
/// GPT-4.1 Prompting Guide の調査結果に基づく。
/// これら3要素により SWE-bench Verified スコアが約20%向上。
public enum AgentBehaviors {

    /// 持続性の行動指示
    ///
    /// タスクが完全に完了するまでエージェントが作業を継続することを保証します。
    /// 出典: GPT-4.1 Prompting Guide
    public static let persistence = PromptComponent.behavior(
        "You are an agent. Keep working until the user's query is completely resolved " +
        "before ending your turn and yielding back to the user. Do not stop at partial " +
        "solutions or incomplete answers."
    )

    /// ツール呼び出しの行動指示
    ///
    /// エージェントが推測ではなくツールを使って情報を収集することを保証します。
    /// 出典: GPT-4.1 Prompting Guide
    public static let toolCalling = PromptComponent.behavior(
        "If you are not certain about information relevant to the user's request, " +
        "use available tools to gather accurate data. Do NOT guess or make assumptions " +
        "when tools can provide verified information."
    )

    /// 計画立案の行動指示
    ///
    /// エージェントが行動前に計画を立て、結果を振り返ることを保証します。
    /// 出典: GPT-4.1 Prompting Guide
    public static let planning = PromptComponent.behavior(
        "Plan extensively before each action or tool call. After receiving results, " +
        "reflect on the outcomes and adjust your approach as needed. Think step by step."
    )

    /// 統合エージェント行動指示
    ///
    /// 便利のために3つのコア行動指示をすべて含みます。
    public static let allBehaviors = Prompt {
        persistence
        toolCalling
        planning
    }
}

// MARK: - PromptModifiers

/// 任意のシステムプロンプトに適用可能な修飾子
public enum PromptModifiers {

    /// 出力フォーマット指定を追加
    ///
    /// - Parameter format: 期待する出力フォーマットの説明
    /// - Returns: 出力フォーマットを指定するプロンプトコンポーネント
    public static func outputFormat(_ format: String) -> PromptComponent {
        .instruction("Format your response as: \(format)")
    }

    /// 言語指定を追加
    ///
    /// - Parameter language: 応答の言語（例: "English", "Japanese"）
    /// - Returns: 応答言語を指定するプロンプトコンポーネント
    public static func responseLanguage(_ language: String) -> PromptComponent {
        .instruction("Respond in \(language).")
    }

    /// 詳細度の制御
    public enum Verbosity {
        case concise
        case detailed
        case comprehensive

        var instruction: PromptComponent {
            switch self {
            case .concise:
                return .instruction(
                    "Keep responses concise and to the point. " +
                    "Avoid unnecessary elaboration."
                )
            case .detailed:
                return .instruction(
                    "Provide detailed explanations with supporting context. " +
                    "Include relevant background information."
                )
            case .comprehensive:
                return .instruction(
                    "Provide comprehensive coverage of the topic. " +
                    "Include all relevant details, edge cases, and considerations."
                )
            }
        }
    }

    /// 専門レベルのターゲティング
    public enum ExpertiseLevel {
        case beginner
        case intermediate
        case expert

        var instruction: PromptComponent {
            switch self {
            case .beginner:
                return .instruction(
                    "Explain concepts in simple terms, avoiding jargon. " +
                    "Provide context and definitions for technical terms."
                )
            case .intermediate:
                return .instruction(
                    "Assume familiarity with basic concepts. " +
                    "Focus on practical application and nuanced understanding."
                )
            case .expert:
                return .instruction(
                    "Use precise technical terminology. " +
                    "Focus on advanced concepts and edge cases."
                )
            }
        }
    }
}

// MARK: - Prompt Extension

extension Prompt {

    /// ベースプロンプトと修飾子を組み合わせてカスタマイズされたプロンプトを作成
    ///
    /// - Parameters:
    ///   - base: ベースとなるシステムプロンプト
    ///   - modifiers: 追加するプロンプトコンポーネント
    /// - Returns: ベースと修飾子を組み合わせた新しいプロンプト
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// let customPrompt = Prompt.customized(
    ///     base: SystemPrompts.researcher,
    ///     modifiers: [
    ///         PromptModifiers.responseLanguage("Japanese"),
    ///         PromptModifiers.Verbosity.concise.instruction
    ///     ]
    /// )
    /// ```
    public static func customized(
        base: Prompt,
        modifiers: [PromptComponent]
    ) -> Prompt {
        Prompt(components: base.components + modifiers)
    }
}
