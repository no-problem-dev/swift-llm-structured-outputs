import SwiftUI

@main
struct ConversationAgentExampleApp: App {
    @State private var appState = AppState()
    private let dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(\.useCase, dependencies)
                .onAppear {
                    // 環境変数から同期
                    dependencies.apiKey.syncFromEnvironment()
                    // 状態を更新
                    appState.syncKeyStatuses(from: dependencies.apiKey)
                }
        }
    }
}
