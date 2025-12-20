import SwiftUI
import LLMDynamicStructured
import UniformTypeIdentifiers

/// 結果を表示するシート
struct ResultSheet: View {
    let result: DynamicStructuredResult
    let outputSchema: OutputSchema
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: ResultTab = .fields
    @State private var showShareSheet = false
    @State private var copiedField: String?

    enum ResultTab: String, CaseIterable {
        case fields = "フィールド"
        case json = "JSON"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                typeInfoSection
                    .padding()

                Picker("表示", selection: $selectedTab) {
                    ForEach(ResultTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Divider()
                    .padding(.top)

                TabView(selection: $selectedTab) {
                    fieldsView
                        .tag(ResultTab.fields)

                    jsonView
                        .tag(ResultTab.json)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("生成結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            copyAllToClipboard()
                        } label: {
                            Label("すべてコピー", systemImage: "doc.on.doc")
                        }

                        Button {
                            showShareSheet = true
                        } label: {
                            Label("共有", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            exportAsFile()
                        } label: {
                            Label("ファイルに保存", systemImage: "arrow.down.doc")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [jsonString])
            }
        }
    }

    // MARK: - Type Info Section

    private var typeInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green.gradient)

                        Text(outputSchema.name)
                            .font(.headline)
                    }

                    if let description = outputSchema.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(outputSchema.fields.count) fields")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.fill.secondary)
                        .clipShape(Capsule())

                    Text(formattedTime)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            fieldTypeSummary
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.1), Color.green.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }

    private var fieldTypeSummary: some View {
        HStack(spacing: 6) {
            ForEach(outputSchema.fields.prefix(5)) { field in
                HStack(spacing: 4) {
                    Image(systemName: field.type.icon)
                        .font(.caption2)
                    Text(field.name)
                        .font(.caption2)
                }
                .foregroundStyle(typeColor(for: field.type))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(typeColor(for: field.type).opacity(0.1))
                .clipShape(Capsule())
            }
            if outputSchema.fields.count > 5 {
                Text("+\(outputSchema.fields.count - 5)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func typeColor(for type: FieldType) -> Color {
        switch type {
        case .string: .blue
        case .integer, .number: .purple
        case .boolean: .green
        case .stringEnum: .orange
        case .stringArray, .integerArray: .teal
        }
    }

    // MARK: - Fields View

    private var fieldsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(outputSchema.fields) { field in
                    EnhancedResultFieldRow(
                        field: field,
                        result: result,
                        copiedField: $copiedField
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - JSON View

    private var jsonView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Raw JSON")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = jsonString
                    } label: {
                        Label("コピー", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                JSONSyntaxHighlightedView(json: jsonString)
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private var jsonString: String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: result.rawValues,
            options: [.prettyPrinted, .sortedKeys]
        ),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private func copyAllToClipboard() {
        UIPasteboard.general.string = jsonString
    }

    private func exportAsFile() {
        // Create a temporary file and share it
        let fileName = "\(outputSchema.name)_\(Date().timeIntervalSince1970).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
            showShareSheet = true
        } catch {
            print("Export failed: \(error)")
        }
    }
}

// MARK: - EnhancedResultFieldRow

struct EnhancedResultFieldRow: View {
    let field: Field
    let result: DynamicStructuredResult
    @Binding var copiedField: String?

    private var isCopied: Bool { copiedField == field.name }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(typeColor.gradient)
                        .frame(width: 8, height: 8)

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
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: field.type.icon)
                        .font(.caption)
                    Text(field.type.displayName)
                        .font(.caption)
                }
                .foregroundStyle(typeColor)

                Button {
                    copyValue()
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(isCopied ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }

            // Value
            valueView
        }
        .padding()
        .background(.fill.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var valueView: some View {
        let value = valueString

        if value == "(null)" {
            Text(value)
                .font(.body)
                .foregroundStyle(.tertiary)
                .italic()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.fill.quinary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Text(value)
                .font(.system(.body, design: field.type == .stringArray || field.type == .integerArray ? .monospaced : .default))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.quaternary)
                )
        }
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
                return String(format: "%.2f", value)
            }
            return "(null)"

        case .boolean:
            if let value = result.bool(field.name) {
                return value ? "true" : "false"
            }
            return "(null)"

        case .stringArray:
            if let values = result.stringArray(field.name) {
                if values.isEmpty { return "[]" }
                return values.enumerated()
                    .map { "[\($0.offset)] \"\($0.element)\"" }
                    .joined(separator: "\n")
            }
            return "(null)"

        case .integerArray:
            if let values = result.intArray(field.name) {
                if values.isEmpty { return "[]" }
                return values.enumerated()
                    .map { "[\($0.offset)] \($0.element)" }
                    .joined(separator: "\n")
            }
            return "(null)"
        }
    }

    private func copyValue() {
        UIPasteboard.general.string = valueString
        copiedField = field.name
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedField == field.name {
                copiedField = nil
            }
        }
    }
}

// MARK: - JSONSyntaxHighlightedView

struct JSONSyntaxHighlightedView: View {
    let json: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(attributedJSON)
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

    private var attributedJSON: AttributedString {
        var result = AttributedString(json)

        // Keys (quoted strings followed by :)
        let keyPattern = try? NSRegularExpression(pattern: "\"([^\"]+)\"\\s*:")
        if let keyPattern {
            let range = NSRange(json.startIndex..., in: json)
            for match in keyPattern.matches(in: json, range: range) {
                if let swiftRange = Range(match.range, in: json),
                   let attrRange = Range(swiftRange, in: result) {
                    result[attrRange].foregroundColor = .purple
                }
            }
        }

        // String values
        let stringPattern = try? NSRegularExpression(pattern: ":\\s*\"([^\"]+)\"")
        if let stringPattern {
            let range = NSRange(json.startIndex..., in: json)
            for match in stringPattern.matches(in: json, range: range) {
                if let swiftRange = Range(match.range(at: 0), in: json),
                   let attrRange = Range(swiftRange, in: result) {
                    // Only color the value part
                    let valueStart = json[swiftRange].firstIndex(of: "\"")!
                    if let valueSwiftRange = Range(NSRange(valueStart..., in: json), in: json),
                       let valueAttrRange = Range(valueSwiftRange, in: result) {
                        result[valueAttrRange].foregroundColor = .green
                    }
                }
            }
        }

        // Numbers
        let numberPattern = try? NSRegularExpression(pattern: ":\\s*(-?\\d+\\.?\\d*)")
        if let numberPattern {
            let range = NSRange(json.startIndex..., in: json)
            for match in numberPattern.matches(in: json, range: range) {
                if let swiftRange = Range(match.range(at: 1), in: json),
                   let attrRange = Range(swiftRange, in: result) {
                    result[attrRange].foregroundColor = .blue
                }
            }
        }

        // Booleans and null
        let boolPattern = try? NSRegularExpression(pattern: ":\\s*(true|false|null)")
        if let boolPattern {
            let range = NSRange(json.startIndex..., in: json)
            for match in boolPattern.matches(in: json, range: range) {
                if let swiftRange = Range(match.range(at: 1), in: json),
                   let attrRange = Range(swiftRange, in: result) {
                    result[attrRange].foregroundColor = .orange
                }
            }
        }

        return result
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
