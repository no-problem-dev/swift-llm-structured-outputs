import SwiftUI
import LLMClient

/// プロンプトコンポーネントの編集用モデル
struct PromptItem: Identifiable, Hashable {
    let id: UUID
    var kind: Kind
    var value: String
    var exampleOutput: String?

    init(id: UUID = UUID(), kind: Kind, value: String = "", exampleOutput: String? = nil) {
        self.id = id
        self.kind = kind
        self.value = value
        self.exampleOutput = exampleOutput
    }

    init(from component: PromptComponent) {
        self.id = UUID()
        switch component {
        case .role(let v): self.kind = .role; self.value = v; self.exampleOutput = nil
        case .expertise(let v): self.kind = .expertise; self.value = v; self.exampleOutput = nil
        case .behavior(let v): self.kind = .behavior; self.value = v; self.exampleOutput = nil
        case .objective(let v): self.kind = .objective; self.value = v; self.exampleOutput = nil
        case .context(let v): self.kind = .context; self.value = v; self.exampleOutput = nil
        case .instruction(let v): self.kind = .instruction; self.value = v; self.exampleOutput = nil
        case .constraint(let v): self.kind = .constraint; self.value = v; self.exampleOutput = nil
        case .thinkingStep(let v): self.kind = .thinkingStep; self.value = v; self.exampleOutput = nil
        case .reasoning(let v): self.kind = .reasoning; self.value = v; self.exampleOutput = nil
        case .example(let input, let output): self.kind = .example; self.value = input; self.exampleOutput = output
        case .important(let v): self.kind = .important; self.value = v; self.exampleOutput = nil
        case .note(let v): self.kind = .note; self.value = v; self.exampleOutput = nil
        case .outputConstraint(let v): self.kind = .outputConstraint; self.value = v; self.exampleOutput = nil
        }
    }

    func toPromptComponent() -> PromptComponent {
        switch kind {
        case .role: .role(value)
        case .expertise: .expertise(value)
        case .behavior: .behavior(value)
        case .objective: .objective(value)
        case .context: .context(value)
        case .instruction: .instruction(value)
        case .constraint: .constraint(value)
        case .thinkingStep: .thinkingStep(value)
        case .reasoning: .reasoning(value)
        case .example: .example(input: value, output: exampleOutput ?? "")
        case .important: .important(value)
        case .note: .note(value)
        case .outputConstraint: .outputConstraint(value)
        }
    }

    enum Kind: String, CaseIterable, Hashable {
        case role, expertise, behavior
        case objective, context, instruction, constraint
        case thinkingStep, reasoning
        case example
        case important, note, outputConstraint

        var displayName: String {
            switch self {
            case .role: "役割"
            case .expertise: "専門性"
            case .behavior: "振る舞い"
            case .objective: "目的"
            case .context: "コンテキスト"
            case .instruction: "指示"
            case .constraint: "制約"
            case .thinkingStep: "思考ステップ"
            case .reasoning: "推論"
            case .example: "例示"
            case .important: "重要事項"
            case .note: "補足"
            case .outputConstraint: "出力制約"
            }
        }

        var icon: String {
            switch self {
            case .role: "person.fill"
            case .expertise: "brain.head.profile"
            case .behavior: "figure.walk"
            case .objective: "target"
            case .context: "doc.text"
            case .instruction: "list.number"
            case .constraint: "exclamationmark.triangle"
            case .thinkingStep: "brain"
            case .reasoning: "lightbulb"
            case .example: "text.quote"
            case .important: "exclamationmark.circle.fill"
            case .note: "note.text"
            case .outputConstraint: "slider.horizontal.3"
            }
        }

        var color: Color {
            switch self {
            case .role, .expertise, .behavior: .blue
            case .objective, .context: .purple
            case .instruction, .constraint: .orange
            case .thinkingStep, .reasoning: .green
            case .example: .teal
            case .important: .red
            case .note: .gray
            case .outputConstraint: .indigo
            }
        }

        var hint: String {
            switch self {
            case .role: "LLMに特定の役割を与えます。例: 「経験豊富なSwiftエンジニア」"
            case .expertise: "役割に付随する専門知識を指定します。例: 「iOSアプリ開発」"
            case .behavior: "回答のスタイルや態度を指定します。例: 「簡潔かつ実用的なアドバイス」"
            case .objective: "プロンプトの主要な目的やゴールを明示します。"
            case .context: "タスクに関連する背景情報や状況を説明します。"
            case .instruction: "タスクを遂行するための具体的な手順を指定します。"
            case .constraint: "回答に対する制限や禁止事項を指定します。例: 「推測はしない」"
            case .thinkingStep: "Chain-of-Thoughtで特定の思考プロセスを促します。"
            case .reasoning: "なぜそのような処理をするのかの理由を説明します。"
            case .example: "Few-shotプロンプティングで期待する入出力パターンを例示します。"
            case .important: "特に重要な指示や注意点を強調します。"
            case .note: "補足的な情報やヒントを提供します。"
            case .outputConstraint: "出力値の技術的な制約を指定します。"
            }
        }
    }
}
