import SwiftUI
import ExamplesCommon

@main
struct AgentBuilderExampleApp: App {
    @State private var appState = AppState()
    private let dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(\.useCase, dependencies)
                .onAppear {
                    dependencies.apiKey.syncFromEnvironment()
                    appState.syncKeyStatuses(from: dependencies.apiKey)
                    loadOutputSchemas()
                }
        }
    }

    private func loadOutputSchemas() {
        do {
            let schemas = try dependencies.outputSchema.loadAll()
            appState.setOutputSchemas(schemas)
        } catch {
            print("Failed to load output schemas: \(error)")
        }
    }
}
