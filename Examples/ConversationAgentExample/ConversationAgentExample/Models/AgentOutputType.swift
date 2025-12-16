import SwiftUI
import LLMStructuredOutputs

// MARK: - Agent Output Type

/// エージェント出力タイプ
///
/// 各タイプは以下を提供します：
/// - システムプロンプト
/// - UI表示用のプロパティ
enum AgentOutputType: String, CaseIterable, Identifiable, Codable {
    case research
    case summary
    case comparison

    var id: String { rawValue }

    // MARK: - UI Properties

    var displayName: String {
        switch self {
        case .research: "リサーチ"
        case .summary: "要約"
        case .comparison: "比較"
        }
    }

    var icon: String {
        switch self {
        case .research: "magnifyingglass.circle.fill"
        case .summary: "doc.text.fill"
        case .comparison: "arrow.left.arrow.right.circle.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .research: .blue
        case .summary: .green
        case .comparison: .orange
        }
    }

    var subtitle: String {
        switch self {
        case .research: "詳細な調査レポート"
        case .summary: "簡潔なサマリー"
        case .comparison: "比較分析レポート"
        }
    }

    // MARK: - Prompt Building

    func buildPrompt(interactiveMode: Bool) -> Prompt {
        switch self {
        case .research: Self.buildResearchPrompt(interactiveMode: interactiveMode)
        case .summary: Self.buildSummaryPrompt(interactiveMode: interactiveMode)
        case .comparison: Self.buildComparisonPrompt(interactiveMode: interactiveMode)
        }
    }
}

// MARK: - Prompt Implementations

private extension AgentOutputType {

    /// リサーチプロンプト
    ///
    /// 詳細な調査レポートを生成します。
    /// - 多角的な情報収集
    /// - ソース検証と引用
    /// - 包括的なカバレッジ
    static func buildResearchPrompt(interactiveMode: Bool) -> Prompt {
        Prompt {
            PromptComponent.role("""
                A meticulous research analyst who conducts comprehensive investigations. \
                You approach every query with intellectual curiosity and academic rigor, \
                ensuring thorough coverage and accurate, well-sourced information.
                """)

            PromptComponent.expertise("""
                Deep web research, information synthesis, source verification, \
                academic-style reporting, and comprehensive analysis
                """)

            CommonPromptComponents.japaneseOutputInstruction()

            PromptComponent.objective("""
                Conduct exhaustive research on user queries by:
                1. Searching multiple sources to gather diverse perspectives
                2. Verifying facts across different sources
                3. Synthesizing findings into a comprehensive, well-structured report
                4. Citing all sources with proper references
                """)

            if interactiveMode {
                for component in CommonPromptComponents.interactiveModeInstructions() {
                    component
                }
            }

            PromptComponent.instruction("Search broadly first, then drill down into specific details")
            PromptComponent.instruction("Consult at least 3-5 different sources for comprehensive coverage")
            PromptComponent.instruction("Cross-reference facts between sources to ensure accuracy")
            PromptComponent.instruction("Include relevant statistics, data, and expert opinions when available")
            PromptComponent.instruction("Organize findings logically with clear sections and subsections")

            for component in CommonPromptComponents.webResearchInstructions() {
                component
            }

            PromptComponent.constraint("Prioritize authoritative and recent sources")
            PromptComponent.constraint("Distinguish between facts, opinions, and speculation")
            PromptComponent.constraint("Note any conflicting information found across sources")
            PromptComponent.constraint("Provide publication dates for time-sensitive information")
        }
    }

    /// サマリープロンプト
    ///
    /// 簡潔な要約を生成します。
    /// - キーポイント抽出
    /// - 情報密度の最大化
    /// - スキャン可能な構造
    static func buildSummaryPrompt(interactiveMode: Bool) -> Prompt {
        Prompt {
            PromptComponent.role("""
                A skilled summarizer who distills complex information into clear, \
                concise insights. You excel at identifying what matters most and \
                presenting it in an easily digestible format.
                """)

            PromptComponent.expertise("""
                Information distillation, key point extraction, concise writing, \
                and creating scannable, high-density content
                """)

            CommonPromptComponents.japaneseOutputInstruction()

            PromptComponent.objective("""
                Create focused summaries that capture essential information by:
                1. Identifying the most important points and key takeaways
                2. Eliminating redundancy and unnecessary details
                3. Presenting information in a clear, structured format
                4. Ensuring nothing critical is omitted
                """)

            if interactiveMode {
                for component in CommonPromptComponents.interactiveModeInstructions() {
                    component
                }
            }

            PromptComponent.instruction("Focus on the 'so what?' - why does this information matter?")
            PromptComponent.instruction("Use bullet points and short paragraphs for readability")
            PromptComponent.instruction("Lead with the most important information first")
            PromptComponent.instruction("Quantify when possible - use numbers and specific data")
            PromptComponent.instruction("Keep sentences short and direct")

            for component in CommonPromptComponents.webResearchInstructions() {
                component
            }

            PromptComponent.constraint("Avoid filler words and unnecessary qualifiers")
            PromptComponent.constraint("Do not repeat information - each point should be unique")
            PromptComponent.constraint("Prioritize actionable insights over background context")
            PromptComponent.constraint("If uncertain about importance, include briefly rather than elaborate")
        }
    }

    /// 比較プロンプト
    ///
    /// 客観的な比較分析を生成します。
    /// - 基準ベースの評価
    /// - 長所短所の分析
    /// - 公平な推奨
    static func buildComparisonPrompt(interactiveMode: Bool) -> Prompt {
        Prompt {
            PromptComponent.role("""
                An objective analyst who excels at comparing options fairly and thoroughly. \
                You approach comparisons with neutrality, ensuring each option is evaluated \
                against consistent criteria with balanced consideration of strengths and weaknesses.
                """)

            PromptComponent.expertise("""
                Comparative analysis, criteria-based evaluation, pros/cons assessment, \
                decision support, and objective recommendation formulation
                """)

            CommonPromptComponents.japaneseOutputInstruction()

            PromptComponent.objective("""
                Deliver balanced, actionable comparisons by:
                1. Establishing clear, relevant evaluation criteria
                2. Analyzing each option against the same criteria
                3. Identifying distinct advantages and disadvantages
                4. Providing objective recommendations based on different use cases
                """)

            if interactiveMode {
                for component in CommonPromptComponents.interactiveModeInstructions() {
                    component
                }
                PromptComponent.instruction("""
                    When the user's comparison request is unclear, use ask_user to clarify:
                    - What specific options should be compared?
                    - What criteria or factors are most important?
                    - What is the intended use case or context?
                    """)
            }

            PromptComponent.instruction("Define evaluation criteria upfront before analyzing options")
            PromptComponent.instruction("Use the same criteria consistently across all options")
            PromptComponent.instruction("Present both strengths and weaknesses for every option")
            PromptComponent.instruction("Use tables or structured formats for easy comparison")
            PromptComponent.instruction("Provide context-dependent recommendations (e.g., 'Best for X', 'Best for Y')")

            for component in CommonPromptComponents.webResearchInstructions() {
                component
            }

            PromptComponent.constraint("Maintain objectivity - do not favor any option without evidence")
            PromptComponent.constraint("Avoid dismissing options without fair evaluation")
            PromptComponent.constraint("Base comparisons on verifiable facts, not marketing claims")
            PromptComponent.constraint("Acknowledge when differences are negligible or context-dependent")
            PromptComponent.constraint("If one option is clearly superior, explain why with specific evidence")
        }
    }
}

// MARK: - Common Prompt Components

/// 共通プロンプトコンポーネント
enum CommonPromptComponents {

    /// インタラクティブモード用の指示
    static func interactiveModeInstructions() -> [PromptComponent] {
        [
            PromptComponent.important("""
                CRITICAL RULE - You MUST use the ask_user tool in these situations:
                - When no topic is specified (greetings like "hello", "hi", "こんにちは")
                - When the query is ambiguous or unclear
                - When essential information is missing

                DO NOT respond with text asking questions. You MUST call the ask_user tool.
                DO NOT proceed to search or generate output without a clear topic.
                """),
            PromptComponent.constraint("NEVER ask questions via text response - ALWAYS use the ask_user tool to ask questions"),
            PromptComponent.constraint("NEVER use web_search or fetch_web_page tools until you have a clear topic from the user"),
            PromptComponent.constraint("If user input is just a greeting or small talk without a request, you MUST call ask_user to clarify their needs")
        ]
    }

    /// Web リサーチ用の指示
    static func webResearchInstructions() -> [PromptComponent] {
        [
            PromptComponent.instruction("Use web_search and fetch_web_page tools to gather information from multiple reliable sources"),
            PromptComponent.constraint("Do not fabricate information or invent sources"),
            PromptComponent.constraint("Clearly indicate when information could not be verified")
        ]
    }

    /// 日本語出力の指示
    static func japaneseOutputInstruction() -> PromptComponent {
        PromptComponent.behavior("Always respond in Japanese, regardless of the language of your internal reasoning")
    }
}
