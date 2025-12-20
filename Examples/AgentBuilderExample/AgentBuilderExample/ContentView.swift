import SwiftUI
import ExamplesCommon

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.useCase) private var useCase
    @State private var showSettings = false
    @State private var editingType: BuiltType?
    @State private var isNewType = false
    @State private var conversationType: BuiltType?

    var body: some View {
        NavigationStack {
            List {
                // 型定義セクション
                Section {
                    if appState.builtTypes.isEmpty {
                        ContentUnavailableView(
                            "型定義がありません",
                            systemImage: "doc.badge.plus",
                            description: Text("「新規作成」ボタンをタップして\n最初の型定義を作成してください")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(appState.builtTypes) { type in
                            BuiltTypeRow(
                                type: type,
                                onRun: { conversationType = type },
                                onEdit: {
                                    isNewType = false
                                    editingType = type
                                }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteType(type)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("型定義")
                        Spacer()
                        Button {
                            createNewType()
                        } label: {
                            Label("新規作成", systemImage: "plus")
                                .font(.subheadline)
                        }
                    }
                }

                // API Key ステータス
                Section("ステータス") {
                    APIKeyStatusRow(
                        provider: .anthropic,
                        hasKey: appState.hasAnthropicKey
                    )
                    APIKeyStatusRow(
                        provider: .openai,
                        hasKey: appState.hasOpenAIKey
                    )
                    APIKeyStatusRow(
                        provider: .gemini,
                        hasKey: appState.hasGeminiKey
                    )
                }
            }
            .navigationTitle("Agent Builder")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(item: $editingType) { type in
                TypeEditorView(type: type, isNew: isNewType) { savedType in
                    updateType(savedType)
                }
            }
            .sheet(item: $conversationType) { type in
                ConversationView(builtType: type)
            }
        }
    }

    // MARK: - Actions

    private func createNewType() {
        let newType = useCase.builtType.create(
            name: "NewType",
            description: nil
        )
        isNewType = true
        editingType = newType
    }

    private func updateType(_ type: BuiltType) {
        do {
            try useCase.builtType.save(type)
            if appState.builtTypes.contains(where: { $0.id == type.id }) {
                appState.updateBuiltType(type)
            } else {
                appState.addBuiltType(type)
            }
        } catch {
            print("Failed to save type: \(error)")
        }
        editingType = nil
    }

    private func deleteType(_ type: BuiltType) {
        do {
            try useCase.builtType.delete(id: type.id)
            appState.deleteBuiltType(id: type.id)
        } catch {
            print("Failed to delete type: \(error)")
        }
    }
}

// MARK: - BuiltTypeRow

struct BuiltTypeRow: View {
    let type: BuiltType
    let onRun: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ヘッダー
            HStack {
                Text(type.name)
                    .font(.headline)

                Spacer()

                Text("\(type.fields.count) fields")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let description = type.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // フィールドプレビュー
            if !type.fields.isEmpty {
                HStack(spacing: 8) {
                    ForEach(type.fields.prefix(3)) { field in
                        Label(field.name, systemImage: field.fieldType.iconName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.fill.tertiary)
                            .clipShape(Capsule())
                    }
                    if type.fields.count > 3 {
                        Text("+\(type.fields.count - 3)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // アクションボタン
            HStack(spacing: 12) {
                Button {
                    onRun()
                } label: {
                    Label("会話で生成", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button {
                    onEdit()
                } label: {
                    Label("編集", systemImage: "pencil")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - APIKeyStatusRow

struct APIKeyStatusRow: View {
    let provider: LLMProvider
    let hasKey: Bool

    var body: some View {
        HStack {
            Text(provider.displayName)

            Spacer()

            if hasKey {
                Label("設定済み", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else {
                Label("未設定", systemImage: "xmark.circle")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
