import XCTest
@testable import LLMStructuredOutputs

final class PromptTests: XCTestCase {

    // MARK: - Basic Initialization

    func testEmptyPrompt() {
        let prompt = Prompt { }

        XCTAssertTrue(prompt.isEmpty)
        XCTAssertEqual(prompt.count, 0)
        XCTAssertEqual(prompt.render(), "")
    }

    func testSingleComponentPrompt() {
        let prompt = Prompt {
            PromptComponent.objective("テスト目的")
        }

        XCTAssertFalse(prompt.isEmpty)
        XCTAssertEqual(prompt.count, 1)
        XCTAssertEqual(
            prompt.render(),
            """
            <objective>
            テスト目的
            </objective>
            """
        )
    }

    func testMultipleComponentsPrompt() {
        let prompt = Prompt {
            PromptComponent.role("専門家")
            PromptComponent.objective("情報抽出")
            PromptComponent.instruction("名前を抽出")
        }

        XCTAssertEqual(prompt.count, 3)
        XCTAssertEqual(
            prompt.render(),
            """
            <role>
            専門家
            </role>

            <objective>
            情報抽出
            </objective>

            <instruction>
            名前を抽出
            </instruction>
            """
        )
    }

    // MARK: - Order Preservation Tests

    func testComponentOrderPreservation() {
        let prompt = Prompt {
            PromptComponent.instruction("最初")
            PromptComponent.role("途中")
            PromptComponent.constraint("最後")
        }

        let rendered = prompt.render()
        let instructionIndex = rendered.range(of: "<instruction>")!.lowerBound
        let roleIndex = rendered.range(of: "<role>")!.lowerBound
        let constraintIndex = rendered.range(of: "<constraint>")!.lowerBound

        // 記述順が保持されていることを確認
        XCTAssertTrue(instructionIndex < roleIndex)
        XCTAssertTrue(roleIndex < constraintIndex)
    }

    func testComponentOrderWithMixedTypes() {
        let prompt = Prompt {
            PromptComponent.context("コンテキスト1")
            PromptComponent.example(input: "入力", output: "出力")
            PromptComponent.context("コンテキスト2")
            PromptComponent.important("重要事項")
            PromptComponent.context("コンテキスト3")
        }

        XCTAssertEqual(prompt.count, 5)

        let rendered = prompt.render()

        // 同じ種類のコンポーネントが散在しても順序が保持されることを確認
        let context1Index = rendered.range(of: "コンテキスト1")!.lowerBound
        let exampleIndex = rendered.range(of: "<example>")!.lowerBound
        let context2Index = rendered.range(of: "コンテキスト2")!.lowerBound
        let importantIndex = rendered.range(of: "<important>")!.lowerBound
        let context3Index = rendered.range(of: "コンテキスト3")!.lowerBound

        XCTAssertTrue(context1Index < exampleIndex)
        XCTAssertTrue(exampleIndex < context2Index)
        XCTAssertTrue(context2Index < importantIndex)
        XCTAssertTrue(importantIndex < context3Index)
    }

    // MARK: - Result Builder Features

    func testOptionalComponentInclusion() {
        let includeExample = true

        let prompt = Prompt {
            PromptComponent.objective("テスト")
            if includeExample {
                PromptComponent.example(input: "入力", output: "出力")
            }
        }

        XCTAssertEqual(prompt.count, 2)
        XCTAssertTrue(prompt.render().contains("<example>"))
    }

    func testOptionalComponentExclusion() {
        let includeExample = false

        let prompt = Prompt {
            PromptComponent.objective("テスト")
            if includeExample {
                PromptComponent.example(input: "入力", output: "出力")
            }
        }

        XCTAssertEqual(prompt.count, 1)
        XCTAssertFalse(prompt.render().contains("<example>"))
    }

    func testIfElseBranching() {
        let useDetailedRole = true

        let prompt = Prompt {
            if useDetailedRole {
                PromptComponent.role("詳細な専門家の役割")
            } else {
                PromptComponent.role("シンプルな役割")
            }
        }

        XCTAssertTrue(prompt.render().contains("詳細な専門家の役割"))
        XCTAssertFalse(prompt.render().contains("シンプルな役割"))
    }

    func testForLoopInBuilder() {
        let steps = ["ステップ1", "ステップ2", "ステップ3"]

        let prompt = Prompt {
            PromptComponent.objective("タスク実行")
            for step in steps {
                PromptComponent.thinkingStep(step)
            }
        }

        XCTAssertEqual(prompt.count, 4) // objective + 3 steps
        XCTAssertTrue(prompt.render().contains("ステップ1"))
        XCTAssertTrue(prompt.render().contains("ステップ2"))
        XCTAssertTrue(prompt.render().contains("ステップ3"))
    }

    // MARK: - Direct Initialization

    func testDirectComponentsInitialization() {
        let components: [PromptComponent] = [
            .objective("目的"),
            .instruction("指示")
        ]

        let prompt = Prompt(components: components)

        XCTAssertEqual(prompt.count, 2)
        XCTAssertEqual(prompt.components, components)
    }

    // MARK: - String Literal Initialization

    func testStringLiteralInitialization() {
        let prompt: Prompt = "これはシンプルなプロンプトです"

        XCTAssertEqual(prompt.count, 1)
        XCTAssertEqual(
            prompt.render(),
            """
            <context>
            これはシンプルなプロンプトです
            </context>
            """
        )
    }

    // MARK: - Combination Tests

    func testPromptAddition() {
        let prompt1 = Prompt {
            PromptComponent.role("専門家")
        }

        let prompt2 = Prompt {
            PromptComponent.objective("目的")
        }

        let combined = prompt1 + prompt2

        XCTAssertEqual(combined.count, 2)
        XCTAssertTrue(combined.render().contains("<role>"))
        XCTAssertTrue(combined.render().contains("<objective>"))
    }

    func testPromptComponentAddition() {
        let prompt = Prompt {
            PromptComponent.role("専門家")
        }

        let extended = prompt + PromptComponent.objective("追加の目的")

        XCTAssertEqual(extended.count, 2)
        XCTAssertTrue(extended.render().contains("<role>"))
        XCTAssertTrue(extended.render().contains("追加の目的"))
    }

    func testAppendingPrompt() {
        let prompt1 = Prompt {
            PromptComponent.role("専門家")
        }

        let prompt2 = Prompt {
            PromptComponent.instruction("指示")
        }

        let combined = prompt1.appending(prompt2)

        XCTAssertEqual(combined.count, 2)
    }

    func testAppendingComponent() {
        let prompt = Prompt {
            PromptComponent.role("専門家")
        }

        let extended = prompt.appending(.objective("目的"))

        XCTAssertEqual(extended.count, 2)
    }

    // MARK: - Filtering Tests

    func testFilterComponents() {
        let prompt = Prompt {
            PromptComponent.instruction("指示1")
            PromptComponent.constraint("制約1")
            PromptComponent.instruction("指示2")
            PromptComponent.constraint("制約2")
        }

        let instructionsOnly = prompt.filter { component in
            if case .instruction = component { return true }
            return false
        }

        XCTAssertEqual(instructionsOnly.count, 2)
        XCTAssertTrue(instructionsOnly.render().contains("指示1"))
        XCTAssertTrue(instructionsOnly.render().contains("指示2"))
        XCTAssertFalse(instructionsOnly.render().contains("制約"))
    }

    func testComponentsWithTag() {
        let prompt = Prompt {
            PromptComponent.instruction("指示1")
            PromptComponent.constraint("制約1")
            PromptComponent.instruction("指示2")
        }

        let instructions = prompt.components(withTag: "instruction")

        XCTAssertEqual(instructions.count, 2)
    }

    // MARK: - Equality Tests

    func testPromptEquality() {
        let prompt1 = Prompt {
            PromptComponent.role("専門家")
            PromptComponent.objective("目的")
        }

        let prompt2 = Prompt {
            PromptComponent.role("専門家")
            PromptComponent.objective("目的")
        }

        XCTAssertEqual(prompt1, prompt2)
    }

    func testPromptInequality() {
        let prompt1 = Prompt {
            PromptComponent.role("専門家")
        }

        let prompt2 = Prompt {
            PromptComponent.role("初心者")
        }

        XCTAssertNotEqual(prompt1, prompt2)
    }

    func testPromptOrderMattersForEquality() {
        let prompt1 = Prompt {
            PromptComponent.role("専門家")
            PromptComponent.objective("目的")
        }

        let prompt2 = Prompt {
            PromptComponent.objective("目的")
            PromptComponent.role("専門家")
        }

        // 順序が違うので不等
        XCTAssertNotEqual(prompt1, prompt2)
    }

    // MARK: - CustomStringConvertible Tests

    func testDescription() {
        let prompt = Prompt {
            PromptComponent.objective("テスト")
        }

        XCTAssertEqual(prompt.description, prompt.render())
    }

    // MARK: - Sendable Tests

    func testSendableConformance() {
        let prompt = Prompt {
            PromptComponent.role("テスト")
        }

        Task {
            let _ = prompt
        }

        XCTAssertTrue(true)
    }

    // MARK: - Complex Prompt Tests

    func testComplexPromptWithAllComponentTypes() {
        let prompt = Prompt {
            // ペルソナ
            PromptComponent.role("データ分析の専門家")
            PromptComponent.expertise("構造化データ抽出")
            PromptComponent.behavior("正確性を最優先する")

            // タスク定義
            PromptComponent.objective("テキストからユーザー情報を抽出する")
            PromptComponent.context("日本語のSNS投稿が入力される")

            // 指示
            PromptComponent.instruction("名前は敬称を除いて抽出する")
            PromptComponent.instruction("年齢は数値のみ抽出する")

            // Chain-of-Thought
            PromptComponent.thinkingStep("まずテキスト内の人名を特定する")
            PromptComponent.thinkingStep("次に年齢に関する記述を探す")
            PromptComponent.reasoning("敬称を除くのはデータの正規化のため")

            // 制約
            PromptComponent.constraint("推測はしない")
            PromptComponent.constraint("明示的に記載された情報のみ使用")

            // メタ指示
            PromptComponent.important("不明な情報は必ずnullを返す")
            PromptComponent.note("西暦と和暦が混在している場合がある")

            // Few-shot
            PromptComponent.example(
                input: "佐藤花子さん（28）は東京在住",
                output: #"{"name": "佐藤花子", "age": 28}"#
            )
        }

        XCTAssertEqual(prompt.count, 15)

        let rendered = prompt.render()

        // 全てのセクションが含まれていることを確認
        XCTAssertTrue(rendered.contains("<role>"))
        XCTAssertTrue(rendered.contains("<expertise>"))
        XCTAssertTrue(rendered.contains("<behavior>"))
        XCTAssertTrue(rendered.contains("<objective>"))
        XCTAssertTrue(rendered.contains("<context>"))
        XCTAssertTrue(rendered.contains("<instruction>"))
        XCTAssertTrue(rendered.contains("<thinking_step>"))
        XCTAssertTrue(rendered.contains("<reasoning>"))
        XCTAssertTrue(rendered.contains("<constraint>"))
        XCTAssertTrue(rendered.contains("<important>"))
        XCTAssertTrue(rendered.contains("<note>"))
        XCTAssertTrue(rendered.contains("<example>"))
    }

    // MARK: - Rendering Format Tests

    func testRenderingWithDoubleNewlineSeparators() {
        let prompt = Prompt {
            PromptComponent.role("役割")
            PromptComponent.objective("目的")
        }

        let rendered = prompt.render()
        let parts = rendered.components(separatedBy: "\n\n")

        // 2つのコンポーネントが空行で区切られている
        XCTAssertEqual(parts.count, 2)
    }

    // MARK: - Edge Cases

    func testEmptyStringComponents() {
        let prompt = Prompt {
            PromptComponent.objective("")
            PromptComponent.instruction("")
        }

        XCTAssertEqual(prompt.count, 2)
        // 空文字列でもレンダリングは行われる
        XCTAssertFalse(prompt.render().isEmpty)
    }

    func testVeryLongContent() {
        let longText = String(repeating: "これは非常に長いテキストです。", count: 100)
        let prompt = Prompt {
            PromptComponent.context(longText)
        }

        XCTAssertTrue(prompt.render().contains(longText))
    }
}
