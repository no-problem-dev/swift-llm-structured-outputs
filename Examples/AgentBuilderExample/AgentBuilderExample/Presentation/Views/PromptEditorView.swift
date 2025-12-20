import SwiftUI

/// プロンプト編集画面
struct PromptEditorView: View {
    @State private var item: PromptItem
    let onSave: (PromptItem) -> Void

    init(item: PromptItem, onSave: @escaping (PromptItem) -> Void) {
        self._item = State(initialValue: item)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("タイプ") {
                Picker("タイプ", selection: $item.kind) {
                    ForEach(PromptItem.Kind.allCases, id: \.self) { kind in
                        Label(kind.displayName, systemImage: kind.icon)
                            .tag(kind)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            Section {
                if item.kind == .example {
                    TextField("入力例", text: $item.value, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("出力例", text: Binding(
                        get: { item.exampleOutput ?? "" },
                        set: { item.exampleOutput = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                } else {
                    TextEditor(text: $item.value)
                        .frame(minHeight: 100)
                }
            } header: {
                Text("内容")
            } footer: {
                Text(item.kind.hint)
                    .font(.caption)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(item.kind.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { onSave(item) }
                    .disabled(item.value.isEmpty)
            }
        }
    }
}
