import XCTest
@testable import LLMStructuredOutputs
@testable import LLMClient

final class PromptBuilderTests: XCTestCase {

    // MARK: - Basic Block Building

    func testBuildBlockWithSingleComponent() {
        let components = PromptBuilder.buildBlock(
            [PromptComponent.objective("テスト")]
        )

        XCTAssertEqual(components.count, 1)
        XCTAssertEqual(components[0], .objective("テスト"))
    }

    func testBuildBlockWithMultipleComponents() {
        let components = PromptBuilder.buildBlock(
            [PromptComponent.role("役割")],
            [PromptComponent.objective("目的")],
            [PromptComponent.instruction("指示")]
        )

        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(components[0], .role("役割"))
        XCTAssertEqual(components[1], .objective("目的"))
        XCTAssertEqual(components[2], .instruction("指示"))
    }

    func testBuildBlockWithNoComponents() {
        let components = PromptBuilder.buildBlock()

        XCTAssertTrue(components.isEmpty)
    }

    // MARK: - Optional Building

    func testBuildOptionalWithValue() {
        let components: [PromptComponent]? = [.objective("テスト")]
        let result = PromptBuilder.buildOptional(components)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], .objective("テスト"))
    }

    func testBuildOptionalWithNil() {
        let components: [PromptComponent]? = nil
        let result = PromptBuilder.buildOptional(components)

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Either Building (if-else)

    func testBuildEitherFirst() {
        let components = [PromptComponent.role("First")]
        let result = PromptBuilder.buildEither(first: components)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], .role("First"))
    }

    func testBuildEitherSecond() {
        let components = [PromptComponent.role("Second")]
        let result = PromptBuilder.buildEither(second: components)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], .role("Second"))
    }

    // MARK: - Array Building (for-in)

    func testBuildArray() {
        let arrays: [[PromptComponent]] = [
            [.instruction("指示1")],
            [.instruction("指示2")],
            [.instruction("指示3")]
        ]

        let result = PromptBuilder.buildArray(arrays)

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], .instruction("指示1"))
        XCTAssertEqual(result[1], .instruction("指示2"))
        XCTAssertEqual(result[2], .instruction("指示3"))
    }

    func testBuildArrayWithEmptyArrays() {
        let arrays: [[PromptComponent]] = [
            [],
            [.instruction("指示")],
            []
        ]

        let result = PromptBuilder.buildArray(arrays)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], .instruction("指示"))
    }

    // MARK: - Expression Building

    func testBuildExpressionSingle() {
        let result = PromptBuilder.buildExpression(PromptComponent.objective("テスト"))

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], .objective("テスト"))
    }

    func testBuildExpressionArray() {
        let components = [
            PromptComponent.role("役割"),
            PromptComponent.objective("目的")
        ]

        let result = PromptBuilder.buildExpression(components)

        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Final Result Building

    func testBuildFinalResult() {
        let components = [PromptComponent.objective("テスト")]
        let result = PromptBuilder.buildFinalResult(components)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], .objective("テスト"))
    }

    // MARK: - Limited Availability Building

    func testBuildLimitedAvailability() {
        let components = [PromptComponent.objective("テスト")]
        let result = PromptBuilder.buildLimitedAvailability(components)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], .objective("テスト"))
    }

    // MARK: - Integration Tests with Prompt

    func testPromptWithConditional() {
        let includeConstraints = true

        let prompt = Prompt {
            PromptComponent.objective("テスト")
            if includeConstraints {
                PromptComponent.constraint("制約1")
                PromptComponent.constraint("制約2")
            }
        }

        XCTAssertEqual(prompt.count, 3)
    }

    func testPromptWithConditionalExcluded() {
        let includeConstraints = false

        let prompt = Prompt {
            PromptComponent.objective("テスト")
            if includeConstraints {
                PromptComponent.constraint("制約1")
                PromptComponent.constraint("制約2")
            }
        }

        XCTAssertEqual(prompt.count, 1)
    }

    func testPromptWithIfElse() {
        let isExpert = true

        let prompt = Prompt {
            if isExpert {
                PromptComponent.role("専門家")
                PromptComponent.expertise("高度な分析")
            } else {
                PromptComponent.role("アシスタント")
            }
            PromptComponent.objective("タスク実行")
        }

        XCTAssertEqual(prompt.count, 3)
        XCTAssertTrue(prompt.render().contains("専門家"))
        XCTAssertTrue(prompt.render().contains("高度な分析"))
        XCTAssertFalse(prompt.render().contains("アシスタント"))
    }

    func testPromptWithForLoop() {
        let items = ["A", "B", "C"]

        let prompt = Prompt {
            PromptComponent.objective("処理")
            for item in items {
                PromptComponent.instruction("処理項目: \(item)")
            }
        }

        XCTAssertEqual(prompt.count, 4)
        XCTAssertTrue(prompt.render().contains("処理項目: A"))
        XCTAssertTrue(prompt.render().contains("処理項目: B"))
        XCTAssertTrue(prompt.render().contains("処理項目: C"))
    }

    func testPromptWithNestedConditions() {
        let useRole = true
        let useExpertise = true

        let prompt = Prompt {
            if useRole {
                PromptComponent.role("専門家")
                if useExpertise {
                    PromptComponent.expertise("データ分析")
                }
            }
            PromptComponent.objective("タスク")
        }

        XCTAssertEqual(prompt.count, 3)
    }

    func testPromptWithEmptyLoop() {
        let items: [String] = []

        let prompt = Prompt {
            PromptComponent.objective("処理")
            for item in items {
                PromptComponent.instruction("処理項目: \(item)")
            }
        }

        XCTAssertEqual(prompt.count, 1)
    }

    func testPromptWithComplexLogic() {
        let examples = [
            ("入力1", "出力1"),
            ("入力2", "出力2")
        ]
        let useThinking = true
        let priority: String? = "高"

        let prompt = Prompt {
            PromptComponent.role("分析者")

            if useThinking {
                PromptComponent.thinkingStep("分析開始")
            }

            PromptComponent.objective("データ処理")

            if let priority = priority {
                PromptComponent.important("優先度: \(priority)")
            }

            for (input, output) in examples {
                PromptComponent.example(input: input, output: output)
            }
        }

        XCTAssertEqual(prompt.count, 6)
        XCTAssertTrue(prompt.render().contains("分析開始"))
        XCTAssertTrue(prompt.render().contains("優先度: 高"))
        XCTAssertTrue(prompt.render().contains("入力1"))
        XCTAssertTrue(prompt.render().contains("入力2"))
    }

    // MARK: - Order Preservation with Control Flow

    func testOrderPreservationWithConditional() {
        let prompt = Prompt {
            PromptComponent.instruction("1番目")
            if true {
                PromptComponent.instruction("2番目（条件内）")
            }
            PromptComponent.instruction("3番目")
        }

        let rendered = prompt.render()
        let first = rendered.range(of: "1番目")!.lowerBound
        let second = rendered.range(of: "2番目")!.lowerBound
        let third = rendered.range(of: "3番目")!.lowerBound

        XCTAssertTrue(first < second)
        XCTAssertTrue(second < third)
    }

    func testOrderPreservationWithLoop() {
        let prompt = Prompt {
            PromptComponent.instruction("開始")
            for i in 1...3 {
                PromptComponent.instruction("ループ\(i)")
            }
            PromptComponent.instruction("終了")
        }

        let rendered = prompt.render()
        let start = rendered.range(of: "開始")!.lowerBound
        let loop1 = rendered.range(of: "ループ1")!.lowerBound
        let loop2 = rendered.range(of: "ループ2")!.lowerBound
        let loop3 = rendered.range(of: "ループ3")!.lowerBound
        let end = rendered.range(of: "終了")!.lowerBound

        XCTAssertTrue(start < loop1)
        XCTAssertTrue(loop1 < loop2)
        XCTAssertTrue(loop2 < loop3)
        XCTAssertTrue(loop3 < end)
    }

    // MARK: - Edge Cases

    func testEmptyPrompt() {
        let prompt = Prompt { }
        XCTAssertTrue(prompt.isEmpty)
        XCTAssertEqual(prompt.count, 0)
    }

    func testSingleComponentInConditionalBlock() {
        let prompt = Prompt {
            if true {
                PromptComponent.objective("単一")
            }
        }

        XCTAssertEqual(prompt.count, 1)
    }

    func testMultipleConditionalsInSequence() {
        let a = true
        let b = false
        let c = true

        let prompt = Prompt {
            if a {
                PromptComponent.instruction("A")
            }
            if b {
                PromptComponent.instruction("B")
            }
            if c {
                PromptComponent.instruction("C")
            }
        }

        XCTAssertEqual(prompt.count, 2)
        XCTAssertTrue(prompt.render().contains("A"))
        XCTAssertFalse(prompt.render().contains("B"))
        XCTAssertTrue(prompt.render().contains("C"))
    }

    func testNestedLoops() {
        let outer = ["X", "Y"]
        let inner = [1, 2]

        let prompt = Prompt {
            for o in outer {
                for i in inner {
                    PromptComponent.instruction("\(o)\(i)")
                }
            }
        }

        XCTAssertEqual(prompt.count, 4)
        XCTAssertTrue(prompt.render().contains("X1"))
        XCTAssertTrue(prompt.render().contains("X2"))
        XCTAssertTrue(prompt.render().contains("Y1"))
        XCTAssertTrue(prompt.render().contains("Y2"))
    }
}
