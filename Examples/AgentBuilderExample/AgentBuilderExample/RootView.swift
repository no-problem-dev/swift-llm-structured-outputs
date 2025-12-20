import SwiftUI
import UIRouting

/// アプリのルートビュー（ルーティング設定）
struct RootView: View {
    @State private var router = Router<AppRoute>()
    @State private var sheetPresenter = SheetPresenter<AppSheet>()
    @State private var alertPresenterOnNavigation = AlertPresenter<AppAlert>()
    @State private var alertPresenterOnSheet = AlertPresenter<AppAlert>()
    @State private var editorState = AgentEditorState()

    var body: some View {
        AgentListView()
            .routingScope(for: AppRoute.self, alert: AppAlert.self)
            .routing(
                router: router,
                sheetPresenter: sheetPresenter,
                alertPresenterOnNavigation: alertPresenterOnNavigation,
                alertPresenterOnSheet: alertPresenterOnSheet
            )
            .sheet(item: $sheetPresenter.presentedSheet) { sheet in
                sheet.body
                    .environment(\.agentEditorState, editorState)
                    .sheetAlert(for: AppAlert.self)
            }
            .environment(\.agentEditorState, editorState)
    }
}
