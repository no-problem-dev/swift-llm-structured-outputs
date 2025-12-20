import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(ActiveSessionState.self) private var activeSessionState
    @Environment(\.useCase) private var useCase
    @State private var sessionListState = SessionListState()
    @State private var selectedSession: SessionData?
    @State private var navigationPath = NavigationPath()
    @State private var showSettings = false
    @State private var showSwitchSessionAlert = false
    @State private var pendingSession: SessionData?

    /// アクティブセッションバーを表示するかどうか
    private var shouldShowActiveSessionBar: Bool {
        // ConversationView表示中は非表示（重複を避ける）
        guard navigationPath.isEmpty else { return false }
        // 会話履歴がある、または実行中の場合に表示
        // （新規セッションで何も実行していない場合は表示しない）
        return activeSessionState.hasConversationHistory ||
               activeSessionState.executionState.isRunning
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack(path: $navigationPath) {
                SessionListView(
                    state: sessionListState,
                    selectedSession: $selectedSession,
                    onNewSession: createNewSession,
                    onDeleteSession: handleDeletedSession
                )
                .navigationDestination(for: SessionData.self) { session in
                    // ActiveSessionStateのsessionDataがこのセッションと一致する場合のみ表示
                    if activeSessionState.sessionData.id == session.id {
                        ConversationView()
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

            // フローティングのアクティブセッションバー
            if shouldShowActiveSessionBar {
                ActiveSessionBar {
                    navigateToActiveSession()
                }
                .animation(.spring(duration: 0.3), value: shouldShowActiveSessionBar)
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
        .alert("セッションを切り替えますか？", isPresented: $showSwitchSessionAlert) {
            Button("キャンセル", role: .cancel) {
                pendingSession = nil
                selectedSession = nil
            }
            Button("切り替える", role: .destructive) {
                if let session = pendingSession {
                    forceOpenSession(session)
                }
                pendingSession = nil
            }
        } message: {
            Text("現在実行中のセッションがあります。切り替えると実行が停止されます。")
        }
    }

    // MARK: - Actions

    private func createNewSession() {
        let newSession = useCase.session.createNewSession(
            provider: appState.selectedProvider,
            outputType: .research,
            interactiveMode: true
        )
        openNewSession(newSession)
    }

    /// 新規セッションを開く（既存セッションを完全リセット）
    private func openNewSession(_ session: SessionData) {
        // 実行中の場合は確認ダイアログを表示
        if activeSessionState.isExecuting {
            pendingSession = session
            showSwitchSessionAlert = true
            return
        }

        forceOpenNewSession(session)
    }

    /// 既存セッションを開く（履歴から選択時）
    private func openSession(_ session: SessionData) {
        // 同じセッションならそのまま開く
        guard activeSessionState.sessionData.id != session.id else {
            activeSessionState.setSessionData(session)
            navigationPath.append(session)
            selectedSession = nil
            return
        }

        // 実行中の場合は確認ダイアログを表示
        if activeSessionState.isExecuting {
            pendingSession = session
            showSwitchSessionAlert = true
            return
        }

        forceOpenSession(session)
    }

    /// 確認なしで新規セッションを開く
    private func forceOpenNewSession(_ session: SessionData) {
        activeSessionState.resetAll()
        activeSessionState.setSessionData(session)
        navigationPath.append(session)
        selectedSession = nil
    }

    /// 確認なしで既存セッションを開く
    private func forceOpenSession(_ session: SessionData) {
        activeSessionState.resetAll()
        activeSessionState.setSessionData(session)
        navigationPath.append(session)
        selectedSession = nil
    }

    /// アクティブセッションに遷移
    private func navigateToActiveSession() {
        // 既にアクティブなセッションのデータを使って遷移
        navigationPath.append(activeSessionState.sessionData)
    }

    private func handleDeletedSession(_ deletedSession: SessionData) {
        if activeSessionState.sessionData.id == deletedSession.id {
            if activeSessionState.isExecuting, let session = activeSessionState.session {
                Task {
                    await useCase.execution.stop(session: session)
                }
            }
            activeSessionState.resetAll()
            navigationPath = NavigationPath()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environment(ActiveSessionState())
}
