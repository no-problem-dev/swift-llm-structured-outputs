import SwiftUI
import UIRouting
import ExamplesCommon

/// エージェント詳細画面へのルートビュー
struct AgentDetailRouteView: View {
    let agent: Agent

    @Environment(.router(AppRoute.self)) private var router
    @Environment(\.agentEditorState) private var editorState
    @Environment(AppState.self) private var appState
    @Environment(\.useCase) private var useCase

    var body: some View {
        AgentDetailView(
            agent: agent,
            onEdit: { agent in
                editorState?.startEditing(agent, isNew: false)
                router.navigate(to: .agentEditor)
            },
            onStartSession: { agent in
                startNewSession(for: agent)
            }
        )
    }

    private func startNewSession(for agent: Agent) {
        let newSession = useCase.session.create(
            agentId: agent.id,
            provider: appState.selectedProvider.rawValue
        )
        do {
            try useCase.session.save(newSession)
            appState.addSession(newSession)
            router.navigate(to: .chat(session: newSession, agent: agent))
        } catch {
            print("Failed to create session: \(error)")
        }
    }
}
