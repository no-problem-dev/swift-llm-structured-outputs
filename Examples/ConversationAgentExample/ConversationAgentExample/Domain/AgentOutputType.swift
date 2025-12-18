import Foundation
import LLMStructuredOutputs
import LLMToolkits

/// エージェント出力タイプ
enum AgentOutputType: String, CaseIterable, Identifiable, Codable {
    case research
    case articleSummary
    case codeReview

    var id: String { rawValue }

    // MARK: - Tool Configuration

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

    // MARK: - Prompt Building

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
}

// MARK: - Prompt Implementations

private extension AgentOutputType {

    func buildResearchPrompt(interactiveMode: Bool) -> Prompt {
        Prompt {
            for component in ResearcherPreset.systemPrompt.components {
                component
            }

            PromptComponent.behavior("Always respond in Japanese, regardless of the language of your internal reasoning")

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

    func buildArticleSummaryPrompt(interactiveMode: Bool) -> Prompt {
        Prompt {
            for component in WriterPreset.systemPrompt.components {
                component
            }

            PromptComponent.behavior("Always respond in Japanese, regardless of the language of your internal reasoning")

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

    func buildCodeReviewPrompt(interactiveMode: Bool) -> Prompt {
        Prompt {
            for component in CodingAssistantPreset.systemPrompt.components {
                component
            }

            PromptComponent.behavior("Always respond in Japanese, regardless of the language of your internal reasoning")

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

enum CommonPromptComponents {

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
