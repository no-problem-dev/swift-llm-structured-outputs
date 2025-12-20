import SwiftUI
import LLMDynamicStructured

/// 結果を表示するシート
struct ResultSheet: View {
    let result: DynamicStructuredResult
    let outputSchema: OutputSchema
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    typeInfoSection

                    Divider()

                    fieldsSection
                }
                .padding()
            }
            .navigationTitle("生成結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Type Info Section

    private var typeInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cube.fill")
                    .foregroundStyle(.orange)
                Text(outputSchema.name)
                    .font(.headline)
            }

            if let description = outputSchema.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(outputSchema.fields.prefix(5)) { field in
                    Label(field.name, systemImage: field.type.icon)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.fill.tertiary)
                        .clipShape(Capsule())
                }
                if outputSchema.fields.count > 5 {
                    Text("+\(outputSchema.fields.count - 5)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Fields Section

    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(outputSchema.fields) { field in
                ResultFieldRow(field: field, result: result)
            }
        }
    }
}

// MARK: - ResultFieldRow

struct ResultFieldRow: View {
    let field: Field
    let result: DynamicStructuredResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: field.type.icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                Text(field.name)
                    .font(.subheadline.weight(.medium))

                if !field.isRequired {
                    Text("optional")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.fill.tertiary)
                        .clipShape(Capsule())
                }

                Spacer()

                Text(field.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Text(valueString)
                .font(.body)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.fill.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .textSelection(.enabled)
        }
    }

    private var valueString: String {
        switch field.type {
        case .string, .stringEnum:
            return result.string(field.name) ?? "(null)"

        case .integer:
            if let value = result.int(field.name) {
                return String(value)
            }
            return "(null)"

        case .number:
            if let value = result.double(field.name) {
                return String(value)
            }
            return "(null)"

        case .boolean:
            if let value = result.bool(field.name) {
                return value ? "true" : "false"
            }
            return "(null)"

        case .stringArray:
            if let values = result.stringArray(field.name) {
                if values.isEmpty {
                    return "[]"
                }
                return values.enumerated()
                    .map { "[\($0.offset)] \($0.element)" }
                    .joined(separator: "\n")
            }
            return "(null)"

        case .integerArray:
            if let values = result.intArray(field.name) {
                if values.isEmpty {
                    return "[]"
                }
                return values.enumerated()
                    .map { "[\($0.offset)] \($0.element)" }
                    .joined(separator: "\n")
            }
            return "(null)"
        }
    }
}
