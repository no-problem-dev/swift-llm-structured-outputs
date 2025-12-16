import SwiftUI

/// メインコンテンツビュー
///
/// アプリのエントリーポイントとなるビューです。
/// セッション一覧、会話画面、設定画面をタブで切り替えます。
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var sessionListViewModel = SessionListViewModel()
    @State private var selectedSession: SessionData?
    @State private var conversationViewModel: ConversationViewModelImpl?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        TabView(selecti そしたら新規ブランチを立てて、一旦コミット・プッシュしてほしい。 on: $selectedTab) {
            NavigationStack(path: $navigationPath) {
                SessionListView(
                    viewModel: sessionListViewModel,
                    selectedSession: $selectedSession,
                    onNewSession: createNewSession
                )
                .navigationDestination(for: SessionData.self) { session in
                    if let viewModel = conversationViewModel, viewModel.sessionData.id == session.id {
                        ConversationView(viewModel: viewModel)
                    }
                }
            }
            .tabItem {
                Label("セッション", systemImage: "bubble.left.and.bubble.right.fill")
            }
            .tag(0)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("設定", systemImage: "gearshape.fill")
            }
            .tag(1)
        }
        .onAppear {
            // 環境変数からAPIキーを同期
            APIKeyManager.syncFromEnvironment()
        }
        .onChange(of: selectedSession) { _, newSession in
            if let session = newSession {
                openSession(session)
            }
        }
    }

    // MARK: - Actions

    private func createNewSession() {
        let newSession = sessionListViewModel.createNewSession()
        openSession(newSession)
    }

    private func openSession(_ session: SessionData) {
        conversationViewModel = ConversationViewModelImpl(sessionData: session)
        navigationPath.append(session)
        selectedSession = nil
    }
}

#Preview {
    ContentView()
}
