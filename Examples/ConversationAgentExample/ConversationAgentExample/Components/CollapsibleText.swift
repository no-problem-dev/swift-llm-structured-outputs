import SwiftUI

struct CollapsibleText: View {
    let text: String
    var lineThreshold: Int = 5
    var font: Font = .subheadline
    var foregroundStyle: Color = .primary
    var showBackground: Bool = false

    @State private var isExpanded = false

    private var lines: [String] {
        text.components(separatedBy: .newlines)
    }

    private var needsCollapse: Bool {
        lines.count > lineThreshold
    }

    private var displayText: String {
        if needsCollapse && !isExpanded {
            return lines.prefix(lineThreshold).joined(separator: "\n") + "\n..."
        }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(displayText)
                .font(font)
                .foregroundStyle(foregroundStyle)

            if needsCollapse {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "折りたたむ" : "すべて表示 (\(lines.count)行)")
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption2)
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(showBackground ? 8 : 0)
        .background {
            if showBackground {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
            }
        }
    }
}
