import SwiftUI

struct SessionListView: View {
    @Bindable var state: SessionListState
    @Binding var selectedSession: SessionData?
    let onNewSession: () -> Void
    let onDeleteSession: (SessionData) -> Void

    @Environment(\.useCase) private var useCase

    @State private var showDeleteConfirmation = false
    @State private var sessionToDelete: SessionData?
    @State private var showRenameDialog = false
    @State private var sessionToRename: SessionData?
    @State private var newSessionTitle = ""

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
        .alert("セッションを削除しますか？", isPresented: $showDeleteConfirmation) {
            Button("キャンセル", role: .cancel) {
                sessionToDelete = nil
            }
            Button("削除", role: .destructive) {
                if let session = sessionToDelete {
                    Task {
                        await deleteSession(session)
                    }
                }
                sessionToDelete = nil
            }
        } message: {
            if let session = sessionToDelete {
                Text("「\(session.title)」を削除します。この操作は取り消せません。")
            }
        }
        .alert("セッション名を変更", isPresented: $showRenameDialog) {
            TextField("セッション名", text: $newSessionTitle)
            Button("キャンセル", role: .cancel) {
                sessionToRename = nil
                newSessionTitle = ""
            }
            Button("変更") {
                if let session = sessionToRename, !newSessionTitle.isEmpty {
                    Task {
                        await renameSession(session, newTitle: newSessionTitle)
                    }
                }
                sessionToRename = nil
                newSessionTitle = ""
            }
        } message: {
            Text("新しいセッション名を入力してください")
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
                    .contextMenu {
                        Button {
                            sessionToRename = session
                            newSessionTitle = session.title
                            showRenameDialog = true
                        } label: {
                            Label("名前を変更", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            sessionToDelete = session
                            showDeleteConfirmation = true
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
            }
            .onDelete { offsets in
                // 確認ダイアログを表示するため、最初のセッションのみを対象にする
                if let index = offsets.first {
                    sessionToDelete = state.sessions[index]
                    showDeleteConfirmation = true
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

    private func deleteSession(_ session: SessionData) async {
        do {
            try await useCase.session.deleteSession(id: session.id)
            state.removeSession(id: session.id)
            // コールバックを呼び出してアクティブセッションの処理を委譲
            onDeleteSession(session)
        } catch {
            state.setError(error.localizedDescription)
        }
    }

    private func renameSession(_ session: SessionData, newTitle: String) async {
        do {
            try await useCase.session.renameSession(id: session.id, newTitle: newTitle)
            // セッション一覧を再読み込み
            await loadSessions()
        } catch {
            state.setError(error.localizedDescription)
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
            onNewSession: {},
            onDeleteSession: { _ in }
        )
    }
}
