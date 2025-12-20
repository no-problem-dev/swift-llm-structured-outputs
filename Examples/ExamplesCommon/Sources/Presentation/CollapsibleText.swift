import SwiftUI

/// 折りたたみ可能なテキスト表示コンポーネント
///
/// 指定した行数を超えるテキストは折りたたまれ、
/// ユーザーが展開/折りたたみを切り替えられる。
public struct CollapsibleText: View {
    public let text: String
    public var lineThreshold: Int
    public var font: Font
    public var foregroundStyle: Color
    public var showBackground: Bool

    @State private var isExpanded = false

    public init(
        text: String,
        lineThreshold: Int = 5,
        font: Font = .subheadline,
        foregroundStyle: Color = .primary,
        showBackground: Bool = false
    ) {
        self.text = text
        self.lineThreshold = lineThreshold
        self.font = font
        self.foregroundStyle = foregroundStyle
        self.showBackground = showBackground
    }

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

    #if os(iOS)
    private var backgroundFillColor: Color { Color(.systemGray5) }
    #else
    private var backgroundFillColor: Color { Color(nsColor: .controlBackgroundColor) }
    #endif

    public var body: some View {
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
                    .fill(backgroundFillColor)
            }
        }
    }
}
