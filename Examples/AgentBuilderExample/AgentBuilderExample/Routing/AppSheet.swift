import SwiftUI
import UIRouting

/// Sheet表示
enum AppSheet: Sheetable {
    case settings
    case fieldNew
    case fieldEdit(index: Int)
    case promptNew(type: PromptItem.Kind)
    case promptEdit(index: Int)

    @ViewBuilder
    var body: some View {
        switch self {
        case .settings:
            SettingsView()
        case .fieldNew:
            FieldEditorSheetView(mode: .new)
        case .fieldEdit(let index):
            FieldEditorSheetView(mode: .edit(index: index))
        case .promptNew(let type):
            PromptEditorSheetView(mode: .new(type: type))
        case .promptEdit(let index):
            PromptEditorSheetView(mode: .edit(index: index))
        }
    }
}

// MARK: - Field Editor Sheet View

private struct FieldEditorSheetView: View {
    enum Mode: Hashable {
        case new
        case edit(index: Int)
    }

    let mode: Mode

    @Environment(\.agentEditorState) private var editorState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if let state = editorState {
                switch mode {
                case .new:
                    FieldEditorView(
                        field: state.newFieldTemplate,
                        onSave: { field in
                            state.addField(field)
                            dismiss()
                        }
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル") { dismiss() }
                        }
                    }
                case .edit(let index):
                    if let field = state.field(at: index) {
                        FieldEditorView(
                            field: field,
                            onSave: { updatedField in
                                state.updateField(updatedField, at: index)
                                dismiss()
                            }
                        )
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("キャンセル") { dismiss() }
                            }
                        }
                    } else {
                        ContentUnavailableView(
                            "フィールドが見つかりません",
                            systemImage: "exclamationmark.triangle"
                        )
                    }
                }
            } else {
                ContentUnavailableView(
                    "エディタの状態が見つかりません",
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
    }
}

// MARK: - Prompt Editor Sheet View

private struct PromptEditorSheetView: View {
    enum Mode: Hashable {
        case new(type: PromptItem.Kind)
        case edit(index: Int)
    }

    let mode: Mode

    @Environment(\.agentEditorState) private var editorState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if let state = editorState {
                switch mode {
                case .new(let type):
                    PromptEditorView(
                        item: PromptItem(kind: type, value: ""),
                        onSave: { item in
                            state.addPromptItem(item)
                            dismiss()
                        }
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル") { dismiss() }
                        }
                    }
                case .edit(let index):
                    if let item = state.promptItem(at: index) {
                        PromptEditorView(
                            item: item,
                            onSave: { updatedItem in
                                state.updatePromptItem(updatedItem, at: index)
                                dismiss()
                            }
                        )
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("キャンセル") { dismiss() }
                            }
                        }
                    } else {
                        ContentUnavailableView(
                            "プロンプトが見つかりません",
                            systemImage: "exclamationmark.triangle"
                        )
                    }
                }
            } else {
                ContentUnavailableView(
                    "エディタの状態が見つかりません",
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
    }
}
