import SwiftUI
import LLMClient
import UIRouting

/// エージェント編集画面
struct AgentEditorView: View {
    @Bindable var editorState: AgentEditorState
    let isNew: Bool
    let onSave: (Agent) -> Void

    @Environment(.sheet(AppSheet.self)) private var sheetPresenter

    private var agent: Agent {
        editorState.agent ?? Agent(
            name: "",
            outputSchema: OutputSchema(name: "Output", description: nil, fields: [])
        )
    }

    var body: some View {
        List {
            basicInfoSection
            outputSchemaSection
            fieldsSection
            promptSection
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(isNew ? "新規エージェント" : "編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    if let agent = editorState.agent {
                        onSave(agent)
                    }
                }
                .disabled(editorState.agent?.name.isEmpty ?? true)
            }
        }
        .environment(\.editMode, .constant(.active))
    }

    @ViewBuilder
    private var basicInfoSection: some View {
        Section("基本情報") {
            TextField("名前", text: Binding(
                get: { editorState.agent?.name ?? "" },
                set: { editorState.agent?.name = $0 }
            ))

            TextField("説明（オプション）", text: Binding(
                get: { editorState.agent?.description ?? "" },
                set: { editorState.agent?.description = $0.isEmpty ? nil : $0 }
            ), axis: .vertical)
            .lineLimit(2...4)
        }
    }

    @ViewBuilder
    private var outputSchemaSection: some View {
        Section {
            TextField("スキーマ名", text: Binding(
                get: { editorState.agent?.outputSchema.name ?? "" },
                set: { editorState.agent?.outputSchema.name = $0 }
            ))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            TextField("説明（オプション）", text: Binding(
                get: { editorState.agent?.outputSchema.description ?? "" },
                set: { editorState.agent?.outputSchema.description = $0.isEmpty ? nil : $0 }
            ))
        } header: {
            Text("出力スキーマ")
        }
    }

    @ViewBuilder
    private var fieldsSection: some View {
        Section {
            if agent.outputSchema.fields.isEmpty {
                Text("フィールドがありません")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(agent.outputSchema.fields.indices, id: \.self) { index in
                    let field = agent.outputSchema.fields[index]
                    Button {
                        sheetPresenter.present(.fieldEdit(index: index))
                    } label: {
                        HStack {
                            Label(field.name, systemImage: field.type.icon)
                                .foregroundStyle(.primary)
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
                .onDelete { indexSet in
                    for index in indexSet { editorState.deleteField(at: index) }
                }
                .onMove { source, destination in
                    editorState.moveFields(from: source, to: destination)
                }
            }
        } header: {
            HStack {
                Text("フィールド")
                Spacer()
                Button {
                    sheetPresenter.present(.fieldNew)
                } label: {
                    Label("追加", systemImage: "plus")
                        .font(.subheadline)
                }
            }
        }
    }

    @ViewBuilder
    private var promptSection: some View {
        Section {
            if agent.systemPrompt.isEmpty {
                Text("デフォルトプロンプトを使用")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(agent.systemPrompt.components.indices, id: \.self) { index in
                    let component = agent.systemPrompt.components[index]
                    Button {
                        sheetPresenter.present(.promptEdit(index: index))
                    } label: {
                        PromptRow(component: component)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet { editorState.deletePromptItem(at: index) }
                }
                .onMove { source, destination in
                    editorState.movePromptItems(from: source, to: destination)
                }
            }
        } header: {
            HStack {
                Text("プロンプト構成")
                Spacer()
                Menu {
                    ForEach(PromptItem.Kind.allCases, id: \.self) { kind in
                        Button {
                            sheetPresenter.present(.promptNew(type: kind))
                        } label: {
                            Label(kind.displayName, systemImage: kind.icon)
                        }
                    }
                } label: {
                    Label("追加", systemImage: "plus")
                        .font(.subheadline)
                }
            }
        }
    }
}

// MARK: - PromptRow

struct PromptRow: View {
    let component: PromptComponent

    private var item: PromptItem { PromptItem(from: component) }

    var body: some View {
        HStack {
            Image(systemName: item.kind.icon)
                .foregroundStyle(item.kind.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.kind.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(component.contentPreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
