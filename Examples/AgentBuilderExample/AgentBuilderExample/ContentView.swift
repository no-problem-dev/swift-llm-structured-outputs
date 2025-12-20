import SwiftUI
import ExamplesCommon
import LLMClient

// MARK: - Editor State

/// 定義編集の共有状態
@Observable
final class DefinitionEditorState {
    var definition: AgentDefinition?
    var isNew: Bool = false
    var editingFieldIndex: Int?
    var editingComponentIndex: Int?

    func startEditing(_ definition: AgentDefinition, isNew: Bool) {
        self.definition = definition
        self.isNew = isNew
        self.editingFieldIndex = nil
        self.editingComponentIndex = nil
    }

    func updateField(_ field: BuiltField, at index: Int) {
        guard var def = definition else { return }
        if index < def.outputType.fields.count {
            def.outputType.fields[index] = field
            definition = def
        }
    }

    func addField(_ field: BuiltField) {
        guard var def = definition else { return }
        def.outputType.fields.append(field)
        definition = def
    }

    func deleteField(at index: Int) {
        guard var def = definition else { return }
        def.outputType.fields.remove(at: index)
        definition = def
    }

    func moveFields(from source: IndexSet, to destination: Int) {
        guard var def = definition else { return }
        def.outputType.fields.move(fromOffsets: source, toOffset: destination)
        definition = def
    }

    func updateComponent(_ component: EditablePromptComponent, at index: Int) {
        guard var def = definition else { return }
        var components = def.systemPrompt.components
        if index < components.count {
            components[index] = component.toPromptComponent()
            def.systemPrompt = Prompt(components: components)
            definition = def
        }
    }

    func addComponent(_ component: EditablePromptComponent) {
        guard var def = definition else { return }
        var components = def.systemPrompt.components
        components.append(component.toPromptComponent())
        def.systemPrompt = Prompt(components: components)
        definition = def
    }

    func deleteComponent(at index: Int) {
        guard var def = definition else { return }
        var components = def.systemPrompt.components
        components.remove(at: index)
        def.systemPrompt = Prompt(components: components)
        definition = def
    }

    func moveComponents(from source: IndexSet, to destination: Int) {
        guard var def = definition else { return }
        var components = def.systemPrompt.components
        components.move(fromOffsets: source, toOffset: destination)
        def.systemPrompt = Prompt(components: components)
        definition = def
    }

    func finishEditing() {
        definition = nil
        isNew = false
        editingFieldIndex = nil
        editingComponentIndex = nil
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.useCase) private var useCase
    @State private var showSettings = false
    @State private var navigationPath = NavigationPath()
    @State private var editorState = DefinitionEditorState()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                // エージェント定義セクション
                Section {
                    if appState.definitions.isEmpty {
                        ContentUnavailableView(
                            "エージェント定義がありません",
                            systemImage: "cpu",
                            description: Text("「新規作成」ボタンをタップして\n最初のエージェントを定義してください")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(appState.definitions) { definition in
                            NavigationLink(value: NavigationDestination.definitionDetail(definition)) {
                                DefinitionRow(definition: definition)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteDefinition(definition)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("エージェント定義")
                        Spacer()
                        Button {
                            createNewDefinition()
                        } label: {
                            Label("新規作成", systemImage: "plus")
                                .font(.subheadline)
                        }
                    }
                }

                // 最近のセッションセクション
                if !appState.recentSessions.isEmpty {
                    Section("最近のセッション") {
                        ForEach(appState.recentSessions) { session in
                            if let definition = appState.definitions.first(where: { $0.id == session.definitionId }) {
                                NavigationLink(value: NavigationDestination.sessionDetail(session, definition)) {
                                    SessionRow(
                                        session: session,
                                        definitionName: definition.name
                                    )
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deleteSession(session)
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }

            }
            .navigationTitle("Agent Builder")
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .definitionDetail(let definition):
                    AgentDefinitionDetailView(
                        definition: definition,
                        onEdit: { def in
                            editorState.startEditing(def, isNew: false)
                            navigationPath.append(NavigationDestination.definitionEditor(def, isNew: false))
                        },
                        onStartSession: { def in
                            startNewSession(for: def)
                        }
                    )
                case .definitionEditor(_, let isNew):
                    AgentDefinitionEditorView(
                        editorState: editorState,
                        isNew: isNew,
                        navigationPath: $navigationPath,
                        onSave: { savedDefinition in
                            saveDefinition(savedDefinition, isNew: isNew)
                            editorState.finishEditing()
                            navigationPath.removeLast()
                        }
                    )
                case .sessionDetail(let session, let definition):
                    SessionConversationView(
                        session: session,
                        definition: definition
                    )
                case .fieldEditorNew(let field):
                    FieldEditorView(
                        field: field,
                        onSave: { updatedField in
                            editorState.addField(updatedField)
                            navigationPath.removeLast()
                        }
                    )
                case .fieldEditorEdit(let field, let index):
                    FieldEditorView(
                        field: field,
                        onSave: { updatedField in
                            editorState.updateField(updatedField, at: index)
                            navigationPath.removeLast()
                        }
                    )
                case .promptComponentEditorNew(let component):
                    PromptComponentEditorView(
                        component: component,
                        onSave: { updatedComponent in
                            editorState.addComponent(updatedComponent)
                            navigationPath.removeLast()
                        }
                    )
                case .promptComponentEditorEdit(let component, let index):
                    PromptComponentEditorView(
                        component: component,
                        onSave: { updatedComponent in
                            editorState.updateComponent(updatedComponent, at: index)
                            navigationPath.removeLast()
                        }
                    )
                }
            }
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
            .task {
                loadInitialData()
            }
        }
    }

    // MARK: - Data Loading

    private func loadInitialData() {
        do {
            let definitions = try useCase.definition.fetchAll()
            appState.setDefinitions(definitions)

            let sessions = try useCase.session.fetchAll()
            appState.setSessions(sessions)
        } catch {
            print("Failed to load data: \(error)")
        }
    }

    // MARK: - Helpers

    private func definitionName(for session: AgentSession) -> String {
        appState.definitions.first { $0.id == session.definitionId }?.name ?? "Unknown"
    }

    // MARK: - Actions

    private func createNewDefinition() {
        let newDefinition = useCase.definition.create(
            name: "新しいエージェント",
            description: nil
        )
        editorState.startEditing(newDefinition, isNew: true)
        navigationPath.append(NavigationDestination.definitionEditor(newDefinition, isNew: true))
    }

    private func saveDefinition(_ definition: AgentDefinition, isNew: Bool) {
        do {
            try useCase.definition.save(definition)
            if isNew {
                appState.addDefinition(definition)
            } else {
                appState.updateDefinition(definition)
            }
        } catch {
            print("Failed to save definition: \(error)")
        }
    }

    private func deleteDefinition(_ definition: AgentDefinition) {
        do {
            try useCase.session.deleteByDefinition(id: definition.id)
            try useCase.definition.delete(id: definition.id)
            appState.deleteDefinition(id: definition.id)
        } catch {
            print("Failed to delete definition: \(error)")
        }
    }

    private func startNewSession(for definition: AgentDefinition) {
        let newSession = useCase.session.create(
            definitionId: definition.id,
            provider: appState.selectedProvider.rawValue
        )
        do {
            try useCase.session.save(newSession)
            appState.addSession(newSession)
            navigationPath.append(NavigationDestination.sessionDetail(newSession, definition))
        } catch {
            print("Failed to create session: \(error)")
        }
    }

    private func deleteSession(_ session: AgentSession) {
        do {
            try useCase.session.delete(id: session.id)
            appState.deleteSession(id: session.id)
        } catch {
            print("Failed to delete session: \(error)")
        }
    }
}

// MARK: - Navigation Destination

enum NavigationDestination: Hashable {
    case definitionDetail(AgentDefinition)
    case definitionEditor(AgentDefinition, isNew: Bool)
    case sessionDetail(AgentSession, AgentDefinition)  // 定義も一緒に渡す
    case fieldEditorNew(BuiltField)
    case fieldEditorEdit(BuiltField, Int)
    case promptComponentEditorNew(EditablePromptComponent)
    case promptComponentEditorEdit(EditablePromptComponent, Int)
}

// MARK: - Editable Prompt Component

/// プロンプトコンポーネントの編集用ラッパー
struct EditablePromptComponent: Identifiable, Hashable {
    let id: UUID
    var type: ComponentType
    var value: String
    var exampleOutput: String?

    init(id: UUID = UUID(), type: ComponentType, value: String = "", exampleOutput: String? = nil) {
        self.id = id
        self.type = type
        self.value = value
        self.exampleOutput = exampleOutput
    }

    init(from component: PromptComponent) {
        self.id = UUID()
        switch component {
        case .role(let value):
            self.type = .role
            self.value = value
            self.exampleOutput = nil
        case .expertise(let value):
            self.type = .expertise
            self.value = value
            self.exampleOutput = nil
        case .behavior(let value):
            self.type = .behavior
            self.value = value
            self.exampleOutput = nil
        case .objective(let value):
            self.type = .objective
            self.value = value
            self.exampleOutput = nil
        case .context(let value):
            self.type = .context
            self.value = value
            self.exampleOutput = nil
        case .instruction(let value):
            self.type = .instruction
            self.value = value
            self.exampleOutput = nil
        case .constraint(let value):
            self.type = .constraint
            self.value = value
            self.exampleOutput = nil
        case .thinkingStep(let value):
            self.type = .thinkingStep
            self.value = value
            self.exampleOutput = nil
        case .reasoning(let value):
            self.type = .reasoning
            self.value = value
            self.exampleOutput = nil
        case .example(let input, let output):
            self.type = .example
            self.value = input
            self.exampleOutput = output
        case .important(let value):
            self.type = .important
            self.value = value
            self.exampleOutput = nil
        case .note(let value):
            self.type = .note
            self.value = value
            self.exampleOutput = nil
        case .outputConstraint(let value):
            self.type = .outputConstraint
            self.value = value
            self.exampleOutput = nil
        }
    }

    func toPromptComponent() -> PromptComponent {
        switch type {
        case .role: return .role(value)
        case .expertise: return .expertise(value)
        case .behavior: return .behavior(value)
        case .objective: return .objective(value)
        case .context: return .context(value)
        case .instruction: return .instruction(value)
        case .constraint: return .constraint(value)
        case .thinkingStep: return .thinkingStep(value)
        case .reasoning: return .reasoning(value)
        case .example: return .example(input: value, output: exampleOutput ?? "")
        case .important: return .important(value)
        case .note: return .note(value)
        case .outputConstraint: return .outputConstraint(value)
        }
    }

    enum ComponentType: String, CaseIterable, Hashable {
        case role, expertise, behavior
        case objective, context, instruction, constraint
        case thinkingStep, reasoning
        case example
        case important, note, outputConstraint

        var displayName: String {
            switch self {
            case .role: return "役割"
            case .expertise: return "専門性"
            case .behavior: return "振る舞い"
            case .objective: return "目的"
            case .context: return "コンテキスト"
            case .instruction: return "指示"
            case .constraint: return "制約"
            case .thinkingStep: return "思考ステップ"
            case .reasoning: return "推論"
            case .example: return "例示"
            case .important: return "重要事項"
            case .note: return "補足"
            case .outputConstraint: return "出力制約"
            }
        }

        var icon: String {
            switch self {
            case .role: return "person.fill"
            case .expertise: return "brain.head.profile"
            case .behavior: return "figure.walk"
            case .objective: return "target"
            case .context: return "doc.text"
            case .instruction: return "list.number"
            case .constraint: return "exclamationmark.triangle"
            case .thinkingStep: return "brain"
            case .reasoning: return "lightbulb"
            case .example: return "text.quote"
            case .important: return "exclamationmark.circle.fill"
            case .note: return "note.text"
            case .outputConstraint: return "slider.horizontal.3"
            }
        }

        var color: Color {
            switch self {
            case .role, .expertise, .behavior: return .blue
            case .objective, .context: return .purple
            case .instruction, .constraint: return .orange
            case .thinkingStep, .reasoning: return .green
            case .example: return .teal
            case .important: return .red
            case .note: return .gray
            case .outputConstraint: return .indigo
            }
        }
    }
}

// MARK: - DefinitionRow

struct DefinitionRow: View {
    let definition: AgentDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(definition.name)
                    .font(.headline)

                Spacer()

                HStack(spacing: 8) {
                    Label(definition.fieldsSummary, systemImage: "list.bullet")
                    if !definition.enabledToolNames.isEmpty {
                        Label(definition.toolsSummary, systemImage: "wrench")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let description = definition.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // 出力型のフィールドプレビュー
            if !definition.outputType.fields.isEmpty {
                HStack(spacing: 6) {
                    ForEach(definition.outputType.fields.prefix(4)) { field in
                        Text(field.name)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.fill.tertiary)
                            .clipShape(Capsule())
                    }
                    if definition.outputType.fields.count > 4 {
                        Text("+\(definition.outputType.fields.count - 4)")
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
    let session: AgentSession
    let definitionName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.name)
                    .font(.subheadline.weight(.medium))

                Spacer()

                Label(session.status.displayName, systemImage: session.status.iconName)
                    .font(.caption)
                    .foregroundStyle(session.status == .active ? .green : .secondary)
            }

            HStack {
                Label(definitionName, systemImage: "cpu")
                Spacer()
                Text("\(session.turnCount) turns")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detail Views

struct AgentDefinitionDetailView: View {
    let definition: AgentDefinition
    let onEdit: (AgentDefinition) -> Void
    let onStartSession: (AgentDefinition) -> Void

    var body: some View {
        List {
            Section("基本情報") {
                LabeledContent("名前", value: definition.name)
                if let desc = definition.description {
                    LabeledContent("説明", value: desc)
                }
            }

            Section("出力型: \(definition.outputType.name)") {
                if definition.outputType.fields.isEmpty {
                    Text("フィールドが定義されていません")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(definition.outputType.fields) { field in
                        HStack {
                            Label(field.name, systemImage: field.fieldType.iconName)
                            Spacer()
                            Text(field.fieldType.displayName)
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
                if definition.systemPrompt.isEmpty {
                    Text("デフォルトプロンプトを使用")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(definition.systemPrompt.components.indices, id: \.self) { index in
                        let component = definition.systemPrompt.components[index]
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

            if !definition.enabledToolNames.isEmpty {
                Section("有効なツール") {
                    ForEach(definition.enabledToolNames, id: \.self) { toolName in
                        Label(toolName, systemImage: "wrench")
                    }
                }
            }

            Section {
                Button {
                    onStartSession(definition)
                } label: {
                    Label("新しいセッションを開始", systemImage: "bubble.left.and.bubble.right.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(definition.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    onEdit(definition)
                } label: {
                    Text("編集")
                }
            }
        }
    }
}

struct AgentDefinitionEditorView: View {
    @Bindable var editorState: DefinitionEditorState
    let isNew: Bool
    @Binding var navigationPath: NavigationPath
    let onSave: (AgentDefinition) -> Void

    private var definition: AgentDefinition {
        editorState.definition ?? AgentDefinition(
            name: "",
            outputType: BuiltType(name: "Output", description: nil, fields: [])
        )
    }

    var body: some View {
        List {
            // 基本情報セクション
            Section("基本情報") {
                TextField("名前", text: Binding(
                    get: { editorState.definition?.name ?? "" },
                    set: { editorState.definition?.name = $0 }
                ))

                TextField("説明（オプション）", text: Binding(
                    get: { editorState.definition?.description ?? "" },
                    set: { editorState.definition?.description = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(2...4)
            }

            // 出力型セクション
            Section {
                TextField("型名", text: Binding(
                    get: { editorState.definition?.outputType.name ?? "" },
                    set: { editorState.definition?.outputType.name = $0 }
                ))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                TextField("型の説明（オプション）", text: Binding(
                    get: { editorState.definition?.outputType.description ?? "" },
                    set: { editorState.definition?.outputType.description = $0.isEmpty ? nil : $0 }
                ))
            } header: {
                Text("出力型")
            }

            // フィールドセクション
            Section {
                if definition.outputType.fields.isEmpty {
                    Text("フィールドがありません")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(definition.outputType.fields.indices, id: \.self) { index in
                        let field = definition.outputType.fields[index]
                        Button {
                            navigationPath.append(NavigationDestination.fieldEditorEdit(field, index))
                        } label: {
                            HStack {
                                Label(field.name, systemImage: field.fieldType.iconName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(field.fieldType.displayName)
                                    .foregroundStyle(.secondary)
                                if !field.isRequired {
                                    Text("optional")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            editorState.deleteField(at: index)
                        }
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
                        let newField = BuiltField(name: "", fieldType: .string)
                        navigationPath.append(NavigationDestination.fieldEditorNew(newField))
                    } label: {
                        Label("追加", systemImage: "plus")
                            .font(.subheadline)
                    }
                }
            }

            // プロンプトセクション
            Section {
                if definition.systemPrompt.isEmpty {
                    Text("デフォルトプロンプトを使用")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(definition.systemPrompt.components.indices, id: \.self) { index in
                        let component = definition.systemPrompt.components[index]
                        let editable = EditablePromptComponent(from: component)
                        Button {
                            navigationPath.append(NavigationDestination.promptComponentEditorEdit(editable, index))
                        } label: {
                            PromptComponentRow(component: component)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            editorState.deleteComponent(at: index)
                        }
                    }
                    .onMove { source, destination in
                        editorState.moveComponents(from: source, to: destination)
                    }
                }
            } header: {
                HStack {
                    Text("プロンプト構成")
                    Spacer()
                    Menu {
                        ForEach(EditablePromptComponent.ComponentType.allCases, id: \.self) { type in
                            Button {
                                let newComponent = EditablePromptComponent(type: type)
                                navigationPath.append(NavigationDestination.promptComponentEditorNew(newComponent))
                            } label: {
                                Label(type.displayName, systemImage: type.icon)
                            }
                        }
                    } label: {
                        Label("追加", systemImage: "plus")
                            .font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle(isNew ? "新規エージェント" : "編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    if let def = editorState.definition {
                        onSave(def)
                    }
                }
                .disabled(editorState.definition?.name.isEmpty ?? true)
            }
        }
        .environment(\.editMode, .constant(.active))
    }
}

// MARK: - Prompt Component Row

struct PromptComponentRow: View {
    let component: PromptComponent

    private var type: EditablePromptComponent.ComponentType {
        switch component {
        case .role: return .role
        case .expertise: return .expertise
        case .behavior: return .behavior
        case .objective: return .objective
        case .context: return .context
        case .instruction: return .instruction
        case .constraint: return .constraint
        case .thinkingStep: return .thinkingStep
        case .reasoning: return .reasoning
        case .example: return .example
        case .important: return .important
        case .note: return .note
        case .outputConstraint: return .outputConstraint
        }
    }

    var body: some View {
        HStack {
            Image(systemName: type.icon)
                .foregroundStyle(type.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayName)
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

// MARK: - Prompt Component Editor View

struct PromptComponentEditorView: View {
    @State private var component: EditablePromptComponent
    let onSave: (EditablePromptComponent) -> Void

    init(component: EditablePromptComponent, onSave: @escaping (EditablePromptComponent) -> Void) {
        self._component = State(initialValue: component)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("タイプ") {
                Picker("タイプ", selection: $component.type) {
                    ForEach(EditablePromptComponent.ComponentType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            Section {
                if component.type == .example {
                    TextField("入力例", text: $component.value, axis: .vertical)
                        .lineLimit(3...6)

                    TextField("出力例", text: Binding(
                        get: { component.exampleOutput ?? "" },
                        set: { component.exampleOutput = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                } else {
                    TextEditor(text: $component.value)
                        .frame(minHeight: 100)
                }
            } header: {
                Text("内容")
            } footer: {
                Text(footerText)
                    .font(.caption)
            }
        }
        .navigationTitle(component.type.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    onSave(component)
                }
                .disabled(component.value.isEmpty)
            }
        }
    }

    private var footerText: String {
        switch component.type {
        case .role:
            return "LLMに特定の役割を与えます。例: 「経験豊富なSwiftエンジニア」"
        case .expertise:
            return "役割に付随する専門知識を指定します。例: 「iOSアプリ開発」"
        case .behavior:
            return "回答のスタイルや態度を指定します。例: 「簡潔かつ実用的なアドバイス」"
        case .objective:
            return "プロンプトの主要な目的やゴールを明示します。"
        case .context:
            return "タスクに関連する背景情報や状況を説明します。"
        case .instruction:
            return "タスクを遂行するための具体的な手順を指定します。"
        case .constraint:
            return "回答に対する制限や禁止事項を指定します。例: 「推測はしない」"
        case .thinkingStep:
            return "Chain-of-Thoughtで特定の思考プロセスを促します。"
        case .reasoning:
            return "なぜそのような処理をするのかの理由を説明します。"
        case .example:
            return "Few-shotプロンプティングで期待する入出力パターンを例示します。"
        case .important:
            return "特に重要な指示や注意点を強調します。"
        case .note:
            return "補足的な情報やヒントを提供します。"
        case .outputConstraint:
            return "出力値の技術的な制約を指定します。"
        }
    }
}

struct SessionConversationView: View {
    let session: AgentSession
    let definition: AgentDefinition

    var body: some View {
        ConversationView(builtType: definition.outputType)
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
