import XCTest
@testable import LLMStructuredOutputs

final class PromptComponentTests: XCTestCase {

    // MARK: - Persona Components

    func testRoleComponent() {
        let component = PromptComponent.role("データ分析の専門家")

        XCTAssertEqual(component.tagName, "role")
        XCTAssertEqual(
            component.render(),
            """
            <role>
            データ分析の専門家
            </role>
            """
        )
    }

    func testExpertiseComponent() {
        let component = PromptComponent.expertise("iOS アプリ開発")

        XCTAssertEqual(component.tagName, "expertise")
        XCTAssertEqual(
            component.render(),
            """
            <expertise>
            iOS アプリ開発
            </expertise>
            """
        )
    }

    func testBehaviorComponent() {
        let component = PromptComponent.behavior("簡潔かつ実用的なアドバイスを提供する")

        XCTAssertEqual(component.tagName, "behavior")
        XCTAssertEqual(
            component.render(),
            """
            <behavior>
            簡潔かつ実用的なアドバイスを提供する
            </behavior>
            """
        )
    }

    // MARK: - Task Definition Components

    func testObjectiveComponent() {
        let component = PromptComponent.objective("ユーザー情報を抽出する")

        XCTAssertEqual(component.tagName, "objective")
        XCTAssertEqual(
            component.render(),
            """
            <objective>
            ユーザー情報を抽出する
            </objective>
            """
        )
    }

    func testContextComponent() {
        let component = PromptComponent.context("日本語のSNS投稿が入力される")

        XCTAssertEqual(component.tagName, "context")
        XCTAssertEqual(
            component.render(),
            """
            <context>
            日本語のSNS投稿が入力される
            </context>
            """
        )
    }

    func testInstructionComponent() {
        let component = PromptComponent.instruction("名前は敬称を除いて抽出する")

        XCTAssertEqual(component.tagName, "instruction")
        XCTAssertEqual(
            component.render(),
            """
            <instruction>
            名前は敬称を除いて抽出する
            </instruction>
            """
        )
    }

    func testConstraintComponent() {
        let component = PromptComponent.constraint("推測はしない")

        XCTAssertEqual(component.tagName, "constraint")
        XCTAssertEqual(
            component.render(),
            """
            <constraint>
            推測はしない
            </constraint>
            """
        )
    }

    // MARK: - Chain-of-Thought Components

    func testThinkingStepComponent() {
        let component = PromptComponent.thinkingStep("まずテキスト内の人名を特定する")

        XCTAssertEqual(component.tagName, "thinking_step")
        XCTAssertEqual(
            component.render(),
            """
            <thinking_step>
            まずテキスト内の人名を特定する
            </thinking_step>
            """
        )
    }

    func testReasoningComponent() {
        let component = PromptComponent.reasoning("敬称を除くのはデータの正規化のため")

        XCTAssertEqual(component.tagName, "reasoning")
        XCTAssertEqual(
            component.render(),
            """
            <reasoning>
            敬称を除くのはデータの正規化のため
            </reasoning>
            """
        )
    }

    // MARK: - Few-shot Components

    func testExampleComponent() {
        let component = PromptComponent.example(
            input: "佐藤花子さん（28）は東京在住",
            output: #"{"name": "佐藤花子", "age": 28}"#
        )

        XCTAssertEqual(component.tagName, "example")
        XCTAssertEqual(
            component.render(),
            """
            <example>
            Input: 佐藤花子さん（28）は東京在住
            Output: {"name": "佐藤花子", "age": 28}
            </example>
            """
        )
    }

    func testExampleComponentWithMultilineInput() {
        let component = PromptComponent.example(
            input: "これは\n複数行の\n入力です",
            output: "複数行出力"
        )

        XCTAssertEqual(
            component.render(),
            """
            <example>
            Input: これは
            複数行の
            入力です
            Output: 複数行出力
            </example>
            """
        )
    }

    // MARK: - Meta Instruction Components

    func testImportantComponent() {
        let component = PromptComponent.important("不明な情報は必ずnullを返す")

        XCTAssertEqual(component.tagName, "important")
        XCTAssertEqual(
            component.render(),
            """
            <important>
            不明な情報は必ずnullを返す
            </important>
            """
        )
    }

    func testNoteComponent() {
        let component = PromptComponent.note("西暦と和暦が混在している場合がある")

        XCTAssertEqual(component.tagName, "note")
        XCTAssertEqual(
            component.render(),
            """
            <note>
            西暦と和暦が混在している場合がある
            </note>
            """
        )
    }

    // MARK: - Equality Tests

    func testRoleEquality() {
        let role1 = PromptComponent.role("専門家")
        let role2 = PromptComponent.role("専門家")
        let role3 = PromptComponent.role("初心者")

        XCTAssertEqual(role1, role2)
        XCTAssertNotEqual(role1, role3)
    }

    func testExampleEquality() {
        let example1 = PromptComponent.example(input: "入力", output: "出力")
        let example2 = PromptComponent.example(input: "入力", output: "出力")
        let example3 = PromptComponent.example(input: "入力", output: "別の出力")
        let example4 = PromptComponent.example(input: "別の入力", output: "出力")

        XCTAssertEqual(example1, example2)
        XCTAssertNotEqual(example1, example3)
        XCTAssertNotEqual(example1, example4)
    }

    func testDifferentComponentTypesNotEqual() {
        let role = PromptComponent.role("テスト")
        let objective = PromptComponent.objective("テスト")
        let context = PromptComponent.context("テスト")

        XCTAssertNotEqual(role, objective)
        XCTAssertNotEqual(objective, context)
        XCTAssertNotEqual(role, context)
    }

    // MARK: - Tag Name Tests

    func testAllTagNames() {
        XCTAssertEqual(PromptComponent.role("").tagName, "role")
        XCTAssertEqual(PromptComponent.expertise("").tagName, "expertise")
        XCTAssertEqual(PromptComponent.behavior("").tagName, "behavior")
        XCTAssertEqual(PromptComponent.objective("").tagName, "objective")
        XCTAssertEqual(PromptComponent.context("").tagName, "context")
        XCTAssertEqual(PromptComponent.instruction("").tagName, "instruction")
        XCTAssertEqual(PromptComponent.constraint("").tagName, "constraint")
        XCTAssertEqual(PromptComponent.thinkingStep("").tagName, "thinking_step")
        XCTAssertEqual(PromptComponent.reasoning("").tagName, "reasoning")
        XCTAssertEqual(PromptComponent.example(input: "", output: "").tagName, "example")
        XCTAssertEqual(PromptComponent.important("").tagName, "important")
        XCTAssertEqual(PromptComponent.note("").tagName, "note")
    }

    // MARK: - CustomStringConvertible Tests

    func testDescription() {
        let component = PromptComponent.objective("テスト目的")

        XCTAssertEqual(
            component.description,
            """
            <objective>
            テスト目的
            </objective>
            """
        )
    }

    // MARK: - Sendable Conformance Tests

    func testSendableConformance() {
        let component = PromptComponent.role("テスト")

        Task {
            let _ = component
        }

        // コンパイルが通れば Sendable 準拠は成功
        XCTAssertTrue(true)
    }

    // MARK: - Empty Value Tests

    func testEmptyStringValue() {
        let component = PromptComponent.objective("")

        XCTAssertEqual(
            component.render(),
            """
            <objective>

            </objective>
            """
        )
    }

    // MARK: - Special Character Tests

    func testSpecialCharactersInValue() {
        let component = PromptComponent.context("特殊文字: <>&\"'")

        // XMLエスケープは行わない（LLM側で処理される想定）
        XCTAssertEqual(
            component.render(),
            """
            <context>
            特殊文字: <>&\"'
            </context>
            """
        )
    }

    func testUnicodeCharacters() {
        let component = PromptComponent.context("絵文字: 🎉🚀 日本語: あいうえお")

        XCTAssertEqual(
            component.render(),
            """
            <context>
            絵文字: 🎉🚀 日本語: あいうえお
            </context>
            """
        )
    }

    // MARK: - Whitespace Handling Tests

    func testWhitespacePreservation() {
        let component = PromptComponent.instruction("  前後に空白  ")

        // 空白は保持される
        XCTAssertEqual(
            component.render(),
            "<instruction>\n  前後に空白  \n</instruction>"
        )
    }

    func testMultilineValue() {
        let component = PromptComponent.context(
            """
            これは複数行の
            コンテキストです。
            3行目もあります。
            """
        )

        XCTAssertEqual(
            component.render(),
            """
            <context>
            これは複数行の
            コンテキストです。
            3行目もあります。
            </context>
            """
        )
    }
}
