import SwiftUI

/// セッション一覧画面の状態を保持
@MainActor @Observable
final class SessionListState {

    private(set) var sessions: [SessionData] = []
    private(set) var isLoading: Bool = false
    private(set) var error: String?

    // MARK: - Setters

    func setSessions(_ sessions: [SessionData]) {
        self.sessions = sessions
    }

    func setLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }

    func setError(_ error: String?) {
        self.error = error
    }

    func removeSession(id: UUID) {
        sessions.removeAll { $0.id == id }
    }

    func removeSessions(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
    }
}
