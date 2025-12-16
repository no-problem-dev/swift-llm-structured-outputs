import SwiftUI

/// セッション一覧ビュー
struct SessionListView: View {
    @Bindable var viewModel: SessionListViewModel
    @Binding var selectedSession: SessionData?
    let onNewSession: () -> Void

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.sessions.isEmpty {
                ProgressView("読み込み中...")
            } else if viewModel.sessions.isEmpty {
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
            await viewModel.loadSessions()
        }
        .refreshable {
            await viewModel.loadSessions()
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
            ForEach(viewModel.sessions) { session in
                SessionRowView(session: session)
                    .tag(session)
            }
            .onDelete { offsets in
                Task {
                    await viewModel.deleteSessions(at: offsets)
                }
            }
        }
        .listStyle(.insetGrouped)
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
    @Previewable @State var viewModel = SessionListViewModel()
    @Previewable @State var selectedSession: SessionData?

    NavigationStack {
        SessionListView(
            viewModel: viewModel,
            selectedSession: $selectedSession,
            onNewSession: {}
        )
    }
}
