import SwiftUI
import LLMClient
import LLMDynamicStructured

// MARK: - SchemaVisualizer

/// スキーマの視覚的な表示コンポーネント
struct SchemaVisualizer: View {
    let schema: OutputSchema
    @State private var isExpanded = false
    @State private var showJSONPreview = false

    var body: some View {
        VStack(spacing: 0) {
            headerCard

            if isExpanded {
                fieldsGrid
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
        .sheet(isPresented: $showJSONPreview) {
            JSONSchemaPreviewSheet(schema: schema)
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        Button {
            isExpanded.toggle()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "cube.fill")
                                .font(.title2)
                                .foregroundStyle(.orange.gradient)

                            Text(schema.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }

                        if let description = schema.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        fieldCountBadge

                        Button {
                            showJSONPreview = true
                        } label: {
                            Label("JSON", systemImage: "doc.text")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                fieldTypeSummary

                HStack {
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(schemaBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var schemaBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.orange.opacity(0.1),
                Color.orange.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var fieldCountBadge: some View {
        Text("\(schema.fields.count) fields")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.fill.secondary)
            .clipShape(Capsule())
    }

    private var fieldTypeSummary: some View {
        HStack(spacing: 6) {
            ForEach(Array(fieldTypeCount.prefix(4)), id: \.key) { type, count in
                FieldTypeBadge(type: type, count: count)
            }
            if fieldTypeCount.count > 4 {
                Text("+\(fieldTypeCount.count - 4)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var fieldTypeCount: [(key: FieldType, value: Int)] {
        var counts: [FieldType: Int] = [:]
        for field in schema.fields {
            counts[field.type, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }
    }

    // MARK: - Fields Grid

    private var fieldsGrid: some View {
        LazyVStack(spacing: 8) {
            ForEach(schema.fields) { field in
                FieldVisualizerRow(field: field)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

// MARK: - FieldTypeBadge

struct FieldTypeBadge: View {
    let type: FieldType
    var count: Int = 1

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.caption2)
                .foregroundStyle(typeColor)

            if count > 1 {
                Text("\(count)")
                    .font(.caption2.weight(.medium))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(typeColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var typeColor: Color {
        switch type {
        case .string: .blue
        case .integer, .number: .purple
        case .boolean: .green
        case .stringEnum: .orange
        case .stringArray, .integerArray: .teal
        }
    }
}

// MARK: - FieldVisualizerRow

struct FieldVisualizerRow: View {
    let field: Field

    var body: some View {
        HStack(spacing: 12) {
            // Type indicator
            Circle()
                .fill(typeColor.gradient)
                .frame(width: 8, height: 8)

            // Field info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(field.name)
                        .font(.subheadline.weight(.medium))

                    if !field.isRequired {
                        Text("?")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                }

                if let description = field.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Type badge
            HStack(spacing: 4) {
                Image(systemName: field.type.icon)
                    .font(.caption)
                Text(field.type.displayName)
                    .font(.caption)
            }
            .foregroundStyle(typeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(typeColor.opacity(0.1))
            .clipShape(Capsule())

            // Constraints indicator
            if hasConstraints {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
                    .foregroundStyle(.purple)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.fill.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var typeColor: Color {
        switch field.type {
        case .string: .blue
        case .integer, .number: .purple
        case .boolean: .green
        case .stringEnum: .orange
        case .stringArray, .integerArray: .teal
        }
    }

    private var hasConstraints: Bool {
        let c = field.constraints
        return c.minLength != nil || c.maxLength != nil ||
               c.pattern != nil || c.format != nil ||
               c.minimum != nil || c.maximum != nil ||
               c.minItems != nil || c.maxItems != nil
    }
}

// MARK: - JSONSchemaPreviewSheet

struct JSONSchemaPreviewSheet: View {
    let schema: OutputSchema
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private var jsonString: String {
        let dynamicStructured = schema.toDynamicStructured()
        let jsonSchema = dynamicStructured.toJSONSchema()
        return (try? jsonSchema.toJSONString(prettyPrinted: true)) ?? "{}"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection

                    jsonCodeBlock
                }
                .padding()
            }
            .navigationTitle("JSON Schema")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIPasteboard.general.string = jsonString
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    } label: {
                        Label(copied ? "コピー済み" : "コピー",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cube.fill")
                    .foregroundStyle(.orange)
                Text(schema.name)
                    .font(.headline)
            }

            if let description = schema.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("\(schema.fields.count) fields")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.fill.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var jsonCodeBlock: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(jsonString)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding()
        }
        .background(Color(uiColor: .systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary)
        )
    }
}

// MARK: - Previews

#Preview {
    SchemaVisualizer(
        schema: OutputSchema(
            name: "UserInfo",
            description: "ユーザー情報を表す構造体",
            fields: [
                Field(name: "name", type: .string, description: "ユーザー名"),
                Field(name: "age", type: .integer, description: "年齢", isRequired: false),
                Field(name: "email", type: .string, description: "メールアドレス"),
                Field(name: "role", type: .stringEnum(["admin", "user"]), description: "権限"),
                Field(name: "tags", type: .stringArray, description: "タグ")
            ]
        )
    )
    .padding()
}
