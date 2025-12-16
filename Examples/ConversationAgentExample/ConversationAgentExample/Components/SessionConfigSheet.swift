import SwiftUI

struct SessionConfigSheet: View {
    @Binding var interactiveMode: Bool
    @Binding var outputType: AgentOutputType
    var isDisabled: Bool = false
    var onModeChange: () -> Void
    var onClearSession: () -> Void
    var onDismiss: () -> Void

    @State private var showInteractiveModeConfirm = false
    @State private var showClearConfirm = false
    @State private var pendingInteractiveMode = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("インタラクティブモード")
                            Text(interactiveMode ? "AIが不明点を質問します" : "AIが自動で最後まで実行します")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { interactiveMode },
                            set: { newValue in
                                pendingInteractiveMode = newValue
                                showInteractiveModeConfirm = true
                            }
                        ))
                        .labelsHidden()
                        .disabled(isDisabled)
                    }
                } header: {
                    Label("動作モード", systemImage: "person.2")
                } footer: {
                    Text("モードを変更するとセッションがクリアされます")
                }

                Section {
                    ForEach(AgentOutputType.allCases) { type in
                        Button {
                            outputType = type
                        } label: {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundStyle(type.tintColor)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(type.displayName)
                                        .foregroundStyle(.primary)
                                    Text(type.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if outputType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .disabled(isDisabled)
                    }
                } header: {
                    Label("出力タイプ", systemImage: "doc.text")
                } footer: {
                    Text("次の実行時に使用する出力形式を選択します")
                }

                Section {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("セッションをクリア")
                        }
                    }
                    .disabled(isDisabled)
                } footer: {
                    Text("会話履歴がすべて削除されます")
                }
            }
            .navigationTitle("セッション設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了", action: onDismiss)
                }
            }
            .confirmationDialog(
                "モードを変更",
                isPresented: $showInteractiveModeConfirm,
                titleVisibility: .visible
            ) {
                Button("変更する", role: .destructive) {
                    interactiveMode = pendingInteractiveMode
                    onModeChange()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("モードを変更すると現在の会話履歴がクリアされます。")
            }
            .confirmationDialog(
                "セッションをクリア",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("クリア", role: .destructive) {
                    onClearSession()
                    onDismiss()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("現在の会話履歴がすべて削除されます。この操作は取り消せません。")
            }
        }
    }
}

#Preview {
    @Previewable @State var interactive = true
    @Previewable @State var outputType = AgentOutputType.research

    SessionConfigSheet(
        interactiveMode: $interactive,
        outputType: $outputType,
        onModeChange: {},
        onClearSession: {},
        onDismiss: {}
    )
}
