import XCTest
@testable import LLMStructuredOutputs

/// PromptComponent DSL テスト
///
/// `PromptComponent.role(...)` のような記法でプロンプトを構築できることを確認
final class PromptComponentDSLTests: XCTestCase {

    // MARK: - 基本テスト

    func testSingleComponent() {
        let component: PromptComponent = .role("テスト")
        XCTAssertEqual(component, PromptComponent.role("テスト"))
    }

    // MARK: - DSL テスト

    func testBasicDSL() {
        let prompt = Prompt {
            PromptComponent.role("データアナリスト")
            PromptComponent.objective("情報抽出")
            PromptComponent.instruction("名前を抽出")
        }

        XCTAssertEqual(prompt.count, 3)
        XCTAssertTrue(prompt.render().contains("データアナリスト"))
        XCTAssertTrue(prompt.render().contains("情報抽出"))
        XCTAssertTrue(prompt.render().contains("名前を抽出"))
    }

    func testAllComponents() {
        let prompt = Prompt {
            // ペルソナ系
            PromptComponent.role("専門家")
            PromptComponent.expertise("データ分析")
            PromptComponent.behavior("正確に回答する")

            // タスク定義系
            PromptComponent.objective("情報を抽出する")
            PromptComponent.context("日本語テキストが入力される")
            PromptComponent.instruction("名前を抽出")
            PromptComponent.constraint("推測しない")

            // Chain-of-Thought
            PromptComponent.thinkingStep("まず人名を探す")
            PromptComponent.reasoning("正規化のため")

            // Few-shot
            PromptComponent.example(input: "花子さん", output: "花子")

            // メタ指示
            PromptComponent.important("nullを返す")
            PromptComponent.note("補足情報")
        }

        XCTAssertEqual(prompt.count, 12)
    }

    func testWithConditional() {
        let useExpertise = true

        let prompt = Prompt {
            PromptComponent.role("専門家")
            if useExpertise {
                PromptComponent.expertise("高度な分析")
            }
            PromptComponent.objective("タスク実行")
        }

        XCTAssertEqual(prompt.count, 3)
    }

    func testWithLoop() {
        let steps = ["ステップ1", "ステップ2", "ステップ3"]

        let prompt = Prompt {
            PromptComponent.objective("処理実行")
            for step in steps {
                PromptComponent.thinkingStep(step)
            }
        }

        XCTAssertEqual(prompt.count, 4)
    }
}
