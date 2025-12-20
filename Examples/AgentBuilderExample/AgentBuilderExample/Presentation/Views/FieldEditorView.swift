import SwiftUI
import ExamplesCommon

/// フィールド編集画面
struct FieldEditorView: View {
    @State private var field: Field
    @State private var enumValuesText: String = ""
    let onSave: (Field) -> Void

    init(field: Field, onSave: @escaping (Field) -> Void) {
        self._field = State(initialValue: field)
        self.onSave = onSave
        if case .stringEnum(let values) = field.type {
            self._enumValuesText = State(initialValue: values.joined(separator: "\n"))
        }
    }

    var body: some View {
        Form {
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

            Section("型") {
                Picker("型", selection: Binding(
                    get: { fieldTypeSelection },
                    set: { updateFieldType($0) }
                )) {
                    ForEach(FieldTypeSelection.allCases, id: \.self) { selection in
                        Label(selection.displayName, systemImage: selection.icon)
                            .tag(selection)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            if case .stringEnum = field.type {
                Section {
                    TextEditor(text: $enumValuesText)
                        .frame(minHeight: 100)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: enumValuesText) { _, newValue in
                            let values = newValue
                                .split(separator: "\n")
                                .map { String($0).trimmingCharacters(in: .whitespaces) }
                                .filter { !$0.isEmpty }
                            field.type = .stringEnum(values)
                        }
                } header: {
                    Text("列挙値（1行に1つ）")
                } footer: {
                    Text("例:\nactive\ninactive\npending")
                        .font(.caption)
                }
            }

            constraintsSection
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("フィールド編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { onSave(field) }
                    .disabled(field.name.isEmpty)
            }
        }
    }

    @ViewBuilder
    private var constraintsSection: some View {
        switch field.type {
        case .string:
            Section("制約（オプション）") {
                OptionalIntField(title: "最小文字数", value: $field.constraints.minLength)
                OptionalIntField(title: "最大文字数", value: $field.constraints.maxLength)
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
                OptionalDoubleField(title: "最小値", value: $field.constraints.minimum)
                OptionalDoubleField(title: "最大値", value: $field.constraints.maximum)
            }
        case .stringArray, .integerArray:
            Section("制約（オプション）") {
                OptionalIntField(title: "最小要素数", value: $field.constraints.minItems)
                OptionalIntField(title: "最大要素数", value: $field.constraints.maxItems)
            }
        default:
            EmptyView()
        }
    }

    private enum FieldTypeSelection: CaseIterable {
        case string, integer, number, boolean, stringEnum, stringArray, integerArray

        var displayName: String {
            switch self {
            case .string: "文字列"
            case .integer: "整数"
            case .number: "数値"
            case .boolean: "真偽値"
            case .stringEnum: "列挙型"
            case .stringArray: "文字列配列"
            case .integerArray: "整数配列"
            }
        }

        var icon: String {
            switch self {
            case .string: "textformat"
            case .integer: "number"
            case .number: "function"
            case .boolean: "checkmark.circle"
            case .stringEnum: "list.bullet"
            case .stringArray: "square.stack"
            case .integerArray: "square.stack.fill"
            }
        }
    }

    private var fieldTypeSelection: FieldTypeSelection {
        switch field.type {
        case .string: .string
        case .integer: .integer
        case .number: .number
        case .boolean: .boolean
        case .stringEnum: .stringEnum
        case .stringArray: .stringArray
        case .integerArray: .integerArray
        }
    }

    private func updateFieldType(_ selection: FieldTypeSelection) {
        switch selection {
        case .string: field.type = .string
        case .integer: field.type = .integer
        case .number: field.type = .number
        case .boolean: field.type = .boolean
        case .stringEnum:
            if case .stringEnum(let values) = field.type {
                field.type = .stringEnum(values)
            } else {
                field.type = .stringEnum([])
                enumValuesText = ""
            }
        case .stringArray: field.type = .stringArray
        case .integerArray: field.type = .integerArray
        }
        field.constraints = FieldConstraints()
    }
}
