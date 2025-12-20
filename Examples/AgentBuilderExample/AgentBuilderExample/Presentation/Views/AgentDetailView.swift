import SwiftUI
import LLMClient

/// エージェント詳細画面
struct AgentDetailView: View {
    let agent: Agent
    let onEdit: (Agent) -> Void
    let onStartSession: (Agent) -> Void

    var body: some View {
        List {
            Section("基本情報") {
                LabeledContent("名前", value: agent.name)
                if let desc = agent.description {
                    LabeledContent("説明", value: desc)
                }
            }

            Section("出力スキーマ: \(agent.outputSchema.name)") {
                if agent.outputSchema.fields.isEmpty {
                    Text("フィールドが定義されていません")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(agent.outputSchema.fields) { field in
                        HStack {
                            Label(field.name, systemImage: field.type.icon)
                            Spacer()
                            Text(field.type.displayName)
                                .foregroundStyle(.secondary)
                            if !field.isRequired {
                                Text("optional")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }

            Section("プロンプト構成") {
                if agent.systemPrompt.isEmpty {
                    Text("デフォルトプロンプトを使用")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(agent.systemPrompt.components.indices, id: \.self) { index in
                        let component = agent.systemPrompt.components[index]
                        VStack(alignment: .leading, spacing: 4) {
                            Text(component.tagName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text(component.contentPreview)
                                .font(.subheadline)
                                .lineLimit(2)
                        }
                    }
                }
            }

            if !agent.enabledToolNames.isEmpty {
                Section("有効なツール") {
                    ForEach(agent.enabledToolNames, id: \.self) { toolName in
                        Label(toolName, systemImage: "wrench")
                    }
                }
            }

            Section {
                Button {
                    onStartSession(agent)
                } label: {
                    Label("新しいセッションを開始", systemImage: "bubble.left.and.bubble.right.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(agent.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("編集") { onEdit(agent) }
            }
        }
    }
}
