import SwiftUI
import LLMStructuredOutputs
import LLMToolkits

// MARK: - Agent Output Type

/// エージェント出力タイプ
///
/// LLMToolkits のプリセットと出力型を活用した3つのシナリオ：
/// - Research: Web検索によるリサーチ → AnalysisResult
/// - Article Summary: URL入力による記事要約 → Summary
/// - Code Review: コード入力によるレビュー → CodeReview
enum AgentOutputType: String, CaseIterable, Identifiable, Codable {
    case research
    case articleSummary
    case codeReview

    var id: String { rawValue }

    // MARK: - UI Properties

    var displayName: String {
        switch self {
        case .research: "リサーチ"
        case .articleSummary: "記事要約"
        case .codeReview: "コードレビュー"
        }
    }

    var icon: String {
        switch self {
        case .research: "magnifyingglass.circle.fill"
        case .articleSummary: "doc.text.fill"
        case .codeReview: "chevron.left.forwardslash.chevron.right"
        }
    }

    var tintColor: Color {
        switch self {
        case .research: .blue
        case .articleSummary: .green
        case .codeReview: .orange
        }
    }

    var subtitle: String {
        switch self {
        case .research: "Web検索で詳細調査"
        case .articleSummary: "URLから記事を要約"
        case .codeReview: "コードの品質評価"
        }
    }

    var placeholder: String {
        switch self {
        case .research: "調べたいトピックを入力してください"
        case .articleSummary: "記事のURLを入力してください"
        case .codeReview: "レビューしたいコードを貼り付けてください"
        }
    }

    // MARK: - Prompt Building

    /// LLMToolkits のプリセットをベースにカスタマイズしたプロンプトを構築
    func buildPrompt(interactiveMode: Bool) -> Prompt {
        switch self {
        case .research:
            buildResearchPrompt(interactiveMode: interactiveMode)
        case .articleSummary:
            buildArticleSummaryPrompt(interactiveMode: interactiveMode)
        case .codeReview:
            buildCodeReviewPrompt(interactiveMode: interactiveMode)
        }
    }

    // MARK: - Tool Configuration

    /// 各シナリオに必要なツールを判定
    var requiresWebSearch: Bool {
        switch self {
        case .research: true
        case .articleSummary: false
        case .codeReview: false
        }
    }

    var requiresWebFetch: Bool {
        switch self {
        case .research: true
        case .articleSummary: true
        case .codeReview: false
        }
    }
}

// MARK: - Prompt Implementations

private extension AgentOutputType {

    /// リサーチプロンプト
    ///
    /// ResearcherPreset をベースに Web 検索機能を追加
    func buildResearchPrompt(interactiveMode: Bool) -> Prompt {
        Prompt {
            // ResearcherPreset のベースプロンプトを取得
            for component in ResearcherPreset.systemPrompt.components {
                component
            }

            // 日本語出力指示
            PromptComponent.behavior("Always respond in Japanese, regardless of the language of your internal reasoning")

            // Web リサーチ用の追加指示
            PromptComponent.instruction("Use web_search to find relevant information from multiple sources")
            PromptComponent.instruction("Use fetch_web_page to read detailed content from important URLs")
            PromptComponent.instruction("Consult at least 3-5 different sources for comprehensive coverage")
            PromptComponent.instruction("Cross-reference facts between sources to ensure accuracy")

            if interactiveMode {
                for component in CommonPromptComponents.interactiveModeInstructions() {
                    component
                }
            }

            PromptComponent.constraint("Do not fabricate information or invent sources")
            PromptComponent.constraint("Clearly indicate when information could not be verified")
        }
    }

    /// 記事要約プロンプト
    ///
    /// WriterPreset をベースに URL からの要約に特化
    func buildArticleSummaryPrompt(interactiveMode: Bool) -> Prompt {
        Prompt {
            // WriterPreset のベースプロンプトを取得
            for component in WriterPreset.systemPrompt.components {
                component
            }

            // 日本語出力指示
            PromptComponent.behavior("Always respond in Japanese, regardless of the language of your internal reasoning")

            // 記事要約用の追加指示
            PromptComponent.instruction("Use fetch_web_page to retrieve the article content from the provided URL")
            PromptComponent.instruction("Focus on extracting the main points and key takeaways")
            PromptComponent.instruction("Identify the target audience the content is intended for")
            PromptComponent.instruction("Keep the summary concise but comprehensive")

            if interactiveMode {
                for component in CommonPromptComponents.interactiveModeInstructions() {
                    component
                }
            }

            PromptComponent.constraint("Do not add information that is not in the original article")
            PromptComponent.constraint("Preserve the original meaning when summarizing")
        }
    }

    /// コードレビュープロンプト
    ///
    /// CodingAssistantPreset をベースにコードレビューに特化
    func buildCodeReviewPrompt(interactiveMode: Bool) -> Prompt {
        Prompt {
            // CodingAssistantPreset のベースプロンプトを取得
            for component in CodingAssistantPreset.systemPrompt.components {
                component
            }

            // 日本語出力指示
            PromptComponent.behavior("Always respond in Japanese, regardless of the language of your internal reasoning")

            // コードレビュー用の追加指示
            PromptComponent.instruction("Analyze the provided code for bugs, security issues, and performance problems")
            PromptComponent.instruction("Evaluate code quality including readability and maintainability")
            PromptComponent.instruction("Identify positive aspects of the code as well as areas for improvement")
            PromptComponent.instruction("Provide specific suggestions with examples when possible")
            PromptComponent.instruction("Rate the overall quality on a scale of 1-10")

            if interactiveMode {
                for component in CommonPromptComponents.interactiveModeInstructions() {
                    component
                }
            }

            PromptComponent.constraint("Focus on constructive feedback that helps improve the code")
            PromptComponent.constraint("Distinguish between critical issues and minor style suggestions")
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
            PromptComponent.constraint("If user input is just a greeting or small talk without a request, you MUST call ask_user to clarify their needs")
        ]
    }
}
