import SwiftUI
import UIRouting

/// エージェント編集画面へのルートビュー
struct AgentEditorRouteView: View {
    @Environment(.router(AppRoute.self)) private var router
    @Environment(\.agentEditorState) private var editorState
    @Environment(AppState.self) private var appState
    @Environment(\.useCase) private var useCase

    var body: some View {
        if let state = editorState, state.agent != nil {
            AgentEditorView(
                editorState: state,
                isNew: state.isNew,
                onSave: { savedAgent in
                    saveAgent(savedAgent, isNew: state.isNew)
                    state.finishEditing()
                    router.back()
                }
            )
        } else {
            ContentUnavailableView(
                "エディタの状態が見つかりません",
                systemImage: "exclamationmark.triangle"
            )
        }
    }

    private func saveAgent(_ agent: Agent, isNew: Bool) {
        do {
            try useCase.agent.save(agent)
            if isNew {
                appState.addAgent(agent)
            } else {
                appState.updateAgent(agent)
            }
        } catch {
            print("Failed to save agent: \(error)")
        }
    }
}
