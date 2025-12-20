import SwiftUI
import LLMClient
import LLMDynamicStructured
import ExamplesCommon

// MARK: - FieldEditDestination

enum FieldEditDestination: Hashable {
    case new(BuiltField)
    case existing(BuiltField)

    var field: BuiltField {
        switch self {
        case .new(let field), .existing(let field):
            return field
        }
    }

    var isNew: Bool {
        switch self {
        case .new: return true
        case .existing: return false
        }
    }
}

// MARK: - FieldEditorNavigationView

/// NavigationStack内でFieldEditorを表示するためのラッパービュー
struct FieldEditorNavigationView: View {
    let destination: FieldEditDestination
    let onSave: (BuiltField) -> Void
    let onCancel: () -> Void

    @State private var field: BuiltField
    @State private var enumValuesText: String = ""

    init(destination: FieldEditDestination, onSave: @escaping (BuiltField) -> Void, onCancel: @escaping () -> Void) {
        self.destination = destination
        self.onSave = onSave
        self.onCancel = onCancel
        self._field = State(initialValue: destination.field)

        // 列挙型の場合、初期値を設定
        if case .stringEnum(let values) = destination.field.fieldType {
            self._enumValuesText = State(initialValue: values.joined(separator: "\n"))
        }
    }

    var body: some View {
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
        .navigationTitle(destination.isNew ? "フィールド追加" : "フィールド編集")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {
                    onCancel()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    onSave(field)
                }
                .disabled(field.name.isEmpty)
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
}

// MARK: - TypeEditorView

struct TypeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var type: BuiltType
    @State private var navigationPath = NavigationPath()

    let isNew: Bool
    let onSave: (BuiltType) -> Void

    init(type: BuiltType, isNew: Bool, onSave: @escaping (BuiltType) -> Void) {
        self._type = State(initialValue: type)
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Form {
                // 基本情報
                Section("基本情報") {
                    TextField("型名", text: $type.name)

                    TextField("説明（オプション）", text: Binding(
                        get: { type.description ?? "" },
                        set: { type.description = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(2...4)
                }

                // フィールド一覧
                Section {
                    if type.fields.isEmpty {
                        ContentUnavailableView(
                            "フィールドがありません",
                            systemImage: "square.stack.3d.up.slash",
                            description: Text("「フィールド追加」をタップして\nフィールドを追加してください")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(type.fields) { field in
                            NavigationLink(value: FieldEditDestination.existing(field)) {
                                FieldRow(field: field)
                            }
                        }
                        .onDelete(perform: deleteFields)
                        .onMove(perform: moveFields)
                    }
                } header: {
                    HStack {
                        Text("フィールド")
                        Spacer()
                        Button {
                            addNewField()
                        } label: {
                            Label("追加", systemImage: "plus")
                                .font(.subheadline)
                        }
                    }
                }

                // プレビュー
                if !type.fields.isEmpty {
                    Section("JSONスキーマ プレビュー") {
                        SchemaPreviewView(type: type)
                    }
                }
            }
            .navigationTitle(isNew ? "新規型定義" : "型定義を編集")
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
                    .disabled(type.name.isEmpty)
                }
            }
            .navigationDestination(for: FieldEditDestination.self) { destination in
                FieldEditorNavigationView(
                    destination: destination,
                    onSave: { updatedField in
                        updateField(updatedField)
                        navigationPath.removeLast()
                    },
                    onCancel: {
                        navigationPath.removeLast()
                    }
                )
            }
        }
    }

    // MARK: - Actions

    private func addNewField() {
        let newField = BuiltField(
            name: "field\(type.fields.count + 1)",
            fieldType: .string
        )
        navigationPath.append(FieldEditDestination.new(newField))
    }

    private func updateField(_ field: BuiltField) {
        if let index = type.fields.firstIndex(where: { $0.id == field.id }) {
            type.fields[index] = field
        } else {
            type.fields.append(field)
        }
    }

    private func deleteFields(at offsets: IndexSet) {
        type.fields.remove(atOffsets: offsets)
    }

    private func moveFields(from source: IndexSet, to destination: Int) {
        type.fields.move(fromOffsets: source, toOffset: destination)
    }

    private func saveAndDismiss() {
        onSave(type)
        dismiss()
    }
}

// MARK: - FieldRow

struct FieldRow: View {
    let field: BuiltField

    var body: some View {
        HStack {
            Image(systemName: field.fieldType.iconName)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(field.name)
                        .font(.headline)

                    if !field.isRequired {
                        Text("optional")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.fill.tertiary)
                            .clipShape(Capsule())
                    }
                }

                Text(field.fieldType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - SchemaPreviewView

struct SchemaPreviewView: View {
    let type: BuiltType

    var schemaJSON: String {
        let schema = type.toDynamicStructured().toJSONSchema()
        if let jsonString = try? schema.toJSONString(prettyPrinted: true) {
            return jsonString
        }
        return "{}"
    }

    var body: some View {
        Text(schemaJSON)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
    }
}

#Preview {
    TypeEditorView(
        type: BuiltType(
            name: "UserInfo",
            description: "ユーザー情報",
            fields: [
                BuiltField(name: "name", fieldType: .string, description: "ユーザー名"),
                BuiltField(name: "age", fieldType: .integer, description: "年齢", isRequired: false)
            ]
        ),
        isNew: false
    ) { _ in }
}
