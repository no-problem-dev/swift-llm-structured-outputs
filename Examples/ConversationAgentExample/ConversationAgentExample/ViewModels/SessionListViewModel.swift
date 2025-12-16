import Foundation

/// セッション一覧ViewModel
@Observable @MainActor
final class SessionListViewModel {
    private(set) var sessions: [SessionData] = []
    private(set) var isLoading = false
    private(set) var error: String?

    private let storage: SessionStorage

    init(storage: SessionStorage = JSONFileSessionStorage()) {
        self.storage = storage
    }

    /// セッション一覧を読み込み
    func loadSessions() async {
        isLoading = true
        error = nil

        do {
            sessions = try await storage.listSessions()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// 新規セッションを作成
    func createNewSession(
        outputType: AgentOutputType = .research,
        interactiveMode: Bool = true
    ) -> SessionData {
        SessionData(
            title: "新規セッション",
            outputType: outputType,
            interactiveMode: interactiveMode
        )
    }

    /// セッションを削除
    func deleteSession(id: UUID) async {
        do {
            try await storage.delete(id: id)
            sessions.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// セッションを削除（IndexSet から）
    func deleteSessions(at offsets: IndexSet) async {
        let idsToDelete = offsets.map { sessions[$0].id }
        for id in idsToDelete {
            await deleteSession(id: id)
        }
    }
}
