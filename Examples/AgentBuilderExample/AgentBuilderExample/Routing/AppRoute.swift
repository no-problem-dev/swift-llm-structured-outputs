import SwiftUI
import UIRouting

/// NavigationStack遷移先
enum AppRoute: Routable {
    case agentDetail(Agent)
    case agentEditor
    case chat(session: Session, agent: Agent)

    @ViewBuilder
    var body: some View {
        switch self {
        case .agentDetail(let agent):
            AgentDetailRouteView(agent: agent)
        case .agentEditor:
            AgentEditorRouteView()
        case .chat(let session, let agent):
            ChatView(session: session, agent: agent)
        }
    }
}
