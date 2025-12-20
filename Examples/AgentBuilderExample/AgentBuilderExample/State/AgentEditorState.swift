import SwiftUI
import LLMClient

/// エージェント編集の共有状態
@MainActor @Observable
final class AgentEditorState {
    var agent: Agent?
    var isNew: Bool = false

    func startEditing(_ agent: Agent, isNew: Bool) {
        self.agent = agent
        self.isNew = isNew
    }

    func finishEditing() {
        agent = nil
        isNew = false
    }

    // Field operations
    var newFieldTemplate: Field { Field(name: "", type: .string) }

    func field(at index: Int) -> Field? {
        guard let agent, index < agent.outputSchema.fields.count else { return nil }
        return agent.outputSchema.fields[index]
    }

    func updateField(_ field: Field, at index: Int) {
        guard var agent, index < agent.outputSchema.fields.count else { return }
        agent.outputSchema.fields[index] = field
        self.agent = agent
    }

    func addField(_ field: Field) {
        guard var agent else { return }
        agent.outputSchema.fields.append(field)
        self.agent = agent
    }

    func deleteField(at index: Int) {
        guard var agent else { return }
        agent.outputSchema.fields.remove(at: index)
        self.agent = agent
    }

    func moveFields(from source: IndexSet, to destination: Int) {
        guard var agent else { return }
        agent.outputSchema.fields.move(fromOffsets: source, toOffset: destination)
        self.agent = agent
    }

    // Prompt operations
    func promptItem(at index: Int) -> PromptItem? {
        guard let agent, index < agent.systemPrompt.components.count else { return nil }
        return PromptItem(from: agent.systemPrompt.components[index])
    }

    func updatePromptItem(_ item: PromptItem, at index: Int) {
        guard var agent else { return }
        var components = agent.systemPrompt.components
        if index < components.count {
            components[index] = item.toPromptComponent()
            agent.systemPrompt = Prompt(components: components)
            self.agent = agent
        }
    }

    func addPromptItem(_ item: PromptItem) {
        guard var agent else { return }
        var components = agent.systemPrompt.components
        components.append(item.toPromptComponent())
        agent.systemPrompt = Prompt(components: components)
        self.agent = agent
    }

    func deletePromptItem(at index: Int) {
        guard var agent else { return }
        var components = agent.systemPrompt.components
        components.remove(at: index)
        agent.systemPrompt = Prompt(components: components)
        self.agent = agent
    }

    func movePromptItems(from source: IndexSet, to destination: Int) {
        guard var agent else { return }
        var components = agent.systemPrompt.components
        components.move(fromOffsets: source, toOffset: destination)
        agent.systemPrompt = Prompt(components: components)
        self.agent = agent
    }
}

// Environment key
private struct AgentEditorStateKey: EnvironmentKey {
    static let defaultValue: AgentEditorState? = nil
}

extension EnvironmentValues {
    var agentEditorState: AgentEditorState? {
        get { self[AgentEditorStateKey.self] }
        set { self[AgentEditorStateKey.self] = newValue }
    }
}
