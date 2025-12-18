import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.useCase) private var useCase
    @State private var sessionListState = SessionListState()
    @State private var selectedSession: SessionData?
    @State private var conversationState: ConversationState?
    @State private var navigationPath = NavigationPath()
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            SessionListView(
                state: sessionListState,
                selectedSession: $selectedSession,
                onNewSession: createNewSession
            )
            .navigationDestination(for: SessionData.self) { session in
                if let state = conversationState, state.sessionData.id == session.id {
                    ConversationView()
                        .environment(state)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .onChange(of: selectedSession) { _, newSession in
            if let session = newSession {
                openSession(session)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView {
                showSettings = false
            }
        }
    }

    // MARK: - Actions

    private func createNewSession() {
        let newSession = useCase.session.createNewSession(
            provider: appState.selectedProvider,
            outputType: .research,
            interactiveMode: true
        )
        openSession(newSession)
    }

    private func openSession(_ session: SessionData) {
        conversationState = ConversationState(sessionData: session)
        navigationPath.append(session)
        selectedSession = nil
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
