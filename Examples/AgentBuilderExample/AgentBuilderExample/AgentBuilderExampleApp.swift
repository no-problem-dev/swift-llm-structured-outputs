import SwiftUI
import ExamplesCommon

@main
struct AgentBuilderExampleApp: App {
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
                    // 保存された型定義を読み込み
                    loadBuiltTypes()
                }
        }
    }

    private func loadBuiltTypes() {
        do {
            let types = try dependencies.builtType.loadAll()
            appState.setBuiltTypes(types)
        } catch {
            print("Failed to load built types: \(error)")
        }
    }
}
