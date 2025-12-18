import SwiftUI

struct SessionListView: View {
    @Bindable var state: SessionListState
    @Binding var selectedSession: SessionData?
    let onNewSession: () -> Void

    @Environment(\.useCase) private var useCase

    var body: some View {
        Group {
            if state.isLoading && state.sessions.isEmpty {
                ProgressView("読み込み中...")
            } else if state.sessions.isEmpty {
                emptyStateView
            } else {
                sessionListContent
            }
        }
        .navigationTitle("セッション")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    onNewSession()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await loadSessions()
        }
        .refreshable {
            await loadSessions()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("セッションがありません", systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text("新しいセッションを作成して会話を始めましょう")
        } actions: {
            Button("新規セッション") {
                onNewSession()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Session List

    private var sessionListContent: some View {
        List(selection: $selectedSession) {
            ForEach(state.sessions) { session in
                SessionRowView(session: session)
                    .tag(session)
            }
            .onDelete { offsets in
                Task {
                    await deleteSessions(at: offsets)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

    private func loadSessions() async {
        state.setLoading(true)
        state.setError(nil)

        do {
            let sessions = try await useCase.session.listSessions()
            state.setSessions(sessions)
        } catch {
            state.setError(error.localizedDescription)
        }

        state.setLoading(false)
    }

    private func deleteSessions(at offsets: IndexSet) async {
        let idsToDelete = offsets.map { state.sessions[$0].id }
        for id in idsToDelete {
            do {
                try await useCase.session.deleteSession(id: id)
                state.removeSession(id: id)
            } catch {
                state.setError(error.localizedDescription)
            }
        }
    }
}

// MARK: - Session Row

struct SessionRowView: View {
    let session: SessionData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: session.outputType.icon)
                    .foregroundStyle(session.outputType.tintColor)

                Text(session.title)
                    .font(.headline)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Label(session.outputType.displayName, systemImage: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("•")
                    .foregroundStyle(.tertiary)

                Text(session.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - SessionData Hashable

extension SessionData: Hashable {
    static func == (lhs: SessionData, rhs: SessionData) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    @Previewable @State var state = SessionListState()
    @Previewable @State var selectedSession: SessionData?

    NavigationStack {
        SessionListView(
            state: state,
            selectedSession: $selectedSession,
            onNewSession: {}
        )
    }
}
