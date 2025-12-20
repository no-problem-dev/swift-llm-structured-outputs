import SwiftUI
import ExamplesCommon

struct FieldEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var field: BuiltField
    @State private var enumValuesText: String = ""

    let onSave: (BuiltField) -> Void

    init(field: BuiltField, onSave: @escaping (BuiltField) -> Void) {
        self._field = State(initialValue: field)
        self.onSave = onSave

        // 列挙型の場合、初期値を設定
        if case .stringEnum(let values) = field.fieldType {
            self._enumValuesText = State(initialValue: values.joined(separator: "\n"))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // 基本情報
                Section("基本情報") {
                    TextField("フィールド名", text: $field.name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("説明（オプション）", text: Binding(
                        get: { field.description ?? "" },
                        set: { field.description = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(2...4)

                    Toggle("必須フィールド", isOn: $field.isRequired)
                }

                // 型選択
                Section("型") {
                    Picker("型", selection: Binding(
                        get: { fieldTypeSelection },
                        set: { updateFieldType($0) }
                    )) {
                        ForEach(FieldTypeSelection.allCases, id: \.self) { selection in
                            Label(selection.displayName, systemImage: selection.iconName)
                                .tag(selection)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // 列挙型の値入力
                if case .stringEnum = field.fieldType {
                    Section {
                        TextEditor(text: $enumValuesText)
                            .frame(minHeight: 100)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: enumValuesText) { _, newValue in
                                let values = newValue
                                    .split(separator: "\n")
                                    .map { String($0).trimmingCharacters(in: .whitespaces) }
                                    .filter { !$0.isEmpty }
                                field.fieldType = .stringEnum(values)
                            }
                    } header: {
                        Text("列挙値（1行に1つ）")
                    } footer: {
                        Text("例:\nactive\ninactive\npending")
                            .font(.caption)
                    }
                }

                // 制約設定
                constraintsSection
            }
            .navigationTitle("フィールド編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveAndDismiss()
                    }
                    .disabled(field.name.isEmpty)
                }
            }
        }
    }

    // MARK: - Constraints Section

    @ViewBuilder
    private var constraintsSection: some View {
        switch field.fieldType {
        case .string:
            Section("制約（オプション）") {
                OptionalIntField(
                    title: "最小文字数",
                    value: $field.constraints.minLength
                )

                OptionalIntField(
                    title: "最大文字数",
                    value: $field.constraints.maxLength
                )

                TextField("パターン（正規表現）", text: Binding(
                    get: { field.constraints.pattern ?? "" },
                    set: { field.constraints.pattern = $0.isEmpty ? nil : $0 }
                ))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Picker("フォーマット", selection: Binding(
                    get: { field.constraints.format ?? "" },
                    set: { field.constraints.format = $0.isEmpty ? nil : $0 }
                )) {
                    Text("なし").tag("")
                    Text("email").tag("email")
                    Text("uri").tag("uri")
                    Text("date").tag("date")
                    Text("date-time").tag("date-time")
                }
            }

        case .integer, .number:
            Section("制約（オプション）") {
                OptionalDoubleField(
                    title: "最小値",
                    value: $field.constraints.minimum
                )

                OptionalDoubleField(
                    title: "最大値",
                    value: $field.constraints.maximum
                )
            }

        case .stringArray, .integerArray:
            Section("制約（オプション）") {
                OptionalIntField(
                    title: "最小要素数",
                    value: $field.constraints.minItems
                )

                OptionalIntField(
                    title: "最大要素数",
                    value: $field.constraints.maxItems
                )
            }

        default:
            EmptyView()
        }
    }

    // MARK: - Field Type Selection

    private enum FieldTypeSelection: CaseIterable {
        case string, integer, number, boolean, stringEnum, stringArray, integerArray

        var displayName: String {
            switch self {
            case .string: return "文字列"
            case .integer: return "整数"
            case .number: return "数値"
            case .boolean: return "真偽値"
            case .stringEnum: return "列挙型"
            case .stringArray: return "文字列配列"
            case .integerArray: return "整数配列"
            }
        }

        var iconName: String {
            switch self {
            case .string: return "textformat"
            case .integer: return "number"
            case .number: return "function"
            case .boolean: return "checkmark.circle"
            case .stringEnum: return "list.bullet"
            case .stringArray: return "square.stack"
            case .integerArray: return "square.stack.fill"
            }
        }
    }

    private var fieldTypeSelection: FieldTypeSelection {
        switch field.fieldType {
        case .string: return .string
        case .integer: return .integer
        case .number: return .number
        case .boolean: return .boolean
        case .stringEnum: return .stringEnum
        case .stringArray: return .stringArray
        case .integerArray: return .integerArray
        }
    }

    private func updateFieldType(_ selection: FieldTypeSelection) {
        switch selection {
        case .string:
            field.fieldType = .string
        case .integer:
            field.fieldType = .integer
        case .number:
            field.fieldType = .number
        case .boolean:
            field.fieldType = .boolean
        case .stringEnum:
            // 既存の列挙値を保持
            if case .stringEnum(let values) = field.fieldType {
                field.fieldType = .stringEnum(values)
            } else {
                field.fieldType = .stringEnum([])
                enumValuesText = ""
            }
        case .stringArray:
            field.fieldType = .stringArray
        case .integerArray:
            field.fieldType = .integerArray
        }

        // 制約をリセット
        field.constraints = FieldConstraints()
    }

    private func saveAndDismiss() {
        onSave(field)
        dismiss()
    }
}

#Preview {
    FieldEditorView(
        field: BuiltField(
            name: "name",
            fieldType: .string,
            description: "ユーザー名"
        )
    ) { _ in }
}
