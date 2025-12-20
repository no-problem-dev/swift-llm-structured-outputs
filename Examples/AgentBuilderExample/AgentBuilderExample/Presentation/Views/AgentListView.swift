import SwiftUI
import UIRouting

/// エージェント一覧画面
struct AgentListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.useCase) private var useCase
    @Environment(\.agentEditorState) private var editorState
    @Environment(.router(AppRoute.self)) private var router
    @Environment(.sheet(AppSheet.self)) private var sheetPresenter
    @Environment(.alert(AppAlert.self, context: .navigation)) private var alertPresenter

    var body: some View {
        List {
            agentSection
            recentSessionsSection
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Agent Builder")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    sheetPresenter.present(.settings)
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .task { loadInitialData() }
    }

    @ViewBuilder
    private var agentSection: some View {
        Section {
            if appState.agents.isEmpty {
                ContentUnavailableView(
                    "エージェントがありません",
                    systemImage: "cpu",
                    description: Text("「新規作成」ボタンをタップして\n最初のエージェントを作成してください")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(appState.agents) { agent in
                    Button {
                        router.navigate(to: .agentDetail(agent))
                    } label: {
                        AgentRow(agent: agent)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            alertPresenter.present(.deleteAgent(name: agent.name) {
                                deleteAgent(agent)
                            })
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
        } header: {
            HStack {
                Text("エージェント")
                Spacer()
                Button {
                    createNewAgent()
                } label: {
                    Label("新規作成", systemImage: "plus")
                        .font(.subheadline)
                }
            }
        }
    }

    @ViewBuilder
    private var recentSessionsSection: some View {
        if !appState.recentSessions.isEmpty {
            Section("最近のセッション") {
                ForEach(appState.recentSessions) { session in
                    if let agent = appState.agents.first(where: { $0.id == session.agentId }) {
                        Button {
                            router.navigate(to: .chat(session: session, agent: agent))
                        } label: {
                            SessionRow(session: session, agentName: agent.name)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                alertPresenter.present(.deleteSession(name: session.name) {
                                    deleteSession(session)
                                })
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
            }
        }
    }

    private func loadInitialData() {
        do {
            appState.setAgents(try useCase.agent.fetchAll())
            appState.setSessions(try useCase.session.fetchAll())
        } catch {
            print("Failed to load data: \(error)")
        }
    }

    private func createNewAgent() {
        let newAgent = useCase.agent.create(name: "新しいエージェント", description: nil)
        editorState?.startEditing(newAgent, isNew: true)
        router.navigate(to: .agentEditor)
    }

    private func deleteAgent(_ agent: Agent) {
        do {
            try useCase.session.deleteByAgent(id: agent.id)
            try useCase.agent.delete(id: agent.id)
            appState.deleteAgent(id: agent.id)
        } catch {
            print("Failed to delete agent: \(error)")
        }
    }

    private func deleteSession(_ session: Session) {
        do {
            try useCase.session.delete(id: session.id)
            appState.deleteSession(id: session.id)
        } catch {
            print("Failed to delete session: \(error)")
        }
    }
}

// MARK: - AgentRow

struct AgentRow: View {
    let agent: Agent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(agent.name)
                    .font(.headline)
                Spacer()
                HStack(spacing: 8) {
                    Label("\(agent.fieldCount)", systemImage: "list.bullet")
                    if agent.toolCount > 0 {
                        Label("\(agent.toolCount)", systemImage: "wrench")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let description = agent.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !agent.outputSchema.fields.isEmpty {
                HStack(spacing: 6) {
                    ForEach(agent.outputSchema.fields.prefix(4)) { field in
                        Text(field.name)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.fill.tertiary)
                            .clipShape(Capsule())
                    }
                    if agent.outputSchema.fields.count > 4 {
                        Text("+\(agent.outputSchema.fields.count - 4)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - SessionRow

struct SessionRow: View {
    let session: Session
    let agentName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Label(session.status.displayName, systemImage: session.status.icon)
                    .font(.caption)
                    .foregroundStyle(session.status == .active ? .green : .secondary)
            }
            HStack {
                Label(agentName, systemImage: "cpu")
                Spacer()
                Text("\(session.turnCount) turns")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
